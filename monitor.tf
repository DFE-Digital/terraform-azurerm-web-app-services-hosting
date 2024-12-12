resource "azurerm_monitor_action_group" "web_app_service" {
  count = local.enable_monitoring ? 1 : 0

  name                = "${local.resource_prefix}-actiongroup"
  resource_group_name = local.resource_group.name
  short_name          = local.project_name
  tags                = local.tags

  dynamic "email_receiver" {
    for_each = local.monitor_email_receivers

    content {
      name                    = "Email ${email_receiver.value}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }

  dynamic "event_hub_receiver" {
    for_each = local.enable_event_hub ? [0] : []

    content {
      name                    = "Event Hub"
      event_hub_name          = azurerm_eventhub.web_app_service[0].name
      event_hub_namespace     = azurerm_eventhub_namespace.web_app_service[0].id
      subscription_id         = data.azurerm_subscription.current.subscription_id
      use_common_alert_schema = true
    }
  }

  dynamic "logic_app_receiver" {
    for_each = local.enable_monitoring || local.existing_logic_app_workflow.name != "" ? [0] : []

    content {
      name                    = local.monitor_logic_app_receiver.name
      resource_id             = local.monitor_logic_app_receiver.resource_id
      callback_url            = local.monitor_logic_app_receiver.callback_url
      use_common_alert_schema = true
    }
  }
}

resource "azurerm_monitor_metric_alert" "cpu" {
  count = local.enable_monitoring ? 1 : 0

  name                = "Web App CPU - ${azurerm_service_plan.default.name}"
  resource_group_name = local.resource_group.name
  scopes              = [azurerm_service_plan.default.id]
  description         = "Web App ${azurerm_service_plan.default.name} is consuming more than 80% of CPU"
  window_size         = "PT5M"
  frequency           = "PT5M"
  severity            = 2 # Warning

  criteria {
    metric_namespace = "microsoft.web/serverfarms"
    metric_name      = "CpuPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.web_app_service[0].id
  }

  tags = local.tags
}

resource "azurerm_monitor_metric_alert" "memory" {
  count = local.enable_monitoring ? 1 : 0

  name                = "Web App Memory - ${azurerm_service_plan.default.name}"
  resource_group_name = local.resource_group.name
  scopes              = [azurerm_service_plan.default.id]
  description         = "Web App ${azurerm_service_plan.default.name} is consuming more than 80% of Memory"
  window_size         = "PT5M"
  frequency           = "PT5M"
  severity            = 2 # Warning

  criteria {
    metric_namespace = "microsoft.web/serverfarms"
    metric_name      = "MemoryPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.web_app_service[0].id
  }

  tags = local.tags
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "exceptions" {
  count = local.enable_monitoring ? 1 : 0

  name                 = "Exceptions Count - ${azurerm_application_insights.web_app_service.name}"
  resource_group_name  = local.resource_group.name
  location             = local.resource_group.location
  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"
  scopes               = [azurerm_application_insights.web_app_service.id]
  severity             = 2 # Warning
  description          = "Action will be triggered when an Exception is raised in App Insights"

  criteria {
    query = <<-QUERY
      requests
        | where toint(resultCode) >= 500
        | where timestamp > ago(5m)
        | join exceptions on operation_Id
        | project timestamp, itemId, name, url, type, outerMessage, appName,
            linkToAppInsights = strcat(
              "https://portal.azure.com/#blade/AppInsightsExtension/DetailsV2Blade/DataModel/",
              url_encode(strcat('{"eventId":"', itemId, '","timestamp":"', timestamp, '"}')),
              "/ComponentId/",
              url_encode(strcat('{"Name":"', split(appName, "/", 8)[0], '","ResourceGroup":"', split(appName, "/", 4)[0], '","SubscriptionId":"', split(appName, "/", 2)[0], '"}'))
            )
        | order by timestamp desc
        | project-away timestamp, itemId, appName
      QUERY

    time_aggregation_method = "Count"
    threshold               = 1
    operator                = "GreaterThanOrEqual"

    dimension {
      name     = "name"
      operator = "Include"
      values   = ["*"]
    }

    dimension {
      name     = "url"
      operator = "Include"
      values   = ["*"]
    }

    dimension {
      name     = "type"
      operator = "Include"
      values   = ["*"]
    }

    dimension {
      name     = "outerMessage"
      operator = "Include"
      values   = ["*"]
    }

    dimension {
      name     = "linkToAppInsights"
      operator = "Include"
      values   = ["*"]
    }

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  auto_mitigation_enabled = false

  action {
    action_groups = [azurerm_monitor_action_group.web_app_service[0].id]
  }

  tags = local.tags
}

resource "azurerm_monitor_metric_alert" "http" {
  count = local.enable_monitoring ? 1 : 0

  name                = "HTTP Availability Test - ${azurerm_application_insights.web_app_service.name}"
  resource_group_name = local.resource_group.name
  # Scope requires web test to come first
  # https://github.com/hashicorp/terraform-provider-azurerm/issues/8551
  scopes      = [azurerm_application_insights_standard_web_test.web_app_service[0].id, azurerm_application_insights.web_app_service.id]
  description = "HTTP URL ${local.monitor_http_availability_url} could not be reached by 2 out of 3 locations"
  severity    = 0 # Critical

  application_insights_web_test_location_availability_criteria {
    web_test_id           = azurerm_application_insights_standard_web_test.web_app_service[0].id
    component_id          = azurerm_application_insights.web_app_service.id
    failed_location_count = 2 # 2 out of 3 locations
  }

  action {
    action_group_id = azurerm_monitor_action_group.web_app_service[0].id
  }

  tags = local.tags
}

resource "azurerm_monitor_metric_alert" "latency" {
  count = local.enable_monitoring && local.enable_cdn_frontdoor ? 1 : 0

  name                = "Azure Front Door Total Latency - ${azurerm_cdn_frontdoor_profile.cdn[0].name}"
  resource_group_name = local.resource_group.name
  scopes              = [azurerm_cdn_frontdoor_profile.cdn[0].id]
  description         = "Azure Front Door ${azurerm_cdn_frontdoor_profile.cdn[0].name} total latency is greater than 1s"
  window_size         = "PT5M"
  frequency           = "PT5M"
  severity            = 2 # Warning

  criteria {
    metric_namespace = "Microsoft.Cdn/profiles"
    metric_name      = "TotalLatency"
    aggregation      = "Minimum"
    operator         = "GreaterThan"
    threshold        = 1000
  }

  action {
    action_group_id = azurerm_monitor_action_group.web_app_service[0].id
  }

  tags = local.tags
}
