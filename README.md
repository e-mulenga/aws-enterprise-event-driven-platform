# aws-enterprise-event-driven-platform

An enterprise-grade, event-driven order-management platform for a fictional e-commerce company ("ShopSphere Global"), built entirely in Terraform on top of an existing [aws-enterprise-landing-zone](https://github.com/e-mulenga/aws-enterprise-landing-zone) deployment. Demonstrates event-driven architecture, serverless platform engineering, DevSecOps, cloud security, enterprise integration patterns, disaster recovery, observability, FinOps and responsible-AI readiness — all consuming, never duplicating, the Landing Zone's foundational infrastructure.

- **Regions:** af-south-1 (primary) and eu-west-1 (disaster recovery) — the same two Regions the Landing Zone governs.
- **Design rule:** this repository creates only workload-layer resources. It never creates a VPC, subnet, Organization resource, central log bucket, OIDC provider, Route 53 zone, or Bedrock guardrail — see the [Ownership Matrix](docs/landing-zone-dependency-matrix.md).

## Executive summary
ShopSphere Global's current order-management system is a tightly-coupled monolith: a slow partner API or notification provider backs up checkout, every new integration requires a full redeploy, and there's no visibility into where an order actually is. This platform replaces direct service-to-service calls with durable, replayable events — EventBridge for content-based routing, SQS for durable point-to-point processing with DLQs, SNS for fan-out, Lambda for serverless compute, and DynamoDB for an on-demand, stream-enabled data layer. See [docs/business-case.md](docs/business-case.md) for the full problem statement and benefits analysis.

## What it builds
| Capability | Module(s) | Dev default |
|---|---|---|
| Landing Zone consumption | `landingzone-data` | Always on — the sole remote-state reader |
| Security | `security` | AWS-managed keys; CMKs only in prod |
| Data layer | `dynamodb` | 3 on-demand tables, Streams + PITR; Global Tables off |
| Messaging | `sqs`, `sns` | 4 SQS queues + DLQs, 3 SNS topics |
| Event backbone | `eventbridge` | Custom bus, 4 rules, archive (replay) on |
| Compute | `lambda` | 3 functions: api_handler, orders_worker, inventory_worker |
| API | `api-gateway` | HTTP API; custom domain off |
| Resilience | `disaster-recovery` | Event-archive S3 bucket; CRR off |
| AI readiness | `ai-integration` | Off (`enable_ai_integration=false`) |
| Observability | `monitoring` | Dashboard + alarms; Managed Grafana off |

## Repository layout
```
architecture/{diagrams,drawio,mermaid}/   12 required diagrams (Mermaid primary + draw.io XML)
docs/                                      business case, security review, DR strategy, AI governance,
                                            FinOps/cost analysis, ADRs, deployment guide, dependency matrix
environments/{dev,test,prod}/              backend.tf + tfvars.example (real tfvars are git-ignored)
modules/                                    landingzone-data, api-gateway, eventbridge, sqs, sns, lambda,
                                            dynamodb, security, monitoring, ai-integration, disaster-recovery
scripts/                                    bootstrap-state.sh, setup-oidc.sh, plan-guard.sh, rollback.sh
runbooks/                                   DLQ handling, event replay, DR failover, throttling, queue depth
pipelines/                                  CI/CD design reference (executable workflows live in .github/workflows)
validation/                                 validate-event-platform.sh
.github/workflows/                          plan (PR), apply (manual + approval), security scan
```

## Reference event flows
```
Client → API Gateway → Lambda → SQS → Worker Lambda → DynamoDB
Event Producers → EventBridge → Rules → Target Services (SQS / SNS)
```
See [architecture/mermaid/03-event-flow.mmd](architecture/mermaid/03-event-flow.mmd) for the full sequence, including the DLQ path.

## Landing Zone integration
Every Landing Zone value this platform needs — VPC/subnet IDs, Route 53 zone, ACM certificate, GitHub OIDC provider, Bedrock guardrails, AI audit bucket — is read through exactly one module, `modules/landingzone-data`, via `data.terraform_remote_state`. No other module touches that remote state directly ([ADR 0001](docs/adr/0001-single-remote-state-reader.md)). Full consumed-vs-created breakdown: [docs/landing-zone-dependency-matrix.md](docs/landing-zone-dependency-matrix.md).
```hcl
data "terraform_remote_state" "landing_zone" {
  backend = "s3"
  config = {
    bucket  = var.state_bucket
    key     = var.state_key
    region  = var.state_region # defaults to us-east-1 — see ADR 0002
    encrypt = true
  }
}
```

## Deploy
```bash
bash scripts/bootstrap-state.sh <state-bucket> dev
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars   # edit bucket/key to match your deployment
tofu init -backend-config=environments/dev/backend.hcl
tofu plan -var-file=environments/dev/terraform.tfvars -out=tfplan
tofu show -json tfplan > plan.json && bash scripts/plan-guard.sh plan.json
tofu apply tfplan
bash validation/validate-event-platform.sh dev
```
Full walkthrough, including the API smoke test: [docs/deployment-guide.md](docs/deployment-guide.md).

## Service selection
Every event-processing service (API Gateway, EventBridge, SQS, SNS, Lambda, Step Functions) evaluated against why it was selected, business value, security implications, cost implications and alternatives considered: [docs/service-selection-rationale.md](docs/service-selection-rationale.md). Data layer (DynamoDB vs Aurora vs RDS) and messaging strategy (SQS vs SNS vs EventBridge) have their own dedicated docs: [data-layer-decision.md](docs/data-layer-decision.md), [messaging-strategy.md](docs/messaging-strategy.md).

## Security
Least-privilege per-function IAM, VPC-scoped Lambdas in the Landing Zone's private subnets, environment-appropriate encryption, and a threat model covering spoofing/tampering/repudiation/disclosure/DoS/privilege-escalation vectors specific to this architecture: [docs/security-review.md](docs/security-review.md).

**Encryption strategy:** Development and Test environments use AWS-managed encryption keys to reduce AWS KMS operational costs and administrative overhead while maintaining encryption at rest. Production environments use Customer Managed Keys (CMKs) to support enterprise governance, auditability, compliance, and security requirements.

## Reliability & disaster recovery
Target: **99.95% availability, 15-minute RTO, 5-minute RPO.** DLQs on every queue and rule target, EventBridge Archive for event replay, DynamoDB Streams + PITR, optional Global Tables and S3 Cross-Region Replication for a data-warm/compute-cold DR posture. Full strategy and the operational runbook: [docs/dr-strategy.md](docs/dr-strategy.md), [runbooks/dr-failover.md](runbooks/dr-failover.md).

## Observability
CloudWatch dashboard (queue depth, DLQ count, Lambda errors/throttles/duration, EventBridge failures, API 4xx/5xx), per-metric alarms to a dedicated `platform-alerts` SNS topic, X-Ray tracing on every Lambda, and an optional Amazon Managed Grafana workspace.

## AI & responsible-AI readiness
`modules/ai-integration` (off by default) demonstrates AI-assisted event routing, consuming — never creating — the Landing Zone's Bedrock guardrail, approved-models policy, and AI audit bucket. Assessment, threat model and responsible-AI review: [docs/ai-governance-assessment.md](docs/ai-governance-assessment.md), [docs/ai-threat-model.md](docs/ai-threat-model.md), [docs/responsible-ai-review.md](docs/responsible-ai-review.md).

## Cost / FinOps
Dev and Test default every optional, cost-bearing feature off (cross-Region replication, Global Tables, Managed Grafana, custom domain). Full FinOps review plus dedicated Lambda/EventBridge/SQS/KMS cost analyses: [docs/cost-analysis.md](docs/cost-analysis.md).

## Well-Architected review
Mapped against all six pillars, scoped to what this consumer-only repository controls: [docs/well-architected-review.md](docs/well-architected-review.md).

## Public reference architectures
- [AWS Architecture Center](https://aws.amazon.com/architecture/)
- [AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/)
- [AWS Security Reference Architecture](https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/)
- [AWS Event-Driven Architecture guidance](https://aws.amazon.com/event-driven-architecture/)

## Skills demonstrated
Event-driven architecture design · AWS serverless platform engineering (API Gateway, EventBridge, SQS, SNS, Lambda, DynamoDB) · multi-repository Terraform remote-state consumption patterns · DevSecOps (least-privilege IAM, environment-conditional encryption, OIDC-based CI/CD, plan-time guardrails) · disaster recovery design for 99.95%/15min/5min targets · FinOps-aware architecture · responsible AI governance consumption · architecture documentation and diagramming at an enterprise level.

## Interview talking points
- Why a single `landingzone-data` module, not twelve modules each reading remote state — and what that isolation actually buys ([ADR 0001](docs/adr/0001-single-remote-state-reader.md)).
- The deliberate correction of the state-bucket-Region example, and how that was verified against the real deployed Landing Zone ([ADR 0002](docs/adr/0002-state-region-correction.md)).
- Why domain events go through SQS and business events through SNS, both fronted by EventBridge — not Lambda invoked directly from EventBridge ([ADR 0004](docs/adr/0004-messaging-service-per-event-type.md)).
- The data-warm/compute-cold DR trade-off, and what it costs to tighten the RTO further ([docs/dr-strategy.md](docs/dr-strategy.md)).
- Where the AI integration module's governance is solid and where it's intentionally incomplete for a production feature ([docs/ai-threat-model.md](docs/ai-threat-model.md)).

## Future enhancements
[docs/future-enhancements.md](docs/future-enhancements.md) — Step Functions for multi-step sagas, Aurora for relational reporting, a pre-warmed DR compute layer, WAF, cost anomaly detection, and more.

## Disclaimer
This is a portfolio/demonstration repository. "ShopSphere Global" is a fictional company used to ground architecture decisions in a concrete scenario — every AWS resource defined here is real and deployable, but this is not a production system. Pricing figures in [docs/cost-analysis.md](docs/cost-analysis.md) are directional estimates, not a committed budget. Formatted with `tofu fmt` and cross-checked for module/variable/output consistency with a custom script; not yet applied to a live AWS account as part of this build.

## License
[MIT](LICENSE)

---

## Author

**Emmanuel Mulenga** — Multi-Cloud Engineer
- 🌐 [![LinkedIn](https://img.shields.io/badge/LinkedIn-0A66C2?style=flat&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/emmanuel-mulenga)
- 💻 [![GitHub Profile](https://img.shields.io/badge/GitHub-e--mulenga-181717?style=flat&logo=github)](https://github.com/e-mulenga)

---