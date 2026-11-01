#!/usr/bin/env bash
# Fails a plan that would delete or replace a resource this platform
# considers safety-critical: the EventBridge bus/archive, the DynamoDB
# tables, the event-archive S3 bucket, or any CMK. Run against a
# `terraform show -json tfplan` file.
set -euo pipefail

PLAN_JSON="${1:?usage: plan-guard.sh plan.json}"

PROTECTED_TYPES='aws_cloudwatch_event_bus|aws_cloudwatch_event_archive|aws_dynamodb_table|aws_s3_bucket|aws_kms_key'

DANGEROUS=$(jq -r --arg re "${PROTECTED_TYPES}" '
  .resource_changes[]
  | select(.type | test($re))
  | select(.change.actions | index("delete") or index("replace"))
  | .address
' "${PLAN_JSON}")

if [ -n "${DANGEROUS}" ]; then
  echo "BLOCKED: plan would delete/replace protected resources:" >&2
  echo "${DANGEROUS}" >&2
  exit 1
fi

echo "plan-guard: no protected-resource deletions/replacements found."
