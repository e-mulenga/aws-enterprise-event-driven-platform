"""
AI event router — placeholder for "Intelligent Event Routing" and
"Automated Incident Summaries" (the AI & Future Readiness requirements).

Triggered by EventBridge on shopsphere.ai / AIRoutingRequested. Invokes
Amazon Bedrock THROUGH the Landing Zone's existing guardrail
(BEDROCK_GUARDRAIL_ID / BEDROCK_GUARDRAIL_VERSION) — this function never
creates or modifies a guardrail, it only applies the one the Landing Zone
already governs. Every invocation is logged to the Landing Zone's existing
AI audit bucket under this platform's own prefix.

This is a placeholder: it demonstrates the wiring (guardrail application,
audit logging, least-privilege IAM) a real responsible-AI event-routing
feature would use, not a complete feature. See
docs/ai-governance-assessment.md and docs/responsible-ai-review.md.
"""
import json
import os
import time

import boto3

bedrock = boto3.client("bedrock-runtime")
s3 = boto3.client("s3")

GUARDRAIL_ID = os.environ.get("BEDROCK_GUARDRAIL_ID")
GUARDRAIL_VERSION = os.environ.get("BEDROCK_GUARDRAIL_VERSION", "1")
GUARDRAILS_ENABLED = os.environ.get("BEDROCK_GUARDRAILS_ENABLED") == "true"
AUDIT_BUCKET = os.environ["AI_AUDIT_BUCKET_NAME"]
MODEL_ID = os.environ.get("BEDROCK_MODEL_ID", "anthropic.claude-3-5-haiku-20241022-v1:0")


def handler(event, context):
    detail = event.get("detail", event)
    prompt = detail.get("prompt", "")

    invoke_kwargs = {
        "modelId": MODEL_ID,
        "body": json.dumps(
            {
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 512,
                "messages": [{"role": "user", "content": prompt}],
            }
        ),
        "contentType": "application/json",
    }

    if GUARDRAILS_ENABLED and GUARDRAIL_ID:
        invoke_kwargs["guardrailIdentifier"] = GUARDRAIL_ID
        invoke_kwargs["guardrailVersion"] = GUARDRAIL_VERSION

    response = bedrock.invoke_model(**invoke_kwargs)
    result = json.loads(response["body"].read())

    _audit(detail, result)

    return {"statusCode": 200, "body": json.dumps({"routed": True})}


def _audit(request_detail, response_body):
    key = f"event-platform/ai-router/{int(time.time())}.json"
    s3.put_object(
        Bucket=AUDIT_BUCKET,
        Key=key,
        Body=json.dumps({"request": request_detail, "response": response_body}).encode("utf-8"),
        ContentType="application/json",
    )
