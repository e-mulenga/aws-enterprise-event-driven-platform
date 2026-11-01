# Runbook: SQS queue depth growing unbounded

**Trigger:** the "SQS Queue Depth" dashboard widget trending up with no corresponding drop, or on-call judgment that a queue isn't draining.

## 1. Is the consumer running?
```bash
aws lambda get-event-source-mapping --uuid <mapping-uuid>   # State should be Enabled
aws lambda get-function --function-name <prefix>-orders-worker --query 'Configuration.State'
```

## 2. Is the consumer failing?
See [lambda-throttling.md](lambda-throttling.md) — a consumer that's erroring on every message will not drain its queue even though it's "running."

## 3. Is this a genuine traffic spike?
Compare against historical p99 on the "Lambda Duration" widget. If processing time per message hasn't degraded and the backlog is proportional to an incoming-traffic spike, this may resolve on its own as Lambda scales concurrency — Standard queues scale consumption automatically with event source mapping; FIFO (payments) is capped by message-group parallelism, so a single hot message group will serialize regardless of available Lambda concurrency.

## 4. Manual drain
If the consumer is healthy but under-provisioned, temporarily raise `reserved_concurrent_executions` on the worker function, or increase `batch_size` on the event source mapping (currently 10), then revert once the backlog clears.

## 5. If nothing drains it
Check the DLQ — messages that fail every attempt move there after `dlq_max_receive_count` (5) retries and stop counting against the visible queue depth; a DLQ that's filling in lockstep with the main queue's apparent stall is the real signal — go to [dlq-handling.md](dlq-handling.md).
