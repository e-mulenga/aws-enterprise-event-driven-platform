# Runbook: Regional failover to eu-west-1

**RTO target: 15 minutes. RPO target: 5 minutes.**

## Pre-conditions
- `enable_global_tables = true` and `enable_cross_region_replication = true` (both default true in prod) — confirm in `environments/prod/terraform.tfvars`.
- The Route 53 health check (`modules.disaster_recovery.health_check_id`) has been failing for the primary Region's API endpoint for long enough to rule out a transient blip.

## 1. Confirm the primary Region is actually down
```bash
curl -sS -o /dev/null -w "%{http_code}\n" https://api.prod.<domain>/health
aws route53 get-health-check-status --health-check-id <health_check_id>
```

## 2. Promote the DR Region's DynamoDB replica tables
Global Tables already accept writes in eu-west-1 — no promotion step is needed, only re-pointing traffic.

## 3. Deploy the compute layer into eu-west-1
This platform's Lambda/API Gateway/EventBridge/SQS/SNS resources are Regional and are NOT pre-deployed in eu-west-1 by default (cost: a fully warm standby roughly doubles the compute-layer bill — see `docs/cost-analysis.md`). Apply the same root module with `primary_region = "eu-west-1"` and `dr_region = "af-south-1"` against a dedicated `environments/prod-dr/` tfvars (create from `environments/prod/terraform.tfvars.example`, swapping the Regions) to stand up the compute layer against the already-replicated data.

## 4. Re-point DNS
Update the Route 53 failover record (or, if not using failover routing, update the A/ALIAS record directly) to the eu-west-1 API Gateway custom domain.

## 5. Validate
```bash
bash validation/validate-event-platform.sh prod-dr
```

## 6. Failback
Once af-south-1 recovers, reverse the process deliberately — do not let both Regions accept writes simultaneously for longer than necessary; Global Tables use last-writer-wins conflict resolution, which can silently drop a write made in the losing Region during the overlap window.
