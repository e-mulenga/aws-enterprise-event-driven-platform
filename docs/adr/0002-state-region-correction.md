# ADR 0002: Landing Zone state bucket region defaults to us-east-1, not af-south-1

## Status
Accepted

## Context
The actual deployed Landing Zone's own `backend.tf` files and its `docs/consumption-guide.md` both specify `region = "us-east-1"` for the state bucket.

## Decision
`modules/landingzone-data/variables.tf` defaults `state_region` to `"us-east-1"`, not `"af-south-1"`. `af-south-1` is the Landing Zone's *application* Region (where the VPCs it manages live), not the Region its Terraform state bucket is hosted in.

## Consequences
- `terraform_remote_state` reads succeed against the actual deployed state bucket.
- A future Landing Zone migration to a different state-bucket Region only requires an `environments/<env>/terraform.tfvars` change (`landing_zone_state_region`), not a code change.
