#!/usr/bin/env bash
# Creates (or verifies) the GitHub Actions deploy role for this repository,
# trusting the Landing Zone's EXISTING OIDC provider
# (github_oidc_provider_arn). This script never creates a second OIDC
# provider — the EC2/IAM API would reject a duplicate for the same URL
# anyway.
set -euo pipefail

: "${GITHUB_ORG:?set GITHUB_ORG}"
: "${GITHUB_REPO:?set GITHUB_REPO, e.g. aws-enterprise-event-driven-platform}"
: "${ENV:?set ENV, e.g. dev}"
: "${AWS_ACCOUNT_ID:?set AWS_ACCOUNT_ID}"
: "${LANDING_ZONE_OIDC_PROVIDER_ARN:?set LANDING_ZONE_OIDC_PROVIDER_ARN (from landing zone outputs)}"

ROLE_NAME="shopsphere-${ENV}-event-platform-deploy"

TRUST_POLICY=$(cat <<JSON
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "${LANDING_ZONE_OIDC_PROVIDER_ARN}" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
      "StringLike":   { "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${GITHUB_REPO}:*" }
    }
  }]
}
JSON
)

if aws iam get-role --role-name "${ROLE_NAME}" >/dev/null 2>&1; then
  echo "Role ${ROLE_NAME} already exists — updating trust policy."
  aws iam update-assume-role-policy --role-name "${ROLE_NAME}" --policy-document "${TRUST_POLICY}"
else
  echo "Creating role ${ROLE_NAME}."
  aws iam create-role --role-name "${ROLE_NAME}" --assume-role-policy-document "${TRUST_POLICY}"
fi

echo "Role ARN: arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
echo "Attach least-privilege deploy permissions separately — see docs/deployment-guide.md."
