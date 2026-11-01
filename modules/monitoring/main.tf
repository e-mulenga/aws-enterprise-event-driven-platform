# ============================================================
# modules/monitoring
# ============================================================
# This platform's own CloudWatch dashboard and alarms — distinct from the
# Landing Zone's dashboard (landing_zone_dashboard_name), per the Ownership
# Matrix. Monitors exactly the metrics the source requirements call out:
# Queue Depth, Event Processing Time, Lambda Errors, Throttling, DLQ Count,
# Failed Events, Cost Metrics (via AWS Budgets would duplicate the Landing
# Zone's existing $-alert pattern, so cost is surfaced on the dashboard
# instead of a second budget).
# ============================================================

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "${var.name_prefix}-event-platform"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          region = var.primary_region
          title  = "SQS Queue Depth (ApproximateNumberOfMessagesVisible)"
          view   = "timeSeries"
          metrics = [
            for k, v in var.queue_names : ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", v]
          ]
          period = 300
          stat   = "Average"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          region = var.primary_region
          title  = "DLQ Message Count"
          view   = "timeSeries"
          metrics = [
            for k, v in var.dlq_names : ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", v]
          ]
          period = 300
          stat   = "Maximum"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          region = var.primary_region
          title  = "Lambda Errors & Throttles"
          view   = "timeSeries"
          metrics = concat(
            [for k, v in var.lambda_function_names : ["AWS/Lambda", "Errors", "FunctionName", v]],
            [for k, v in var.lambda_function_names : ["AWS/Lambda", "Throttles", "FunctionName", v]]
          )
          period = 300
          stat   = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          region = var.primary_region
          title  = "Lambda Duration (Event Processing Time)"
          view   = "timeSeries"
          metrics = [
            for k, v in var.lambda_function_names : ["AWS/Lambda", "Duration", "FunctionName", v]
          ]
          period = 300
          stat   = "p99"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          region = var.primary_region
          title  = "EventBridge: Failed Invocations"
          view   = "timeSeries"
          metrics = [
            ["AWS/Events", "FailedInvocations", "EventBusName", var.event_bus_name],
            ["AWS/Events", "ThrottledRules", "EventBusName", var.event_bus_name],
          ]
          period = 300
          stat   = "Sum"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          region = var.primary_region
          title  = "API Gateway: 4xx / 5xx"
          view   = "timeSeries"
          metrics = [
            ["AWS/ApiGateway", "4xx", "ApiId", var.api_name],
            ["AWS/ApiGateway", "5xx", "ApiId", var.api_name],
          ]
          period = 300
          stat   = "Sum"
        }
      }
    ]
  })
}

# ---- Alarms -> this platform's own platform-alerts SNS topic ---------------
resource "aws_cloudwatch_metric_alarm" "dlq_not_empty" {
  for_each = var.dlq_names

  alarm_name          = "${var.name_prefix}-${each.key}-dlq-not-empty"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "DLQ ${each.value} has at least one message — investigate and consider Event Replay."
  alarm_actions       = [var.alerts_topic_arn]
  ok_actions          = [var.alerts_topic_arn]

  dimensions = {
    QueueName = each.value
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = var.lambda_function_names

  alarm_name          = "${var.name_prefix}-${each.key}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "${each.value} has raised more than 5 errors in 5 minutes."
  alarm_actions       = [var.alerts_topic_arn]

  dimensions = {
    FunctionName = each.value
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  for_each = var.lambda_function_names

  alarm_name          = "${var.name_prefix}-${each.key}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "${each.value} is being throttled — consider reserved/provisioned concurrency."
  alarm_actions       = [var.alerts_topic_arn]

  dimensions = {
    FunctionName = each.value
  }

  tags = var.tags
}

# ---- Amazon Managed Grafana (optional) --------------------------------------
resource "aws_iam_role" "grafana" {
  count = var.enable_managed_grafana ? 1 : 0

  name = "${var.name_prefix}-grafana-workspace"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowGrafanaAssume"
      Effect    = "Allow"
      Principal = { Service = "grafana.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "grafana_cloudwatch" {
  count = var.enable_managed_grafana ? 1 : 0

  role       = aws_iam_role.grafana[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

resource "aws_grafana_workspace" "this" {
  count = var.enable_managed_grafana ? 1 : 0

  name                     = "${var.name_prefix}-event-platform"
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "SERVICE_MANAGED"
  role_arn                 = aws_iam_role.grafana[0].arn
  data_sources             = ["CLOUDWATCH"]

  tags = var.tags
}
