# Runbook: a message has landed in a DLQ

**Trigger:** the `<prefix>-<queue>-dlq-not-empty` CloudWatch alarm fires (ApproximateNumberOfMessagesVisible > 0 on a DLQ), published to the `platform-alerts` SNS topic.

## 1. Triage
```bash
aws sqs get-queue-attributes \
  --queue-url <dlq-url> \
  --attribute-names ApproximateNumberOfMessages
aws sqs receive-message --queue-url <dlq-url> --max-number-of-messages 10 --visibility-timeout 0
```
Read the message body and any `ApproximateReceiveCount` attribute — it tells you how many times it was retried before landing here.

## 2. Classify
- **Transient failure** (a dependency was briefly down, a Lambda timed out under load): safe to redrive once the dependency has recovered.
- **Poison message** (malformed payload, a schema change the worker doesn't handle yet): do not blindly redrive — it will fail again and burn through `maxReceiveCount` on the next attempt too. Fix the worker or the producer first.

## 3. Redrive (once the cause is understood)
```bash
aws sqs start-message-move-task \
  --source-arn <dlq-arn> \
  --destination-arn <original-queue-arn>
```

## 4. If the message should never be reprocessed
Delete it explicitly after recording its content somewhere durable (the event-archive S3 bucket's `audit-data/` prefix, or a ticket) — do not just let it expire silently.

## 5. Prevent recurrence
If this was a poison-message pattern, check whether `docs/event-replay-strategy.md`'s event schema validation needs tightening at the EventBridge rule's `event_pattern`, or whether the worker Lambda needs stricter input validation before it can raise.
