variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "kms_key_arn" {
  description = "null uses the AWS-managed alias/aws/sns key (dev/test). A CMK ARN in prod."
  type        = string
  default     = null
}

variable "alert_email" {
  type      = string
  default   = ""
  sensitive = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
