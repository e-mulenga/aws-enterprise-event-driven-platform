# Landing Zone Dependency Matrix

This repository is a pure **consumer** of the [aws-enterprise-landing-zone](https://github.com/e-mulenga/aws-enterprise-landing-zone) repository's Terraform state. It never creates a VPC, subnet, Organization resource, central log bucket, OIDC provider, Route 53 zone, or Bedrock guardrail — see `modules/landingzone-data`, the single module permitted to read the Landing Zone's remote state (`docs/adr/0001-single-remote-state-reader.md`).

## Ownership Matrix

| Resource | Landing Zone | Event Platform |
|---|---|---|
| VPC | ✅ | ❌ |
| Subnets | ✅ | ❌ |
| CloudTrail | ✅ | ❌ |
| Config | ✅ | ❌ |
| Route53 Zone | ✅ | ❌ |
| GitHub OIDC | ✅ | ❌ |
| Bedrock Guardrails | ✅ | ❌ |
| EventBridge | ❌ | ✅ |
| SQS | ❌ | ✅ |
| SNS | ❌ | ✅ |
| Lambda | ❌ | ✅ |
| DynamoDB | ❌ | ✅ |
| API Gateway | ❌ | ✅ |
| CloudWatch Dashboards | ❌ | ✅ |

## Consumed outputs

| Landing Zone output | Consumed by | Used for |
|---|---|---|
| `organization_id`, `organization_arn` | `locals.tf` (tagging) | Tagging every resource with its governing Organization |
| `af_south_1.vpc_id`, `.private_subnet_ids` | `modules/security`, `modules/lambda` | Lambda VPC placement, Lambda security group |
| `eu_west_1.vpc_id`, `.private_subnet_ids` | reserved for a future DR compute deploy (see `runbooks/dr-failover.md`) | — |
| `route53_zone_id`, `route53_domain_name` | `modules/api-gateway`, `modules/disaster-recovery` | API custom domain, Route 53 health check |
| `acm_certificate_arn` | `modules/api-gateway` | API custom domain TLS certificate |
| `github_oidc_provider_arn` | `.github/workflows/*.yml`, `scripts/setup-oidc.sh` | GitHub Actions deploy-role trust policy |
| `cloudtrail_bucket_name` | `locals.tf` (tagging/reference) | Audit-trail cross-reference |
| `bedrock_guardrail_id`, `bedrock_guardrail_version`, `bedrock_guardrails_enabled` | `modules/ai-integration` | Applied to every Bedrock InvokeModel call |
| `bedrock_approved_models_policy_arn` | `modules/ai-integration` | Attached to the Lambda execution role, restricting invokable model IDs |
| `ai_audit_bucket_name` | `modules/security`, `modules/ai-integration` | AI invocation audit log destination (`event-platform/` prefix) |
| `key_strategy` | `locals.tf` (tagging/record) | Records the Landing Zone's own encryption posture alongside this repository's |

## Created by this repository

| Resource category | Module | Notes |
|---|---|---|
| API Gateway (HTTP API) | `modules/api-gateway` | Fronts `api_handler` Lambda |
| EventBridge custom bus, rules, archive | `modules/eventbridge` | Domain/Business/Integration event routing + replay |
| SQS queues + DLQs | `modules/sqs` | orders, inventory, notifications (Standard), payments (FIFO) |
| SNS topics | `modules/sns` | order-events, partner-notifications, platform-alerts |
| Lambda functions | `modules/lambda`, `modules/ai-integration` | api_handler, orders_worker, inventory_worker, ai_event_router |
| DynamoDB tables | `modules/dynamodb` | customer_profiles, orders, event_metadata |
| S3 event-archive bucket (+ CRR) | `modules/disaster-recovery` | File uploads, event payload archives, replay data, audit data |
| CloudWatch dashboard + alarms | `modules/monitoring` | Distinct from the Landing Zone's own dashboard |
| KMS CMKs (prod only) | `modules/security` | eventbridge/sqs/dynamodb/lambda/s3 — only when `kms_strategy = customer-managed` |
| Secrets Manager secret | `modules/security` | Partner API credentials placeholder |
| Route 53 health check + optional failover record | `modules/disaster-recovery`, `modules/api-gateway` | Record created inside the Landing Zone's existing zone, never a new zone |
