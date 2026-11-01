# Responsible AI Review

## What this platform does with AI today
`modules/ai-integration` demonstrates the wiring for AI-assisted event routing and incident summarization — it does not yet implement either feature in a way that affects a real customer, order, or payment. It exists to show the governance pattern (consume the Landing Zone's guardrail and approved-models policy, never create new ones) that any future AI feature on this platform would build on.

## Review against Anthropic/AWS-style responsible AI principles

| Principle | Assessment |
|---|---|
| **Human oversight retained** | Yes — the router's output lands in an audit log for human review; nothing currently acts on it automatically. |
| **No undisclosed automated decision-making about people** | Yes — no customer-facing decision (pricing, fraud flag, account action) is made by this module. |
| **Guardrails cannot be silently disabled** | Partially — `bedrock_guardrails_enabled` is read from the Landing Zone's output, not hardcoded, so a Landing Zone change propagates here; but nothing in this module *alerts* if guardrails become disabled upstream. Recorded as a future-enhancement: a CloudWatch alarm on `BEDROCK_GUARDRAILS_ENABLED=false` in prod. |
| **Least-privilege model access** | Yes, via the Landing Zone's approved-models policy, with a noted residual gap (`docs/ai-threat-model.md`) in this module's own inline policy breadth. |
| **Auditable** | Yes — every invocation is logged with request and response to the Landing Zone's AI audit bucket. |
| **Fairness evaluation before customer-facing use** | **Not yet applicable** — no customer-facing decision exists to evaluate. This is the gating item before `docs/future-enhancements.md`'s "Intelligent Event Routing" or "AI-Assisted Business Workflows" move from future use case to implemented feature. |

## Conclusion
This module is reviewed and accepted as **governance-pattern infrastructure**, not as a production AI decision system. Any feature built on top of it that makes a customer-facing or business-consequential decision requires its own Responsible AI Review before deployment, specifically covering fairness and bias evaluation for that feature's actual output.
