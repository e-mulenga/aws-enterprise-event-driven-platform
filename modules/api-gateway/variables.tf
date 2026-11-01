variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "lambda_invoke_arn" {
  type = string
}

variable "lambda_function_name" {
  type = string
}

variable "enable_custom_domain" {
  type    = bool
  default = false
}

variable "route53_zone_id" {
  description = "Landing Zone's existing hosted zone — never created here."
  type        = string
}

variable "domain_name" {
  description = "Landing Zone's existing domain (e.g. emulenga.com)."
  type        = string
}

variable "acm_certificate_arn" {
  description = "Landing Zone's existing wildcard ACM certificate — never created here."
  type        = string
}

variable "throttle_burst_limit" {
  type    = number
  default = 200
}

variable "throttle_rate_limit" {
  type    = number
  default = 100
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
