resource "azurerm_service_plan" "default" {
  #checkov:skip=CKV_AZURE_212: Suppressing check pending review
  #checkov:skip=CKV_AZURE_225: Suppressing check pending review

  name                = "${local.resource_prefix}default"
  resource_group_name = local.resource_group.name
  location            = local.resource_group.location
  os_type             = local.service_plan_os
  sku_name            = local.service_plan_sku

  tags = local.tags
}
