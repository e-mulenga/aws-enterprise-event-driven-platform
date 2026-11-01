# Data Layer Decision: DynamoDB vs Aurora PostgreSQL vs RDS PostgreSQL

## Requirement
Support three entities — Customer Profiles, Orders, Event Metadata — in a platform whose primary interaction pattern is event-driven writes (an event arrives, a record is written or updated) rather than complex relational queries across entities.

## Comparison

| Criterion | DynamoDB | Aurora PostgreSQL | RDS PostgreSQL |
|---|---|---|---|
| Idle cost (on-demand billing) | $0 — pay per request | Minimum 1 instance running continuously (or Aurora Serverless v2, still has a minimum ACU floor) | Minimum 1 instance running continuously |
| Native event-sourcing integration | DynamoDB Streams feed Lambda directly, no polling | Requires a CDC tool (DMS, Debezium) bolted on | Same as Aurora |
| Multi-Region | Global Tables — multi-Region active-active, seconds-level replication | Aurora Global Database — one writer Region, read replicas elsewhere | Cross-Region read replica only, manual promotion |
| Query flexibility | Key/GSI access patterns only — no ad hoc joins | Full SQL, joins, aggregate queries | Full SQL, joins, aggregate queries |
| Operational overhead | None — no patching, no connection pooling to manage | Engine version patching, connection pooling (RDS Proxy recommended with Lambda) | Same as Aurora, plus no serverless option |
| Lambda connection handling | Native SDK calls, no connection limit concerns | Needs RDS Proxy to avoid exhausting connections under Lambda's concurrency bursts | Same |

## Decision
**DynamoDB**, for all three entities. The deciding factors: (1) zero idle cost matches this platform's FinOps posture and bursty, event-triggered traffic; (2) Streams give native, pollless integration with the Lambda event-processing model already used throughout the platform; (3) Global Tables provide the multi-Region story the 5-minute RPO target needs without a separate failover controller.

## Where this trade-off would reverse
If this platform later needs genuine relational reporting — multi-entity joins, ad hoc analytical queries across orders and customers — Aurora PostgreSQL (not RDS, for its faster failover and serverless scaling) would be the better fit for that specific workload, likely added alongside DynamoDB (e.g., via DynamoDB Streams → Lambda → Aurora) rather than replacing it. `docs/future-enhancements.md` records this as a candidate addition once a concrete reporting requirement exists.
