# ============================================================
# Root variables
# ============================================================

# ---- Landing Zone remote state ---------------------------------------------
variable "landing_zone_state_bucket" {
  description = "S3 bucket holding the AWS Enterprise Landing Zone Terraform state."
  type        = string
}

variable "landing_zone_state_key" {
  description = "State object key for the target Landing Zone environment, e.g. landing-zone/dev/terraform.tfstate."
  type        = string
}

variable "landing_zone_state_region" {
  description = "Region of the Landing Zone state bucket."
  type        = string
  default     = "us-east-1"
}

# ---- Core -------------------------------------------------------------------
variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "primary_region" {
  description = "Must match the Landing Zone's primary Region."
  type        = string
  default     = "af-south-1"
}

variable "dr_region" {
  description = "Must match the Landing Zone's DR Region."
  type        = string
  default     = "eu-west-1"
}

variable "additional_tags" {
  type    = map(string)
  default = {}
}

# ---- Encryption strategy (per the mandatory cost-optimization statement) ---
variable "kms_strategy" {
  description = "aws-managed (dev/test) or customer-managed (prod). Dev/Test use AWS-managed encryption keys to reduce KMS operational cost and administrative overhead while maintaining encryption at rest. Production uses Customer Managed Keys (CMKs) for enterprise governance, auditability, compliance, and security."
  type        = string
  default     = "aws-managed"

  validation {
    condition     = contains(["aws-managed", "customer-managed"], var.kms_strategy)
    error_message = "kms_strategy must be aws-managed or customer-managed."
  }
}

# ---- Reliability --------------------------------------------------------------
variable "event_retention_days" {
  description = "EventBridge archive retention, in days, for event replay."
  type        = number
  default     = 14
}

variable "enable_cross_region_replication" {
  description = "Replicate the event-archive S3 bucket from af-south-1 to eu-west-1."
  type        = bool
  default     = true
}

variable "enable_dlq" {
  description = "Create dead-letter queues for every SQS queue and EventBridge rule target."
  type        = bool
  default     = true
}

variable "enable_event_replay" {
  description = "Create an EventBridge archive on the event bus for replay."
  type        = bool
  default     = true
}

variable "enable_global_tables" {
  description = "DynamoDB Global Tables replicating to dr_region. Meaningful cost and complexity — see docs/cost-analysis.md. Recommended true only in prod."
  type        = bool
  default     = false
}

variable "message_retention_seconds" {
  description = "SQS message retention. Default 4 days."
  type        = number
  default     = 345600
}

variable "dlq_max_receive_count" {
  description = "Times a message is retried before moving to its DLQ."
  type        = number
  default     = 5
}

# ---- Observability -------------------------------------------------------------
variable "enable_xray_tracing" {
  type    = bool
  default = true
}

variable "enable_managed_grafana" {
  description = "Amazon Managed Grafana workspace. Has an hourly/per-user cost — see docs/cost-analysis.md. Off by default."
  type        = bool
  default     = false
}

variable "alert_email" {
  type      = string
  default   = ""
  sensitive = true
}

variable "lambda_log_retention_days" {
  type    = number
  default = 30
}

# ---- AI readiness ---------------------------------------------------------------
variable "enable_ai_integration" {
  description = "Deploy the AI-ready event routing module (consumes, never creates, Landing Zone Bedrock guardrails)."
  type        = bool
  default     = false
}

# ---- API Gateway custom domain -----------------------------------------------
variable "enable_custom_domain" {
  description = "Attach an API Gateway custom domain under the Landing Zone's Route 53 zone (api.<env>.<domain>)."
  type        = bool
  default     = false
}

variable "api_throttle_burst_limit" {
  type    = number
  default = 200
}

variable "api_throttle_rate_limit" {
  type    = number
  default = 100
}
