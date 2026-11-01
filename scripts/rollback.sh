#!/usr/bin/env bash
# Re-applies the previous Terraform state version from S3 versioning (the
# state bucket, owned by the Landing Zone, has versioning enabled). Use
# only after confirming the current deployment is broken AND that the
# previous state still matches deployed infrastructure.
set -euo pipefail

BUCKET="${1:?usage: rollback.sh <bucket> <key> <version-id>}"
KEY="${2:?usage: rollback.sh <bucket> <key> <version-id>}"
VERSION_ID="${3:?usage: rollback.sh <bucket> <key> <version-id>}"

echo "Fetching s3://${BUCKET}/${KEY} version ${VERSION_ID}..."
aws s3api get-object --bucket "${BUCKET}" --key "${KEY}" --version-id "${VERSION_ID}" /tmp/rollback.tfstate

echo "Review /tmp/rollback.tfstate, then:"
echo "  aws s3 cp /tmp/rollback.tfstate s3://${BUCKET}/${KEY}"
echo "This does NOT undo already-applied infrastructure changes — pair with a plan/apply to reconcile."
