# Security Architecture, Threat Model & Risk Assessment

## Security architecture summary
- **Identity:** Lambda functions run under one shared, least-privilege execution role (`modules/security`); each function's *own* resource access (which DynamoDB table, which queue, which event bus) is granted by a separate inline policy attached by the module that creates that resource (`modules/lambda`, `modules/ai-integration`) — avoiding both an overly broad shared policy and a circular module dependency. Human access to the AWS account continues to go through the Landing Zone's IAM Identity Center; this repository creates no human-facing IAM users or roles.
- **Network:** every Lambda runs inside the Landing Zone's existing private subnets, behind an egress-only security group this repository owns (`modules/security`). No VPC, subnet, NAT, or route table is created here.
- **Encryption:** Dev and Test use AWS-managed keys (`alias/aws/sqs`, `alias/aws/s3`, `alias/aws/lambda`, DynamoDB's AWS-owned default). Production uses repository-scoped Customer Managed Keys (`eventbridge-prod-key`, `sqs-prod-key`, `dynamodb-prod-key`, plus `lambda-prod-key` and `s3-prod-key`) with automatic annual rotation. See the mandatory cost-optimization statement in `docs/cost-analysis.md`.
- **Secrets:** partner API credentials are a Secrets Manager placeholder (`modules/security`) — never a Terraform-managed literal value.
- **Audit:** every resource is tagged with `LandingZoneSource = <organization_id>`; API Gateway access logs, Lambda logs and the EventBridge archive together give a full request-to-event trail. AI invocations are additionally logged to the Landing Zone's AI audit bucket.

## Threat model (STRIDE-structured, abbreviated)

| Threat | Vector in this platform | Mitigation |
|---|---|---|
| Spoofing | A principal other than EventBridge calling `sqs:SendMessage`/`sns:Publish` on this platform's queues/topics | Queue/topic policies condition on `aws:SourceArn` matching the specific rule ARN, not just the `events.amazonaws.com` service principal |
| Tampering | A message modified in transit or at rest | TLS in transit (AWS SDK default); SSE at rest on every queue, topic, table and bucket |
| Repudiation | "We never received that event" disputes | EventBridge archive retains every event for `event_retention_days`; `event_metadata` table and CloudTrail (Landing Zone) provide independent corroboration |
| Information disclosure | Overly broad IAM, or a public S3 bucket | Event-archive bucket has `block_public_acls`/`restrict_public_buckets` all true; every Lambda policy is scoped to specific resource ARNs, not `*`, except the Bedrock invoke statement (see Known limitation below) |
| Denial of service | A burst of malformed requests exhausting Lambda concurrency | API Gateway throttling (burst/rate limits); DLQs isolate poison messages so they stop consuming retry capacity after `dlq_max_receive_count` |
| Elevation of privilege | A compromised Lambda using its execution role beyond its intended scope | Per-function inline policies (not the broad shared role alone) scope each function to the specific resources it actually touches |

## Known limitation
`modules/ai-integration`'s `aws_iam_role_policy.bedrock_invoke` uses `Resource = "*"` for `bedrock:InvokeModel`, narrowed in practice by the Landing Zone's `bedrock_approved_models_policy_arn` attached to the same role (which restricts invokable model IDs). A stricter build would scope the inline statement itself to specific model ARNs; this is documented rather than silently left for a reviewer to find — see `docs/ai-threat-model.md`.

## Residual risk accepted for this portfolio build
- No WAF in front of API Gateway (would add cost with no attacker traffic to defend against in a demo deployment) — recorded as a prod-readiness gap in `docs/future-enhancements.md`.
- No automated secret rotation configured on the Secrets Manager placeholder (no real credential is stored yet).
