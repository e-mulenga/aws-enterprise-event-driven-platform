variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "enable_cross_region_replication" {
  type    = bool
  default = true
}

variable "kms_key_arn" {
  description = "null uses the AWS-managed alias/aws/s3 key (dev/test). A CMK ARN in prod."
  type        = string
  default     = null
}

variable "kms_key_arn_dr" {
  description = "DR-region CMK for the replica bucket. null in dev/test."
  type        = string
  default     = null
}

variable "route53_zone_id" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "enable_custom_domain" {
  type    = bool
  default = false
}

variable "api_domain_name" {
  description = "The API's custom domain name, used as the Route 53 health-check target. null when enable_custom_domain is false."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
