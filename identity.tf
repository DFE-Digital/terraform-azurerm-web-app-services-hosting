resource "azurerm_user_assigned_identity" "default" {
  location            = local.resource_group.location
  name                = "${local.resource_prefix}-uami"
  resource_group_name = local.resource_group.name
  tags                = local.tags
}
