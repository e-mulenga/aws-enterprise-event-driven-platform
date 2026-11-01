# ADR 0004: EventBridge targets SQS for domain events, SNS for business events, never Lambda directly for durable flows

## Status
Accepted

## Context
Justified strategy across SQS, SNS and EventBridge (`docs/messaging-strategy.md`). Three event categories exist in this platform: Domain Events (order/inventory lifecycle), Business Events (customer-facing status changes meant for multiple subscribers), and Integration Events (partner/external).

## Decision
- Domain events route EventBridge → SQS → a dedicated worker Lambda, so processing failures queue and retry rather than being lost, and a DLQ captures poison messages.
- Business events route EventBridge → SNS, because they are inherently fan-out (multiple current/future subscribers) and SQS's point-to-point model doesn't fit that shape without adding an SNS-to-multiple-SQS fan-out pattern on top.
- No domain or business event targets a Lambda function directly from EventBridge. The one exception, `ai-routing-requested` → `ai_event_router` Lambda, is an explicitly synchronous-feeling AI routing path, not a durable business event, and is clearly separated in `modules/ai-integration` rather than mixed into the domain/business rule set.

## Consequences
- Every durable event has a DLQ-backed safety net; a transient Lambda failure never silently drops an order or inventory event.
- Adding a new subscriber to a business event (e.g., a new partner webhook) is an SNS subscription, not an EventBridge rule change.
- The AI routing path's lack of a DLQ is a known, documented gap (`docs/ai-threat-model.md`) rather than an inconsistency — it was a deliberate scope decision for this placeholder feature, to be revisited before any production use.
