# Future Enhancements

Recorded here rather than implemented now, each with the reason it wasn't done in this build:

1. **Step Functions for multi-step order fulfillment.** Not needed yet — the current flow is linear enough for EventBridge + SQS. Add once a genuine multi-step saga (multi-partner fulfillment, compensating transactions) exists. See `docs/service-selection-rationale.md`.
2. **Aurora PostgreSQL alongside DynamoDB** for relational/analytical reporting, fed via DynamoDB Streams, once a concrete cross-entity reporting requirement exists. See `docs/data-layer-decision.md`.
3. **Landing Zone-published CMKs**, if the Landing Zone is extended to offer per-service customer-managed keys to consuming repositories — `modules/security` is the single place to wire in a conditional reuse-or-create. See ADR 0003.
4. **Pre-warmed DR compute layer** (a standing `environments/prod-dr/` deployment) to shrink RTO below the current manual-apply-driven estimate, once traffic volume justifies roughly doubling the compute-layer cost. See `docs/dr-strategy.md`.
5. **DLQ on the AI router's own Lambda target**, closing the gap noted in `docs/ai-threat-model.md`, before any production use of the AI integration path.
6. **CloudWatch alarm on `bedrock_guardrails_enabled` flipping false** in prod, so a Landing Zone governance regression is detected automatically rather than only on the next deploy. See `docs/responsible-ai-review.md`.
7. **AWS WAF in front of API Gateway** before this platform carries real customer traffic. See `docs/security-review.md`.
8. **AWS Budgets / Cost Anomaly Detection** scoped to this platform's tags, once real traffic volume makes the cost estimates in `docs/cost-analysis.md` worth monitoring continuously rather than reviewing periodically.
9. **Narrower `bedrock:InvokeModel` resource scoping** in `modules/ai-integration`, rather than relying solely on the attached Landing Zone approved-models policy. See `docs/security-review.md`.
