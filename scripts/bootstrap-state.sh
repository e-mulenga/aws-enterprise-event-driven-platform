#!/usr/bin/env bash
# Confirms the shared Terraform state bucket (already created by the
# Landing Zone's own bootstrap-state.sh) is reachable, and that this
# platform's state key prefix doesn't collide with an existing object.
# This script never creates the bucket — it is owned by the Landing Zone.
set -euo pipefail

BUCKET="${1:-mulengae-terraform-state-bucket}"
ENV="${2:-dev}"
KEY="event-driven-platform/${ENV}/terraform.tfstate"

echo "Checking state bucket: s3://${BUCKET}"
aws s3api head-bucket --bucket "${BUCKET}" \
  || { echo "ERROR: ${BUCKET} is not reachable. It should already exist from the Landing Zone's own bootstrap." >&2; exit 1; }

if aws s3api head-object --bucket "${BUCKET}" --key "${KEY}" >/dev/null 2>&1; then
  echo "State object already exists at s3://${BUCKET}/${KEY} — this is an existing deployment."
else
  echo "No existing state at s3://${BUCKET}/${KEY} — this will be a fresh deployment."
fi

echo "OK — proceed with: terraform init -backend-config=environments/${ENV}/backend.hcl"
