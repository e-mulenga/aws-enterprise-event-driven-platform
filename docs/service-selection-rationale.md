# Service Selection Rationale

Each event-processing service the source requirements asked to be evaluated, in the same five-point format: why selected, business value, security implications, cost implications, alternatives evaluated.

## Amazon API Gateway (HTTP API)
- **Why selected:** the only managed, serverless way to expose a REST entry point with built-in throttling, CORS, access logging and a native Lambda proxy integration.
- **Business value:** zero infrastructure to patch or scale; a new route is a Terraform change, not a new server.
- **Security implications:** request throttling limits abuse; access logs feed the audit trail; a custom domain carries the Landing Zone's existing TLS certificate rather than a self-managed one.
- **Cost implications:** pay-per-request (~$1.00 per million requests for HTTP APIs, versus ~$3.50 for REST APIs) — selected over the v1 REST API specifically for this ~70% saving, at the cost of usage plans/API keys/request transformation, none of which this platform currently needs.
- **Alternatives evaluated:** REST API (v1) — rejected on cost for this workload; Application Load Balancer + Lambda — rejected, no built-in request throttling or native OpenAPI-style route management.

## Amazon EventBridge
- **Why selected:** the only AWS service built around schema-aware, content-based event routing with native SaaS/partner-integration support and a built-in replay/archive capability.
- **Business value:** new consumers subscribe to existing events without the producer knowing or changing — directly answers the "slow integration development" pain point.
- **Security implications:** rule-level `event_pattern` filtering is the enforcement boundary for who gets which event; resource policies on targets (SQS, SNS) scope delivery to specific rule ARNs, not the whole bus.
- **Cost implications:** $1.00 per million events published; archive storage is billed separately and scales with retention — set deliberately per environment (`event_retention_days`: 14 dev/test, 30 prod).
- **Alternatives evaluated:** SNS alone — rejected, no content-based filtering or native replay; a self-managed Kafka/MSK cluster — rejected as disproportionate operational overhead for this event volume.

## Amazon SQS
- **Why selected:** the standard AWS pattern for point-to-point, durable, ordered-when-needed (FIFO) decoupling between a producer and exactly the workers that must process each message.
- **Business value:** a slow or failing worker backs up its own queue instead of cascading into the producer — directly answers "failure propagation."
- **Security implications:** queue policies scope `sqs:SendMessage` to the specific EventBridge rule ARN that should be allowed to deliver, not any principal; DLQs preserve a forensic record of what failed.
- **Cost implications:** $0.40 per million requests (Standard) / $0.50 per million (FIFO) — negligible at this platform's expected volume; the DLQ's 14-day max retention is itself a (small) storage-adjacent cost worth noting at scale.
- **Alternatives evaluated:** Kinesis Data Streams — rejected, built for ordered high-throughput streaming/analytics, not per-message worker dispatch with native DLQ semantics.

## Amazon SNS
- **Why selected:** the standard AWS pattern for fan-out — one business event (e.g. `OrderStatusChanged`) reaching multiple independent subscribers (notifications, analytics, partner webhooks) without the publisher enumerating them.
- **Business value:** adding a new subscriber to "an order shipped" is a new subscription, not a code change to the order service.
- **Security implications:** topic policies restrict `sns:Publish` to the specific EventBridge rule; subscriber confirmation (for email/HTTP(S) endpoints) prevents unauthorized subscription.
- **Cost implications:** $0.50 per million publishes; email notifications are billed separately and trivial at this platform's alert volume.
- **Alternatives evaluated:** EventBridge rules with multiple direct targets — viable for a small, fixed subscriber set, but doesn't support external parties self-subscribing the way an SNS topic does.

## AWS Lambda
- **Why selected:** the only compute option with zero idle cost that matches this platform's bursty, event-triggered workload (an order arrives, a queue message arrives) rather than a steady request rate.
- **Business value:** compute spend tracks actual order volume — directly answers "increasing operational costs" from an always-on monolith.
- **Security implications:** each function runs under the shared least-privilege execution role plus its own scoped inline policy (see `modules/lambda/main.tf`); VPC placement in the Landing Zone's private subnets keeps functions off the public internet.
- **Cost implications:** $0.20 per million requests + per-GB-second duration billing; X-Ray tracing and CloudWatch Logs are a secondary but real cost at scale — retention is environment-scoped (14/30/90 days).
- **Alternatives evaluated:** ECS Fargate — rejected, pays for allocated task time regardless of invocation rate, a worse fit for this platform's spiky traffic; EC2 — rejected outright, contradicts the serverless design goal.

## AWS Step Functions (evaluated, not currently used)
- **Why evaluated:** the source requirements ask every listed service to be evaluated, and Step Functions is the natural fit for a multi-step order-fulfillment saga (reserve inventory → charge payment → confirm order → notify) that needs visual state tracking and built-in retry/compensation logic.
- **Business value, if adopted:** would replace an implicit, Lambda-code-encoded workflow with an explicit, versioned state machine — easier to reason about and demo to stakeholders.
- **Security implications:** a Step Functions execution role would need to be scoped per state, same least-privilege principle as the Lambda role.
- **Cost implications:** Standard workflows bill $0.025 per 1,000 state transitions — cheap at this platform's volume, but an added cost line with no functional gap it closes yet.
- **Decision:** not implemented in this build. The current order flow (API Gateway → Lambda → SQS → Worker Lambda → DynamoDB) is linear enough that EventBridge + SQS already provide the needed decoupling and retry semantics. `docs/future-enhancements.md` records Step Functions as the first addition once a genuine multi-step saga (e.g., a multi-partner fulfillment workflow) exists.
