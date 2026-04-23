resource "azurerm_storage_account" "logs" {
  count = local.enable_service_logs ? 1 : 0

  #checkov:skip=CKV_AZURE_33: Ensure Storage logging is enabled for Queue service for read, write and delete requests
  #checkov:skip=CKV_AZURE_206: Ensure that Storage Accounts use replication
  #checkov:skip=CKV2_AZURE_1: Ensure storage for critical data are encrypted with Customer Managed Key
  #checkov:skip=CKV2_AZURE_33: Ensure storage account is configured with private endpoint

  name                            = "${replace(local.resource_prefix, "-", "")}logs"
  resource_group_name             = azurerm_resource_group.default[0].name
  location                        = azurerm_resource_group.default[0].location
  account_tier                    = "Standard"
  account_kind                    = "StorageV2"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true

  #checkov:skip=CKV2_AZURE_40: Ensure storage account is not configured with Shared Key authorization
  sas_policy {
    expiration_period = "2.00:00:00"
  }

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = local.tags
}

resource "azurerm_storage_account_network_rules" "logs" {
  count = local.enable_service_logs ? 1 : 0

  #checkov:skip=CKV2_AZURE_21: Azure storage account logging setting for blobs is disabled

  storage_account_id         = azurerm_storage_account.logs[0].id
  default_action             = "Deny"
  bypass                     = ["AzureServices"]
  virtual_network_subnet_ids = [azurerm_subnet.web_app_service_infra_subnet[0].id]
  ip_rules                   = local.service_log_ipv4_allow_list

  private_link_access {
    endpoint_resource_id = local.service_app.id
  }
}

resource "azurerm_storage_container" "logs" {

  #checkov:skip=CKV2_AZURE_21: Azure storage account logging setting for blobs is disabled

  for_each = local.enable_service_logs ? local.service_log_types : []

  name                  = "${local.resource_prefix}${each.value}logs"
  storage_account_id    = azurerm_storage_account.logs[0].id
  container_access_type = "private"
}

resource "azurerm_monitor_diagnostic_setting" "logs" {
  count = local.enable_service_logs ? 1 : 0

  name                           = "${local.resource_prefix}-storage-diag"
  target_resource_id             = azurerm_storage_account.logs[0].id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.web_app_service.id
  log_analytics_destination_type = "Dedicated"

  metric {
    category = "Transaction"
  }
}

data "azurerm_storage_account_blob_container_sas" "logs" {
  for_each = local.enable_service_logs ? local.service_log_types : []

  connection_string = azurerm_storage_account.logs[0].primary_connection_string
  container_name    = azurerm_storage_container.logs[each.value].name
  https_only        = true
  start             = local.service_log_storage_sas_start != "" ? local.service_log_storage_sas_start : formatdate("YYYY-MM-DD'T'hh:mm:ssZ", timestamp())
  expiry            = local.service_log_storage_sas_expiry != "" ? local.service_log_storage_sas_expiry : formatdate("YYYY-MM-DD'T'hh:mm:ssZ", timeadd(timestamp(), "+8760h")) # +12 months

  permissions {
    read   = true
    add    = true
    create = true
    write  = true
    delete = true
    list   = true
  }
}
