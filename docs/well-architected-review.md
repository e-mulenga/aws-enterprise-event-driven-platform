# AWS Well-Architected Framework Review

Mapped against the six pillars, scoped to what this repository (consumer-only) actually controls — the Landing Zone's own review lives in its repository.

## Operational Excellence
- Infrastructure as code (Terraform/OpenTofu) end to end; `scripts/plan-guard.sh` blocks a plan that would delete/replace a protected resource before it can be applied.
- `validation/validate-event-platform.sh` gives a scripted, repeatable post-deploy check rather than manual spot-checking.
- Runbooks (`runbooks/`) codify the response to the failure modes this architecture actually has (DLQ growth, queue depth, Lambda throttling, DR failover, event replay).

## Security
- See `docs/security-review.md` for the full threat model. Headline: least-privilege per-function IAM, VPC-scoped Lambdas, environment-appropriate encryption, zero duplicated Landing Zone security controls.

## Reliability
- DLQs on every queue and EventBridge rule target; `maxReceiveCount = 5` before a message is quarantined rather than retried forever.
- EventBridge Archive gives Event Replay independent of any single queue's retention.
- DynamoDB Streams + Point-in-Time Recovery on every table.
- Optional Global Tables + S3 Cross-Region Replication meet the 99.95% / 15-min RTO / 5-min RPO targets — see `docs/dr-strategy.md`.
- **Gap, acknowledged:** the compute layer (Lambda, API Gateway, EventBridge, SQS, SNS) is not pre-deployed in the DR Region by default; failover requires a manual `terraform apply` against a DR tfvars file (`runbooks/dr-failover.md`). A warm-standby compute layer would cut RTO further at roughly double the compute-layer cost — see `docs/cost-analysis.md`.

## Performance Efficiency
- Serverless throughout (Lambda, DynamoDB on-demand, HTTP API) — the platform scales with load without capacity planning.
- X-Ray tracing on every Lambda gives per-segment latency visibility to find the actual bottleneck rather than guessing.

## Cost Optimization
- Dev/Test default every optional, cost-bearing feature (Managed Grafana, cross-Region replication, Global Tables, custom domain) to **off**.
- On-demand billing throughout (DynamoDB, Lambda, HTTP API, SQS, SNS) — no idle fixed cost.
- AWS-managed keys in Dev/Test, CMKs only where governance requires them (Prod) — see the cost-optimization statement in `docs/cost-analysis.md`.

## Sustainability
- Serverless compute means no idle EC2/RDS capacity running 24/7 for workloads that are bursty by nature — Lambda and DynamoDB on-demand scale to zero between events, reducing the always-on carbon footprint a fixed fleet would carry.
- Log retention is capped per environment (14/30/90 days) rather than kept indefinitely by default, limiting unnecessary storage.
