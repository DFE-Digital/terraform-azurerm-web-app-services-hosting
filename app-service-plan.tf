resource "azurerm_service_plan" "default" {
  #checkov:skip=CKV_AZURE_212: Ensure App Service has a minimum number of instances for failover
  #checkov:skip=CKV_AZURE_225: Ensure the App Service Plan is zone redundant

  name                = "${local.resource_prefix}default"
  resource_group_name = local.resource_group.name
  location            = local.resource_group.location
  os_type             = local.service_plan_os
  sku_name            = local.service_plan_sku

  tags = local.tags
}
