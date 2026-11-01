# Runbook: replaying events from the EventBridge archive

Use this when a bug in a worker Lambda caused it to process events incorrectly (not when a message is sitting in a DLQ — see [dlq-handling.md](dlq-handling.md) for that path) and you need to reprocess a time window of history.

## 1. Fix the bug first
Replaying into a worker that still has the bug just reproduces the incorrect processing. Deploy the fix before replaying.

## 2. Start a replay
```bash
aws events start-replay \
  --replay-name "replay-$(date +%Y%m%d-%H%M)" \
  --event-source-arn <event-bus-arn> \
  --event-start-time 2026-10-01T00:00:00Z \
  --event-end-time   2026-10-01T06:00:00Z \
  --destination '{"Arn": "<event-bus-arn>"}'
```
Replayed events go back through the bus's normal rules and targets — they are indistinguishable from live events to a target, so make sure the consuming worker is idempotent (this platform's workers key writes by `order_id`/`event_id`, so a replay is safe to re-run).

## 3. Monitor
```bash
aws events describe-replay --replay-name <name>
```
Watch the EventPlatform dashboard's "EventBridge: Failed Invocations" widget during the replay window.

## 4. Archive retention
The archive retains `event_retention_days` (14 in dev/test, 30 in prod) of history — a replay request outside that window will return no events.
