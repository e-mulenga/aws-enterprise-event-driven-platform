# Disaster Recovery, Backup & Event Replay Strategy

**Targets: Availability 99.95% · RTO 15 minutes · RPO 5 minutes.**

## Disaster recovery strategy
This platform follows a **data-warm, compute-cold** DR pattern:

| Layer | DR posture | Why |
|---|---|---|
| DynamoDB | Global Tables (optional, `enable_global_tables`) — data replicates to eu-west-1 in near-real-time | Meets the 5-minute RPO without a separate replication pipeline |
| S3 event archive | Cross-Region Replication (optional, `enable_cross_region_replication`) | Same RPO rationale for file/event-payload data |
| EventBridge, SQS, SNS, Lambda, API Gateway | **Not** pre-deployed in eu-west-1 | These are stateless and cheap to stand up on demand; pre-warming them roughly doubles the compute-layer bill for a Region that's idle 99.95%+ of the time — see `docs/cost-analysis.md` |
| DNS | Route 53 health check against the primary API endpoint (`modules/disaster-recovery`) | Detects the failure that triggers the runbook |

Failover is a deliberate, runbook-driven action (`runbooks/dr-failover.md`), not an automatic Route 53 failover record in this build — automatic failover without a pre-warmed DR compute layer would just point traffic at infrastructure that doesn't exist yet. The 15-minute RTO target assumes the on-call engineer starts the DR `terraform apply` promptly; a future enhancement (recorded in `docs/future-enhancements.md`) is a documented, pre-tested `terraform apply -var-file=environments/prod-dr/terraform.tfvars` runbook step to shrink that window further, or moving to full automatic failover with a pre-warmed standby once traffic volume justifies the cost.

## Backup strategy
- **DynamoDB:** Point-in-Time Recovery enabled on every table (35-day continuous backup window), independent of Global Tables.
- **S3 event archive:** versioning enabled; a lifecycle policy tiers `replay-data/` to STANDARD_IA (30 days) then GLACIER (90 days), and expires `event-archive/` objects after 365 days — see `modules/disaster-recovery/main.tf`.
- **Terraform state:** the state bucket (owned by the Landing Zone) has versioning enabled; `scripts/rollback.sh` documents recovering a previous state version if a bad apply needs to be reverted.

## Event replay strategy
- The EventBridge **Archive** (`enable_event_replay`) is the primary replay mechanism — `aws events start-replay` reconstructs a time window of history through the bus's normal rules/targets. See `runbooks/event-replay.md` for the operational procedure, including the idempotency requirement on consuming workers (this platform's workers key writes by `order_id`/`event_id`, making a replay safe).
- A message's own **DLQ** is the secondary, narrower replay path — `aws sqs start-message-move-task` redrives a specific failed message back to its source queue once the cause is fixed. See `runbooks/dlq-handling.md`.
- The two are for different situations: use the archive to reprocess a correctly-delivered-but-incorrectly-handled time window (a worker bug); use the DLQ redrive for individual messages that failed delivery/processing outright.
