variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "primary_vpc_private_subnet_ids" {
  description = "Landing Zone private subnet IDs — Lambdas run here, never in a VPC this repository creates."
  type        = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "kms_key_arn" {
  description = "null uses AWS-managed Lambda environment-variable encryption (dev/test). A CMK ARN in prod."
  type        = string
  default     = null
}

variable "execution_role_arn" {
  type = string
}

variable "execution_role_name" {
  type = string
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

variable "orders_table_name" {
  type = string
}

variable "orders_table_arn" {
  type = string
}

variable "customer_profiles_table_name" {
  type = string
}

variable "event_metadata_table_name" {
  type = string
}

variable "event_bus_name" {
  type = string
}

variable "event_bus_arn" {
  type = string
}

variable "dlq_arn" {
  description = "Function-level DLQ (on-failure destination for async invokes / orders queue DLQ, reused here for the Lambda DLQ config)."
  type        = string
}

variable "enable_xray_tracing" {
  type    = bool
  default = true
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
