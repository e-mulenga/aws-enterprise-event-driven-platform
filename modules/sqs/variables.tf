variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "kms_key_arn" {
  description = "null uses the AWS-managed alias/aws/sqs key (dev/test). A CMK ARN in prod."
  type        = string
  default     = null
}

variable "enable_dlq" {
  type    = bool
  default = true
}

variable "dlq_max_receive_count" {
  type    = number
  default = 5
}

variable "message_retention_seconds" {
  type    = number
  default = 345600
}

variable "tags" {
  type    = map(string)
  default = {}
}
