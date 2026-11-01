variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "kms_strategy" {
  description = "aws-managed or customer-managed. Only customer-managed (normally prod) creates CMKs here."
  type        = string
}

variable "landing_zone_key_strategy" {
  description = "Informational: the Landing Zone's own key_strategy output, recorded in tags for audit trails."
  type        = string
  default     = "aws-managed"
}

variable "vpc_id" {
  description = "Landing Zone VPC the Lambda security group is created in. Never a VPC this module creates."
  type        = string
}

variable "primary_region" {
  type = string
}

variable "dr_region" {
  type = string
}

variable "enable_dr_replica_keys" {
  description = "Create a second, independent CMK in dr_region for the DR-replicated S3 bucket. KMS keys are regional and cannot replicate, so DR needs its own key with equivalent policy."
  type        = bool
  default     = false
}

variable "ai_audit_bucket_name" {
  description = "Landing Zone's existing AI audit bucket name (never created here) — used only to scope the Lambda execution role's write permission."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "lambda_dlq_arns" {
  description = "DLQ ARNs Lambda functions may write to."
  type        = list(string)
  default     = []
}
