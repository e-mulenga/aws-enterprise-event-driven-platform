# AI Threat Model

Scoped to `modules/ai-integration`'s placeholder event router.

| Threat | Description | Mitigation / residual risk |
|---|---|---|
| Prompt injection via event payload | An attacker-controlled field in an inbound event (e.g. a partner-integration payload) is passed into the Bedrock prompt, attempting to override the function's intended behavior | The Landing Zone guardrail is applied to every call when enabled; the placeholder does not currently sanitize/validate event content before inclusion in the prompt — **residual risk**, flagged for the first real feature built on this path |
| Model scope creep | A future contributor widens the Lambda's IAM policy or swaps `MODEL_ID` to an unapproved model | `bedrock_approved_models_policy_arn` (Landing Zone-owned) is attached independently of this function's own policy, so a code change alone cannot grant access to a non-approved model |
| Guardrail bypass | A code change omits `guardrailIdentifier`/`guardrailVersion` from the `invoke_model` call | `GUARDRAILS_ENABLED` driving whether those parameters are attached is a single, reviewable code path (`src/ai_event_router.py`), not scattered logic |
| Audit gap | An invocation succeeds but the audit write to S3 fails silently | Current implementation calls `_audit()` unconditionally after a successful invoke, synchronously, inside the same Lambda invocation — a failure there raises and is visible in CloudWatch/the DLQ-equivalent failure path, not silently dropped |
| Sensitive data in the audit log | Request/response payloads written to the audit bucket may contain customer data | The audit bucket is the Landing Zone's existing, governed AI audit bucket (not a new, less-controlled location); access to it is restricted to this platform's own `event-platform/` prefix via the IAM policy in `modules/security` |
| Unbounded cost from a runaway invocation loop | A misconfigured EventBridge rule or retry loop causes repeated Bedrock invocations | The Lambda has no automatic self-retry; EventBridge Lambda targets retry per the rule's own retry policy (default AWS behavior) before falling back to a DLQ if configured — this build does not currently attach a DLQ to the AI router's own invocation failures, which is a gap recorded in `docs/future-enhancements.md` |

## Verdict
Acceptable for a portfolio/demonstration deployment with `enable_ai_integration` defaulted to `false` in dev and `true` only in test/prod for evaluation. Not yet hardened enough for a production feature that makes customer-facing decisions — see the recommendation in `docs/ai-governance-assessment.md`.
