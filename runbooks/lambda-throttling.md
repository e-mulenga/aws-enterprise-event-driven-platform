# Runbook: Lambda errors/throttles alarm firing

**Trigger:** `<prefix>-<function>-errors` or `<prefix>-<function>-throttles` CloudWatch alarm.

## 1. Identify the pattern
```bash
aws logs tail /aws/lambda/<function-name> --since 15m --follow
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda --metric-name ConcurrentExecutions \
  --dimensions Name=FunctionName,Value=<function-name> \
  --start-time $(date -u -d '15 minutes ago' +%FT%TZ) --end-time $(date -u +%FT%TZ) \
  --period 60 --statistics Maximum
```

## 2. Throttles (no reserved concurrency / account limit hit)
If `ConcurrentExecutions` is pinned near the account's unreserved-concurrency ceiling, either:
- Set reserved concurrency on this function to guarantee it headroom, or
- Request an account-level concurrent-execution limit increase (Service Quotas).

For `orders_worker`/`inventory_worker`, throttling backs up the source SQS queue rather than dropping events — check the queue-depth dashboard widget; it's a capacity problem, not a correctness one, as long as `visibility_timeout_seconds` (60s) comfortably exceeds the function timeout.

## 3. Errors
Read the log tail for the exception. Common causes in this platform:
- A malformed event body (see [dlq-handling.md](dlq-handling.md) once it's landed in the DLQ)
- A downstream DynamoDB throttle (on-demand billing should prevent this, but a very large burst can still hit the table's internal partition limits)
- An IAM permission gap after a module change — check the function's attached inline policy in `modules/lambda/main.tf` or `modules/security/main.tf`.

## 4. Escalate
If error rate stays elevated after the above, treat it as a DR-triggering event only if it is Region-wide (see [dr-failover.md](dr-failover.md)) — a single function's bug is not a Regional failure.
