variable "state_bucket" {
  description = "S3 bucket holding the AWS Enterprise Landing Zone Terraform state."
  type        = string
}

variable "state_key" {
  description = "State object key for the target Landing Zone environment, e.g. landing-zone/dev/terraform.tfstate."
  type        = string
}

variable "state_region" {
  description = "Region of the Landing Zone state bucket."
  type        = string
  default     = "us-east-1"
}
