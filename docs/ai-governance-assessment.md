# AI Governance Assessment

## Scope
This platform's only AI surface is `modules/ai-integration` — an optional (`enable_ai_integration`), illustrative event router that calls Amazon Bedrock. It is a future-readiness demonstration, not a production AI feature; no AI model currently makes a decision that affects a real order, customer or payment.

## Governance controls consumed (never created) from the Landing Zone
| Control | Landing Zone output | How it's applied here |
|---|---|---|
| Guardrail | `bedrock_guardrail_id`, `bedrock_guardrail_version` | Passed to every `bedrock:InvokeModel` call via `guardrailIdentifier`/`guardrailVersion`, only when `bedrock_guardrails_enabled = true` |
| Approved models | `bedrock_approved_models_policy_arn` | Attached as a managed policy to the Lambda execution role, restricting which model IDs can be invoked regardless of what the function code requests |
| Audit trail | `ai_audit_bucket_name` | Every invocation's request/response is written to `event-platform/ai-router/` in the existing, Landing-Zone-owned audit bucket |

This platform never creates a second guardrail, a second audit bucket, or a looser IAM policy that bypasses the approved-models restriction — doing so would defeat the Landing Zone's governance model rather than extend it.

## Fairness, Transparency, Safety, Accountability, Human Oversight
| Principle | How it's addressed |
|---|---|
| Fairness | Out of scope for the current placeholder feature (it routes/summarizes events; it does not score, rank or make decisions about customers) — flagged as a required review item before any future feature that does |
| Transparency | Every invocation is logged with its full request/response to the audit bucket; the guardrail ID/version in effect is recorded as Lambda environment variables, visible in Terraform state and the function configuration |
| Safety | The Landing Zone's guardrail is always applied when guardrails are enabled; the function fails closed if `BEDROCK_GUARDRAILS_ENABLED` is false by simply not attaching a guardrail parameter — it does not silently retry without one |
| Accountability | `modules/ai-integration` is the sole place this platform touches Bedrock — there is one module, one Lambda, one IAM policy to audit, not AI calls scattered across the codebase |
| Human oversight | No AI output is auto-applied to an order, payment, or customer record in this build — the router's output is a routed/summarized artifact, written to the audit bucket for a human to review |

## Recommendation before any production AI feature is added
1. A Responsible AI Review (see `docs/responsible-ai-review.md`) specific to that feature's actual decision — this document covers the placeholder's infrastructure governance, not a feature that doesn't exist yet.
2. Narrow `aws_iam_role_policy.bedrock_invoke`'s `Resource = "*"` to the specific model ARNs the approved-models policy allows, rather than relying on the attached policy alone (see `docs/security-review.md`, Known limitation).
