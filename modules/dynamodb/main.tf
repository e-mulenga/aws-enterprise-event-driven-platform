# ============================================================
# modules/dynamodb
# ============================================================
# Data layer for Customer Profiles, Orders and Event Metadata (the three
# entities the source requirements call out). On-demand (PAY_PER_REQUEST)
# billing — no capacity planning, no idle cost — with Streams enabled on
# every table so they double as an event-sourcing/replay source, and
# Point-in-Time Recovery for the 5-minute RPO target.
#
# DynamoDB vs Aurora PostgreSQL vs RDS PostgreSQL is evaluated in
# docs/data-layer-decision.md — DynamoDB was selected for its native
# Streams-as-events integration with EventBridge/Lambda, zero idle cost on
# demand billing, and multi-Region Global Tables story that a relational
# engine cannot match without a failover controller.
# ============================================================

locals {
  sse_enabled = true
}

resource "aws_dynamodb_table" "customer_profiles" {
  name         = "${var.name_prefix}-customer-profiles"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "customer_id"

  attribute {
    name = "customer_id"
    type = "S"
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = local.sse_enabled
    kms_key_arn = var.kms_key_arn
  }

  dynamic "replica" {
    for_each = var.enable_global_tables ? [var.dr_region] : []
    content {
      region_name = replica.value
    }
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-customer-profiles", Entity = "customer-profile" })
}

resource "aws_dynamodb_table" "orders" {
  name         = "${var.name_prefix}-orders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "order_id"

  attribute {
    name = "order_id"
    type = "S"
  }

  attribute {
    name = "customer_id"
    type = "S"
  }

  global_secondary_index {
    name            = "by-customer"
    hash_key        = "customer_id"
    projection_type = "ALL"
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = local.sse_enabled
    kms_key_arn = var.kms_key_arn
  }

  dynamic "replica" {
    for_each = var.enable_global_tables ? [var.dr_region] : []
    content {
      region_name = replica.value
    }
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-orders", Entity = "order" })
}

resource "aws_dynamodb_table" "event_metadata" {
  name         = "${var.name_prefix}-event-metadata"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"
  range_key    = "event_timestamp"

  attribute {
    name = "event_id"
    type = "S"
  }

  attribute {
    name = "event_timestamp"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = local.sse_enabled
    kms_key_arn = var.kms_key_arn
  }

  dynamic "replica" {
    for_each = var.enable_global_tables ? [var.dr_region] : []
    content {
      region_name = replica.value
    }
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-event-metadata", Entity = "event-metadata" })
}
