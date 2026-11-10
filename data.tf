data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

data "terraform_remote_state" "landing_zone" {
  count = var.enable_remote_state ? 1 : 0

  backend = "s3"

  config = {
    bucket = var.landing_zone_state_bucket
    key    = var.landing_zone_state_key
    region = var.landing_zone_state_region
  }
}
