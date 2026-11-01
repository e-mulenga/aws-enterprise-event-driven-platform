variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "enable_global_tables" {
  description = "Add a replica in dr_region to each table (DynamoDB Global Tables v2). Meaningful cost/complexity increase — see docs/cost-analysis.md. Recommended only in prod."
  type        = bool
  default     = false
}

variable "dr_region" {
  type = string
}

variable "kms_key_arn" {
  description = "null uses the AWS-owned default DynamoDB encryption (dev/test). A CMK ARN in prod."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
