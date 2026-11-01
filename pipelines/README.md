# Pipelines

This folder documents the CI/CD pipeline design the source requirements asked for as a standalone deliverable. The pipelines that actually execute are GitHub Actions workflows under [`.github/workflows/`](../.github/workflows) (GitHub Actions only runs workflows from that path) — the YAML here is a readable, deploy-target-agnostic reference copy kept in sync with them, useful if this platform is ever ported to another CI system.

| Stage | Trigger | What it does |
|---|---|---|
| [`plan.yml`](plan.yml) | Pull request | `terraform init` + `plan`, posts the plan as a PR comment, runs `scripts/plan-guard.sh` against the plan JSON |
| [`apply.yml`](apply.yml) | Push to `main` (manual approval gate) | `terraform apply`, then `validation/validate-event-platform.sh` |
| [`security-scan.yml`](security-scan.yml) | Pull request | `tflint` + `checkov` static analysis |

All three authenticate to AWS via the Landing Zone's existing GitHub OIDC provider (`github_oidc_provider_arn`) — no long-lived AWS credentials are stored in GitHub.
