# ADR 0001: `modules/landingzone-data` is the sole reader of the Landing Zone's remote state

## Status
Accepted

## Context
The platform must consume the Landing Zone's outputs (VPC, subnets, DNS, OIDC, AI governance, logging buckets) and must never recreate them. If every module that needed, say, a subnet ID called `data.terraform_remote_state.landing_zone` directly, the Landing Zone's output contract would be coupled to every module in this repository, and a renamed/restructured Landing Zone output would require hunting through the whole codebase.

## Decision
Exactly one module, `modules/landingzone-data`, calls `data.terraform_remote_state.landing_zone`. It normalizes every value this platform needs into its own outputs (with `try()` wrapping for forward/backward compatibility with the Landing Zone's `contract_schema_version`). Root `locals.tf` resolves those into `local.lz.*` once, and every other module receives explicit input variables — never `module.landing_zone.*` directly.

## Consequences
- A Landing Zone output rename only requires updating `modules/landingzone-data/outputs.tf` and `locals.tf`, not every consuming module.
- Every module's `variables.tf` is self-documenting about exactly what Landing Zone data it depends on, without needing to trace through remote state.
- One minor cost: `locals.tf` is a slightly larger indirection layer than reaching into `module.landing_zone` ad hoc would be.
