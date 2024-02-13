resource "azurerm_virtual_network" "default" {
  count = local.existing_virtual_network == "" ? (
    local.launch_in_vnet ? 1 : 0
  ) : 0

  name                = "${local.resource_prefix}default"
  address_space       = [local.virtual_network_address_space]
  location            = local.resource_group.location
  resource_group_name = local.resource_group.name
  tags                = local.tags
}

resource "azurerm_route_table" "default" {
  count = local.launch_in_vnet ? 1 : 0

  name                          = "${local.resource_prefix}default"
  location                      = local.resource_group.location
  resource_group_name           = local.resource_group.name
  disable_bgp_route_propagation = false
  tags                          = local.tags
}

resource "azurerm_subnet" "web_app_service_infra_subnet" {
  count = local.launch_in_vnet ? 1 : 0

  name                 = "${local.resource_prefix}webappserviceinfra"
  virtual_network_name = local.virtual_network.name
  resource_group_name  = local.resource_group.name
  address_prefixes     = [local.web_app_service_infra_subnet_cidr]

  service_endpoints = ["Microsoft.Storage"]

  delegation {
    name = "delegation"

    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action",
      ]
    }
  }
}

resource "azurerm_subnet_route_table_association" "web_app_service_infra_subnet" {
  count = local.launch_in_vnet ? 1 : 0

  subnet_id      = azurerm_subnet.web_app_service_infra_subnet[0].id
  route_table_id = azurerm_route_table.default[0].id
}

resource "azurerm_network_security_group" "web_app_service_infra" {
  count = local.launch_in_vnet ? 1 : 0

  name                = "${local.resource_prefix}webappserviceinfransg"
  location            = local.resource_group.location
  resource_group_name = local.resource_group.name

  tags = local.tags
}

resource "azurerm_subnet_network_security_group_association" "web_app_service_infra_allow_frontdoor_inbound_only" {
  count = local.launch_in_vnet ? 1 : 0

  subnet_id                 = azurerm_subnet.web_app_service_infra_subnet[0].id
  network_security_group_id = azurerm_network_security_group.web_app_service_infra[0].id
}


# Storage Account Networking

resource "azurerm_subnet" "storage_private_endpoint_subnet" {
  count = local.enable_service_logs ? 1 : 0

  name                                      = "${local.resource_prefix}storageprivateendpoint"
  virtual_network_name                      = local.virtual_network.name
  resource_group_name                       = local.resource_group.name
  address_prefixes                          = [local.storage_subnet_cidr]
  private_endpoint_network_policies_enabled = true
}

resource "azurerm_subnet_route_table_association" "storage_private_endpoint_subnet" {
  count = local.enable_service_logs ? 1 : 0

  subnet_id      = azurerm_subnet.storage_private_endpoint_subnet[0].id
  route_table_id = azurerm_route_table.default[0].id
}

# Storage Account Networking / Private Endpoint

resource "azurerm_private_endpoint" "storage_private_link" {
  count = local.enable_service_logs ? 1 : 0

  name                = "${local.resource_prefix}storageprivateendpoint"
  location            = local.resource_group.location
  resource_group_name = local.resource_group.name
  subnet_id           = azurerm_subnet.storage_private_endpoint_subnet[0].id

  private_service_connection {
    name                           = "${local.resource_prefix}storageconnection"
    private_connection_resource_id = azurerm_storage_account.logs[0].id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  tags = local.tags
}

resource "azurerm_private_dns_zone" "storage_private_link" {
  count = local.enable_service_logs ? 1 : 0

  name                = "${azurerm_storage_account.logs[0].name}.blob.core.windows.net"
  resource_group_name = local.resource_group.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage_private_link" {
  count = local.enable_service_logs ? 1 : 0

  name                  = "${local.resource_prefix}storageprivatelink"
  resource_group_name   = local.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_private_link[0].name
  virtual_network_id    = local.virtual_network.id
  tags                  = local.tags
}

resource "azurerm_private_dns_a_record" "storage_private_link" {
  count = local.enable_service_logs ? 1 : 0

  name                = "@"
  zone_name           = azurerm_private_dns_zone.storage_private_link[0].name
  resource_group_name = local.resource_group.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.storage_private_link[0].private_service_connection[0].private_ip_address]
  tags                = local.tags
}
