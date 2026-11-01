terraform {
  backend "s3" {
    bucket       = "REPLACE-ME-terraform-state"
    key          = "event-driven-platform/prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
