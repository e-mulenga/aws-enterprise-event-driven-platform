# ============================================================
# modules/sqs
# ============================================================
# Point-to-point queues for domain workers, each with its own DLQ (redrive
# policy) so a poison message never blocks a queue — satisfying the
# reliability requirement for Dead Letter Queues and, via the DLQ's own
# retention, a basis for manual Event Replay. payments uses FIFO because
# payment events must be processed in strict per-order sequence; everything
# else is Standard for throughput and simplicity.
#
# See docs/messaging-strategy.md for the SQS vs SNS vs EventBridge guidance.
# ============================================================

locals {
  standard_queues = {
    orders        = { fifo = false }
    inventory     = { fifo = false }
    notifications = { fifo = false }
  }
  fifo_queues = {
    payments = { fifo = true }
  }
  all_queues = merge(local.standard_queues, local.fifo_queues)

  # A standalone DLQ (no matching primary queue) that EventBridge rules with
  # a non-SQS target use as their dead-letter-config target.
  standalone_dlqs = ["eventbridge-rule-targets"]
}

resource "aws_sqs_queue" "dlq" {
  for_each = var.enable_dlq ? merge(
    { for k, v in local.all_queues : k => v },
    { for k in local.standalone_dlqs : k => { fifo = false } }
  ) : {}

  name                      = each.value.fifo ? "${var.name_prefix}-${each.key}-dlq.fifo" : "${var.name_prefix}-${each.key}-dlq"
  fifo_queue                = each.value.fifo
  message_retention_seconds = 1209600 # 14 days — maximum, to leave the widest replay window for a DLQ
  kms_master_key_id         = var.kms_key_arn

  tags = merge(var.tags, { Name = "${var.name_prefix}-${each.key}-dlq", Role = "dead-letter-queue" })
}

resource "aws_sqs_queue" "this" {
  for_each = local.all_queues

  name                        = each.value.fifo ? "${var.name_prefix}-${each.key}.fifo" : "${var.name_prefix}-${each.key}"
  fifo_queue                  = each.value.fifo
  content_based_deduplication = each.value.fifo
  message_retention_seconds   = var.message_retention_seconds
  kms_master_key_id           = var.kms_key_arn
  visibility_timeout_seconds  = 60

  redrive_policy = var.enable_dlq ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[each.key].arn
    maxReceiveCount     = var.dlq_max_receive_count
  }) : null

  tags = merge(var.tags, { Name = "${var.name_prefix}-${each.key}", Role = "domain-queue" })
}
