# FinOps Review & Cost Analysis

Prices below are us-east-1/af-south-1-class on-demand list prices at the time of writing, for order-of-magnitude planning — always confirm current pricing before a real deployment. This single document covers the FinOps Review, overall Cost Analysis, and the dedicated Lambda, EventBridge, SQS and KMS cost analyses the source requirements list as separate deliverables.

## Mandatory cost-optimization statement
Development and Test environments use AWS-managed encryption keys to reduce AWS KMS operational costs and administrative overhead while maintaining encryption at rest. Production environments use Customer Managed Keys (CMKs) to support enterprise governance, auditability, compliance, and security requirements.

## FinOps review — what drives cost in this platform
| Cost driver | Dev/Test posture | Prod posture |
|---|---|---|
| KMS | AWS-managed keys — $0 | CMKs — $1/key/month + $0.03 per 10K requests |
| Cross-Region replication | Off (`enable_cross_region_replication=false`) | On |
| DynamoDB Global Tables | Off | On (`enable_global_tables=true`) |
| Managed Grafana | Off | On |
| Custom domain | Off | On |
| Log retention | 14/30 days | 90 days |

Every one of these is a variable in `environments/<env>/terraform.tfvars`, not a hardcoded resource — the cost/governance trade-off is explicit and reviewable per environment.

## Lambda cost analysis
- **Pricing:** $0.20 per 1M requests + $0.0000166667 per GB-second.
- **This platform's functions:** `api_handler`, `orders_worker`, `inventory_worker` at 256MB; `ai_event_router` at 256MB (test/prod only).
- **Estimate at 100K orders/month** (≈400K total invocations across the four functions, ~300ms average duration): request cost ≈ $0.08; compute cost ≈ 400,000 × 0.3s × 0.25GB × $0.0000166667 ≈ **$0.50/month**. Negligible at this volume — Lambda's pay-per-invocation model is precisely why it was selected over an always-on compute option (see `docs/service-selection-rationale.md`).
- **Where this grows:** VPC-attached Lambda cold starts add latency, not direct cost, but X-Ray tracing and CloudWatch Logs scale with invocation count and are a secondary cost line worth monitoring at 10x this volume.

## EventBridge cost analysis
- **Pricing:** $1.00 per 1M events published to a custom bus. Archive (replay) storage is billed per GB-month on top of that.
- **Estimate at 100K orders/month:** each order generates roughly 2–3 EventBridge events (OrderCreated, OrderStatusChanged, plus inventory events) → ~300K events/month ≈ **$0.30/month** in publish cost.
- **Archive storage:** at an average event size of ~1KB and 300K events/month with 14-day dev/test retention, archive storage stays under 1GB — effectively free at this volume; a production system retaining 30 days at much higher volume should re-estimate here before enabling replay broadly.

## SQS cost analysis
- **Pricing:** $0.40 per 1M requests (Standard), $0.50 per 1M requests (FIFO).
- **Estimate at 100K orders/month:** ~300K SendMessage + ~300K ReceiveMessage + ~300K DeleteMessage across orders/inventory queues ≈ 900K requests ≈ **$0.36/month**. DLQs add negligible cost unless failure rates are high — a sustained high DLQ rate is itself a signal to investigate (see `runbooks/dlq-handling.md`), not just a cost line.

## KMS cost analysis
- **Dev/Test:** $0 — AWS-managed keys carry no per-key or (for most services) per-request charge to the customer.
- **Prod:** 5 CMKs (eventbridge, sqs, dynamodb, lambda, s3) × $1/month = $5/month, plus $0.03 per 10,000 cryptographic requests. At 100K orders/month generating roughly 2M encrypt/decrypt operations across all five keys combined, request cost ≈ **$6/month**. Total prod KMS cost ≈ **$11/month** — the direct, measurable price of the governance/auditability benefit CMKs provide, which is why the environment-conditional strategy exists rather than CMKs everywhere.

## Total estimated monthly cost (100K orders/month, excluding Landing Zone shared costs)
| Environment | Estimate |
|---|---|
| Dev | ≈ $2–5/month (serverless compute/messaging only; no replication, no Grafana, no CMKs) |
| Test | ≈ $5–10/month (adds AI integration Lambda invocations) |
| Prod | ≈ $40–70/month (adds CMKs, CRR, Global Tables, Managed Grafana ~$9/user/month, custom domain) |

These are directional estimates for a portfolio-scale workload, not a committed budget — see `docs/future-enhancements.md` for recommended next steps (AWS Budgets, Cost Anomaly Detection) before any real production traffic.
