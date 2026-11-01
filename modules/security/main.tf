# ============================================================
# modules/security
# ============================================================
# Creates ONLY what this repository owns: optional prod CMKs for its own
# services, the shared Lambda execution role and security group, and a
# placeholder Secrets Manager secret. It never creates a VPC, an
# Organization resource, a central log bucket, an OIDC provider, a Route 53
# zone, or a Bedrock guardrail — those are the Landing Zone's.
#
# Encryption strategy (mandatory cost-optimization statement):
# Development and Test environments use AWS-managed encryption keys to
# reduce AWS KMS operational costs and administrative overhead while
# maintaining encryption at rest. Production environments use Customer
# Managed Keys (CMKs) to support enterprise governance, auditability,
# compliance, and security requirements.
# ============================================================

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.dr]
    }
  }
}

locals {
  create_cmks = var.kms_strategy == "customer-managed"

  # One CMK per service this repository owns the encryption posture for.
  # Matches the example names in the source requirements (eventbridge-prod-key,
  # sqs-prod-key, dynamodb-prod-key) plus lambda and s3, which the platform
  # also encrypts.
  cmk_services = toset(local.create_cmks ? ["eventbridge", "sqs", "dynamodb", "lambda", "s3"] : [])
}

# ---- Customer Managed Keys (prod only) --------------------------------------
resource "aws_kms_key" "service" {
  for_each = local.cmk_services

  description             = "${var.name_prefix} ${each.key} CMK — customer-managed per the Production encryption strategy."
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name    = "${each.key}-${var.environment}-key"
    Service = each.key
  })
}

resource "aws_kms_alias" "service" {
  for_each = local.cmk_services

  name          = "alias/${each.key}-${var.environment}-key"
  target_key_id = aws_kms_key.service[each.key].key_id
}

# DR-region replica key for the event-archive S3 bucket. KMS keys are
# regional (no cross-Region replication), so the DR copy of the bucket gets
# its own, independently managed CMK with an equivalent policy.
resource "aws_kms_key" "s3_dr" {
  count    = var.enable_dr_replica_keys && local.create_cmks ? 1 : 0
  provider = aws.dr

  description             = "${var.name_prefix} s3 CMK (DR Region replica key) — customer-managed per the Production encryption strategy."
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name    = "s3-${var.environment}-key-dr"
    Service = "s3"
    Region  = var.dr_region
  })
}

resource "aws_kms_alias" "s3_dr" {
  count    = var.enable_dr_replica_keys && local.create_cmks ? 1 : 0
  provider = aws.dr

  name          = "alias/s3-${var.environment}-key-dr"
  target_key_id = aws_kms_key.s3_dr[0].key_id
}

# ---- Lambda execution role (least privilege; per-resource policies are
# attached by the modules that own those resources — eventbridge, sqs,
# dynamodb, lambda, ai-integration — once those resources exist, avoiding a
# circular dependency on a role created here before they exist) -------------
resource "aws_iam_role" "lambda_execution" {
  name = "${var.name_prefix}-lambda-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowLambdaAssume"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "xray" {
  name = "${var.name_prefix}-lambda-xray"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowXRayWrite"
      Effect = "Allow"
      Action = [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords",
        "xray:GetSamplingRules",
        "xray:GetSamplingTargets",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_dlq" {
  count = length(var.lambda_dlq_arns) > 0 ? 1 : 0

  name = "${var.name_prefix}-lambda-dlq"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowLambdaDlqWrites"
      Effect = "Allow"

      Action = [
        "sqs:SendMessage"
      ]

      Resource = var.lambda_dlq_arns
    }]
  })
}

# Scoped, read-only-by-default access to the Landing Zone's AI audit bucket,
# limited to this platform's own prefix. The bucket itself is never created
# or modified here.
resource "aws_iam_role_policy" "ai_audit_write" {
  count = var.ai_audit_bucket_name != null ? 1 : 0

  name = "${var.name_prefix}-ai-audit-write"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "WriteEventPlatformAiAuditPrefix"
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "arn:aws:s3:::${var.ai_audit_bucket_name}/event-platform/*"
    }]
  })
}

# ---- Lambda security group (in the Landing Zone's VPC — never a new VPC) --
resource "aws_security_group" "lambda" {
  name_prefix = "${var.name_prefix}-lambda-"
  description = "Egress only security group for platform Lambda functions"
  vpc_id      = var.vpc_id

  egress {
    description = "All outbound (VPC endpoints / NAT-routed AWS API calls)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-lambda-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

# ---- Secrets Manager: placeholder for partner integration credentials -----
resource "aws_secretsmanager_secret" "partner_api_credentials" {
  name                    = "${var.name_prefix}-partner-api-credentials"
  description             = "Placeholder for partner-integration API credentials consumed by the event-router Lambda. Populate out of band — never store real secrets in Terraform state via this resource's value."
  recovery_window_in_days = var.environment == "prod" ? 30 : 7 # Dev/test environments 7-day recovery window if the secret is accidentally deleted.

  tags = var.tags
}
