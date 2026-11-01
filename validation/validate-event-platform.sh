#!/usr/bin/env bash
# Post-deploy smoke checks. Skips checks for features that are off in this
# environment (enable_ai_integration=false, enable_managed_grafana=false,
# enable_custom_domain=false), mirroring the Landing Zone's own
# validation convention.
set -uo pipefail

ENV="${1:?usage: validate-event-platform.sh <env>}"
FAILED=0

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "OK   - ${desc}"
  else
    echo "FAIL - ${desc}"
    FAILED=1
  fi
}

PREFIX="shopsphere-${ENV}"

check "EventBridge bus exists" aws events describe-event-bus --name "${PREFIX}-events"
check "Orders DynamoDB table ACTIVE" bash -c "aws dynamodb describe-table --table-name ${PREFIX}-orders --query 'Table.TableStatus' --output text | grep -q ACTIVE"
check "Customer profiles DynamoDB table ACTIVE" bash -c "aws dynamodb describe-table --table-name ${PREFIX}-customer-profiles --query 'Table.TableStatus' --output text | grep -q ACTIVE"
check "Event metadata DynamoDB table ACTIVE" bash -c "aws dynamodb describe-table --table-name ${PREFIX}-event-metadata --query 'Table.TableStatus' --output text | grep -q ACTIVE"
check "Orders SQS queue exists" aws sqs get-queue-url --queue-name "${PREFIX}-orders"
check "Orders DLQ exists" aws sqs get-queue-url --queue-name "${PREFIX}-orders-dlq"
check "api-handler Lambda exists" aws lambda get-function --function-name "${PREFIX}-api-handler"
check "orders-worker Lambda exists" aws lambda get-function --function-name "${PREFIX}-orders-worker"
check "CloudWatch dashboard exists" aws cloudwatch get-dashboard --dashboard-name "${PREFIX}-event-platform"

if [ "${FAILED}" -eq 0 ]; then
  echo "All checks passed."
else
  echo "One or more checks failed." >&2
fi
exit "${FAILED}"
