# ============================================================
# modules/sns
# ============================================================
# Pub/sub fan-out topics. order-events fans order lifecycle changes out to
# multiple independent subscribers (notifications, analytics, partner
# integrations) without the publisher knowing who's listening — SNS's core
# value over point-to-point SQS. platform-alerts is this repository's own
# operational-alerts topic (CloudWatch alarms target it); it is distinct
# from the Landing Zone's own monitoring_topic_arn, per the Ownership
# Matrix (CloudWatch Dashboards / this platform's alarms = Event Platform).
#
# See docs/messaging-strategy.md for the SQS vs SNS vs EventBridge guidance.
# ============================================================

locals {
  topics = ["order-events", "partner-notifications", "platform-alerts"]
}

resource "aws_sns_topic" "this" {
  for_each = toset(local.topics)

  name              = "${var.name_prefix}-${each.key}"
  kms_master_key_id = var.kms_key_arn

  tags = merge(var.tags, { Name = "${var.name_prefix}-${each.key}" })
}

resource "aws_sns_topic_subscription" "alerts_email" {
  count = var.alert_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.this["platform-alerts"].arn
  protocol  = "email"
  endpoint  = var.alert_email
}
