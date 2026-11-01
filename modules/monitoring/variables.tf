variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "queue_names" {
  type = map(string)
}

variable "dlq_names" {
  type = map(string)
}

variable "lambda_function_names" {
  type = map(string)
}

variable "event_bus_name" {
  type = string
}

variable "api_name" {
  type = string
}

variable "alerts_topic_arn" {
  type = string
}

variable "enable_managed_grafana" {
  description = "Amazon Managed Grafana workspace — per-user/hour cost. Off by default; see docs/cost-analysis.md."
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "primary_region" {
  description = "Must match the Landing Zone's primary Region."
  type        = string
  default     = "af-south-1"
}
