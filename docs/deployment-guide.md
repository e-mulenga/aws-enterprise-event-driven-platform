# Deployment Guide

## Prerequisites
- The [aws-enterprise-landing-zone](https://github.com/e-mulenga/aws-enterprise-landing-zone) repository already deployed for the target environment, and its Terraform state bucket/key known.
- OpenTofu/Terraform ≥ 1.6, AWS CLI configured.

## 1. Confirm the Landing Zone state is reachable
```bash
bash scripts/bootstrap-state.sh <state-bucket> <env>
```

## 2. Set up the GitHub Actions deploy role (once per environment)
```bash
GITHUB_ORG=<org> GITHUB_REPO=aws-enterprise-event-driven-platform \
ENV=dev AWS_ACCOUNT_ID=<id> \
LANDING_ZONE_OIDC_PROVIDER_ARN=<github_oidc_provider_arn from Landing Zone outputs> \
bash scripts/setup-oidc.sh
```

## 3. Configure variables (never commit terraform.tfvars)
```bash
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars
# edit landing_zone_state_bucket / landing_zone_state_key to match your deployment
```

## 4. Plan and apply
```bash
tofu init -backend-config=environments/dev/backend.hcl
tofu plan -var-file=environments/dev/terraform.tfvars -out=tfplan
tofu show -json tfplan > plan.json && bash scripts/plan-guard.sh plan.json
tofu apply tfplan
bash validation/validate-event-platform.sh dev
```

## 5. Test the API
```bash
curl -X POST "$(tofu output -raw api_endpoint)/orders" \
  -H 'content-type: application/json' \
  -d '{"customer_id": "cust-001", "items": [{"sku": "ABC123", "qty": 1}]}'
```

## Promoting to test / prod
Repeat steps 2–5 with `ENV=test` / `ENV=prod` and the matching `environments/<env>/` files. Prod additionally needs `kms_strategy = "customer-managed"` confirmed in its tfvars (it's the default in `terraform.tfvars.example`) and an approved GitHub Environment protection rule for the manual-approval gate in `.github/workflows/apply.yml`.

## Tearing down
```bash
tofu destroy -var-file=environments/dev/terraform.tfvars
```
`scripts/plan-guard.sh` will also run against a destroy plan in CI and block it if it targets a protected resource type — a destroy of the whole stack is expected to trip that guard by design; run it manually, outside CI, with full awareness of what's being removed.
