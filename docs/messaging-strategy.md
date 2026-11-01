# Enterprise Messaging Strategy: SQS vs SNS vs EventBridge

## When to use each

| Use | Service | Why |
|---|---|---|
| One producer, one or a small fixed set of workers must process every message, in order if needed | **SQS** | Point-to-point, built-in DLQ/redrive, FIFO for strict ordering |
| One event, many independent subscribers who may change over time | **SNS** | Pub/sub fan-out; a new subscriber doesn't require a producer change |
| Routing decisions depend on event content, or the event may come from/go to a SaaS partner, or you need schema registry/replay | **EventBridge** | Content-based filtering via `event_pattern`, native partner event sources, built-in archive/replay |

## Applied in this platform

- **EventBridge is the front door** for every domain/business/integration event — `OrderCreated`, `InventoryReserved`, `OrderStatusChanged`, partner-integration events. It owns the archive (replay) and the content-based routing rules.
- **SQS sits behind EventBridge** wherever a worker Lambda must process every event exactly-once-ish with retry and a DLQ: the orders and inventory domain-event rules target SQS queues, not Lambda directly, so a Lambda cold-start spike or a transient AWS throttle doesn't lose events — they queue instead.
- **SNS sits behind EventBridge** wherever the same business event has, or will have, multiple independent subscribers: `business-events` (OrderStatusChanged) targets the `order-events` SNS topic, so notifications, analytics, and future partner webhook subscribers can all attach without the EventBridge rule changing.
- **Lambda is never a direct EventBridge target for domain/business events** in this build — it's always SQS or SNS in between, so a target-side failure (Lambda throttled, erroring) doesn't cause EventBridge to drop the event; it's durably queued or the delivery failure itself is captured via `dead_letter_config` on the rule target. The one exception is the optional `ai-routing-requested` rule, which targets the `ai_event_router` Lambda directly — that path is explicitly for synchronous-feeling AI routing, not durable event processing, and is only deployed when `enable_ai_integration = true`.

## FIFO vs Standard
Only the `payments` queue is FIFO. Payment events must apply in the exact order they were produced (an authorization before a capture, a capture before a refund) — a Standard queue's best-effort ordering and possible duplicate delivery are unacceptable there. Every other queue is Standard: orders, inventory and notifications tolerate reordering and don't need FIFO's lower throughput ceiling (300 msg/s without batching vs. nearly unlimited for Standard).
