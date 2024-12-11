resource "azurerm_application_insights" "web_app_service" {
  name                = "${local.resource_prefix}-insights"
  location            = local.resource_group.location
  resource_group_name = local.resource_group.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.web_app_service.id
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_monitor_diagnostic_setting" "web_app_service" {
  name                       = "${local.resource_prefix}webappservice"
  target_resource_id         = local.service_app.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.web_app_service.id

  dynamic "enabled_log" {
    for_each = local.service_diagnostic_setting_types
    content {
      category = enabled_log.value
    }
  }

  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_application_insights_standard_web_test" "web_app_service" {
  count = local.enable_monitoring ? 1 : 0

  name                    = "${local.resource_prefix}-http"
  resource_group_name     = local.resource_group.name
  location                = local.resource_group.location
  application_insights_id = azurerm_application_insights.web_app_service.id
  timeout                 = 10
  description             = "Regional HTTP availability check"
  enabled                 = true
  retry_enabled           = true

  geo_locations = [
    "emea-se-sto-edge", # UK West
    "emea-nl-ams-azr",  # West Europe
    "emea-ru-msa-edge"  # UK South
  ]

  request {
    url       = local.monitor_http_availability_url
    http_verb = "GET"

    header {
      name  = "X-AppInsights-HttpTest"
      value = azurerm_application_insights.web_app_service.name
    }
  }

  validation_rules {
    expected_status_code = 0 # 0 = response code < 400
  }

  tags = merge(
    local.tags,
    { "hidden-link:${azurerm_application_insights.web_app_service.id}" = "Resource" },
  )
}
