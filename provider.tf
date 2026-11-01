# ============================================================
# Provider configuration (no versions.tf — constraints live here)
# ============================================================
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }

  backend "s3" {}
}

# Primary Region (af-south-1) — the only Region approved for this platform
# besides the DR Region, per the Landing Zone's regional governance standard.
provider "aws" {
  region = var.primary_region

  default_tags {
    tags = local.default_tags
  }
}

# DR Region (eu-west-1)
provider "aws" {
  alias  = "dr"
  region = var.dr_region

  default_tags {
    tags = local.default_tags
  }
}

# us-east-1 is required for some global resources (CloudFront-scoped ACM
# certs, which the Landing Zone already manages) — kept as a read-only
# alias in case a future module needs it; nothing here creates resources
# in it today.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = local.default_tags
  }
}
