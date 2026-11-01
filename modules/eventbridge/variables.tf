variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "event_retention_days" {
  type    = number
  default = 14
}

variable "enable_event_replay" {
  description = "Creates an EventBridge archive on the custom bus so any event can be replayed."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "Reserved for future use — EventBridge custom buses do not yet support a resource-level kms_key_arn on aws_cloudwatch_event_bus in all provider versions; encryption of events in transit/at rest on the service side is AWS-managed regardless of this value today."
  type        = string
  default     = null
}

variable "orders_queue_arn" {
  type = string
}

variable "orders_queue_url" {
  type = string
}

variable "inventory_queue_arn" {
  type = string
}

variable "inventory_queue_url" {
  type = string
}

variable "notifications_topic_arn" {
  type = string
}

variable "dlq_arn" {
  description = "Standalone DLQ (modules/sqs's 'eventbridge-rule-targets' queue) used as the dead-letter target for rules whose target delivery fails."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
