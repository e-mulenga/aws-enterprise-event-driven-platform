# ============================================================
# modules/ai-integration
# ============================================================
# Consumes, never creates, the Landing Zone's AI governance controls. This
# module is the single place the platform touches Bedrock; it attaches
# the Landing Zone's approved-models policy to the shared execution role
# and gives the AI router Lambda the guardrail ID/version as configuration
# — the guardrail itself, and the audit bucket it writes to, are the
# Landing Zone's, read-only from here.
#
# Only deployed when enable_ai_integration = true (root main.tf wraps this
# module in count), reflecting that AI event routing is a documented
# future-readiness capability, not a Day-1 requirement — see
# docs/ai-governance-assessment.md.
# ============================================================

data "archive_file" "ai_event_router" {
  type        = "zip"
  source_file = "${path.module}/src/ai_event_router.py"
  output_path = "${path.module}/.build/ai_event_router.zip"
}

resource "aws_cloudwatch_log_group" "ai_event_router" {
  name              = "/aws/lambda/${var.name_prefix}-ai-event-router"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_lambda_function" "ai_event_router" {
  function_name = "${var.name_prefix}-ai-event-router"
  role          = var.execution_role_arn
  handler       = "ai_event_router.handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 256

  filename         = data.archive_file.ai_event_router.output_path
  source_code_hash = data.archive_file.ai_event_router.output_base64sha256

  kms_key_arn = var.kms_key_arn

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      BEDROCK_GUARDRAIL_ID       = var.bedrock_guardrail_id
      BEDROCK_GUARDRAIL_VERSION  = "1"
      BEDROCK_GUARDRAILS_ENABLED = tostring(var.bedrock_guardrails_enabled)
      AI_AUDIT_BUCKET_NAME       = var.ai_audit_bucket_name
    }
  }

  depends_on = [aws_cloudwatch_log_group.ai_event_router]

  tags = merge(var.tags, { Name = "${var.name_prefix}-ai-event-router" })
}

resource "aws_cloudwatch_event_rule" "ai_routing_requested" {
  name        = "${var.name_prefix}-ai-routing-requested"
  description = "Integration Events: AIRoutingRequested -> ai-event-router Lambda."

  event_pattern = jsonencode({
    source      = ["shopsphere.ai"]
    detail-type = ["AIRoutingRequested"]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "ai_routing_requested" {
  rule = aws_cloudwatch_event_rule.ai_routing_requested.name
  arn  = aws_lambda_function.ai_event_router.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ai_event_router.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ai_routing_requested.arn
}

# Attach the Landing Zone's existing approved-models policy to the shared
# execution role — restricts which Bedrock model IDs this role may invoke.
resource "aws_iam_role_policy_attachment" "approved_models" {
  count = var.bedrock_approved_models_policy_arn != null ? 1 : 0

  role       = split("/", var.execution_role_arn)[length(split("/", var.execution_role_arn)) - 1]
  policy_arn = var.bedrock_approved_models_policy_arn
}

resource "aws_iam_role_policy" "bedrock_invoke" {
  name = "${var.name_prefix}-ai-router-bedrock-invoke"
  role = split("/", var.execution_role_arn)[length(split("/", var.execution_role_arn)) - 1]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "InvokeBedrockModel"
      Effect   = "Allow"
      Action   = ["bedrock:InvokeModel"]
      Resource = "*" # narrowed in practice by the attached approved-models policy
    }]
  })
}
