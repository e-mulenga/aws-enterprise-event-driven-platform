# ============================================================
# modules/eventbridge
# ============================================================
# The schema-aware event bus for Domain, Business and Integration Events
# (per the source requirements). Rules route by event source/detail-type to
# SQS queues (domain events needing ordered, durable processing) or SNS
# topics (business events needing fan-out). An archive on the bus gives
# Event Replay; every rule target carries a dead-letter-config for Event
# Auditing of delivery failures (distinct from application-level processing
# failures, which land in the target queue's own DLQ).
#
# See docs/messaging-strategy.md for the SQS vs SNS vs EventBridge guidance,
# and architecture/mermaid/eventbridge-architecture.mmd for the full rule map.
# ============================================================

resource "aws_cloudwatch_event_bus" "this" {
  name = "${var.name_prefix}-events"

  tags = merge(var.tags, { Name = "${var.name_prefix}-events" })
}

resource "aws_cloudwatch_event_archive" "this" {
  count = var.enable_event_replay ? 1 : 0

  name             = "${var.name_prefix}-events-archive"
  event_source_arn = aws_cloudwatch_event_bus.this.arn
  retention_days   = var.event_retention_days
  description      = "Event Replay source — retains every event on the bus for ${var.event_retention_days} days."
}

# ---- Rule: domain events for Orders -> orders SQS queue --------------------
resource "aws_cloudwatch_event_rule" "orders_domain_events" {
  name           = "${var.name_prefix}-orders-domain-events"
  description    = "Domain Events: order created/updated/cancelled."
  event_bus_name = aws_cloudwatch_event_bus.this.name

  event_pattern = jsonencode({
    source      = ["shopsphere.orders"]
    detail-type = ["OrderCreated", "OrderUpdated", "OrderCancelled"]
  })

  tags = var.tags
}

resource "aws_sqs_queue_policy" "allow_eventbridge_orders" {
  queue_url = var.orders_queue_url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowEventBridgeSendMessage"
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = var.orders_queue_arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_cloudwatch_event_rule.orders_domain_events.arn } }
    }]
  })
}

resource "aws_cloudwatch_event_target" "orders_domain_events" {
  rule           = aws_cloudwatch_event_rule.orders_domain_events.name
  event_bus_name = aws_cloudwatch_event_bus.this.name
  arn            = var.orders_queue_arn

  dead_letter_config {
    arn = var.dlq_arn
  }
}

# ---- Rule: domain events for Inventory -> inventory SQS queue -------------
resource "aws_cloudwatch_event_rule" "inventory_domain_events" {
  name           = "${var.name_prefix}-inventory-domain-events"
  description    = "Domain Events: inventory reserved/released/adjusted."
  event_bus_name = aws_cloudwatch_event_bus.this.name

  event_pattern = jsonencode({
    source      = ["shopsphere.inventory"]
    detail-type = ["InventoryReserved", "InventoryReleased", "InventoryAdjusted"]
  })

  tags = var.tags
}

resource "aws_sqs_queue_policy" "allow_eventbridge_inventory" {
  queue_url = var.inventory_queue_url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowEventBridgeSendMessage"
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = var.inventory_queue_arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_cloudwatch_event_rule.inventory_domain_events.arn } }
    }]
  })
}

resource "aws_cloudwatch_event_target" "inventory_domain_events" {
  rule           = aws_cloudwatch_event_rule.inventory_domain_events.name
  event_bus_name = aws_cloudwatch_event_bus.this.name
  arn            = var.inventory_queue_arn

  dead_letter_config {
    arn = var.dlq_arn
  }
}

# ---- Rule: business events (order lifecycle, customer-facing) -> SNS fan-out
resource "aws_cloudwatch_event_rule" "business_events" {
  name           = "${var.name_prefix}-business-events"
  description    = "Business Events: customer-facing order status changes, fanned out to notification/analytics/partner subscribers."
  event_bus_name = aws_cloudwatch_event_bus.this.name

  event_pattern = jsonencode({
    source      = ["shopsphere.orders"]
    detail-type = ["OrderStatusChanged"]
  })

  tags = var.tags
}

resource "aws_sns_topic_policy" "allow_eventbridge_business_events" {
  arn = var.notifications_topic_arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowEventBridgePublish"
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sns:Publish"
      Resource  = var.notifications_topic_arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_cloudwatch_event_rule.business_events.arn } }
    }]
  })
}

resource "aws_cloudwatch_event_target" "business_events" {
  rule           = aws_cloudwatch_event_rule.business_events.name
  event_bus_name = aws_cloudwatch_event_bus.this.name
  arn            = var.notifications_topic_arn

  dead_letter_config {
    arn = var.dlq_arn
  }
}

# ---- Rule: integration events (partner / external systems) — catch-all,
# routed to the inventory queue's DLQ-protected path for this portfolio
# build; a real deployment would target a dedicated partner-integration
# queue per partner.
resource "aws_cloudwatch_event_rule" "integration_events" {
  name           = "${var.name_prefix}-integration-events"
  description    = "Integration Events: inbound partner/external-system events."
  event_bus_name = aws_cloudwatch_event_bus.this.name

  event_pattern = jsonencode({
    source = ["shopsphere.partner-integration"]
  })

  tags = var.tags
}
