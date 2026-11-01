variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "bedrock_guardrail_id" {
  description = "Landing Zone's existing Bedrock guardrail ID — never created here."
  type        = string
  default     = null
}

variable "bedrock_guardrails_enabled" {
  type    = bool
  default = false
}

variable "bedrock_approved_models_policy_arn" {
  description = "Landing Zone's existing IAM managed policy restricting which Bedrock models may be invoked — attached, never recreated, here."
  type        = string
  default     = null
}

variable "ai_audit_bucket_name" {
  description = "Landing Zone's existing AI audit bucket — never created here."
  type        = string
}

variable "event_bus_arn" {
  type = string
}

variable "execution_role_arn" {
  type = string
}

variable "kms_key_arn" {
  type    = string
  default = null
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
