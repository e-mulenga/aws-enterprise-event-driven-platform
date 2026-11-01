terraform {
  backend "s3" {
    bucket       = "REPLACE-ME-terraform-state"
    key          = "event-driven-platform/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
