# ============================================================
# modules/landingzone-data
# ============================================================
# The single place this repository reads the AWS Enterprise Landing Zone's
# Terraform state. Every other module receives normalized values from this
# module's outputs — no other module ever calls
# data.terraform_remote_state.landing_zone directly, and no other module
# creates a VPC, subnet, organisation resource, central log bucket, OIDC
# provider, Route 53 zone, or AI governance resource. Those are all owned
# by the Landing Zone and are read-only here.
# ============================================================

data "terraform_remote_state" "landing_zone" {
  backend = "s3"

  config = {
    bucket  = var.state_bucket
    key     = var.state_key
    region  = var.state_region
    encrypt = true
  }
}

locals {
  o = data.terraform_remote_state.landing_zone.outputs
}
