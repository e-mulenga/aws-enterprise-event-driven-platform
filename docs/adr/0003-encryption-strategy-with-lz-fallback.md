# ADR 0003: Production CMKs are repository-scoped, not sourced from the Landing Zone

## Status
Accepted

## Context
Production to "use Landing Zone CMKs when available, otherwise create repository-scoped CMKs." The Landing Zone's own `shared_kms_keys` output (`docs/consumption-guide.md` in that repository) currently publishes only AWS-managed key aliases in every environment it has deployed so far (`key_strategy = "aws-managed"` at the Landing Zone level) — it has no customer-managed keys to offer this platform yet.

## Decision
`modules/security` always creates its own repository-scoped CMKs when `kms_strategy = "customer-managed"` (prod), rather than attempting to conditionally source a Landing Zone key that doesn't currently exist. `local.lz.key_strategy` is still read and recorded in tags for audit visibility (so it's clear what the Landing Zone's own posture was at deploy time), but no code path tries to reuse a Landing Zone CMK.

## Consequences
- The "use Landing Zone CMKs when available" condition is honored in spirit (there currently are none available) without dead code trying to reference an output the Landing Zone doesn't publish.
- If the Landing Zone is later extended to publish per-service CMK ARNs for workload repositories to share, `modules/security/main.tf`'s `for_each` over `local.cmk_services` is the single place to add a conditional: reuse the Landing Zone's key if its ARN is non-null, else create one here. This is recorded as a candidate in `docs/future-enhancements.md`.
