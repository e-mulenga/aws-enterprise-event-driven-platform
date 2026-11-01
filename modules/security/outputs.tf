output "kms_key_arns" {
  description = "service => CMK ARN, only populated when kms_strategy = customer-managed. Empty map in dev/test (consumers pass null to resources, which then default to the AWS-managed key)."
  value       = { for k, v in aws_kms_key.service : k => v.arn }
}

output "eventbridge_kms_key_arn" {
  value = try(aws_kms_key.service["eventbridge"].arn, null)
}

output "sqs_kms_key_arn" {
  value = try(aws_kms_key.service["sqs"].arn, null)
}

output "sns_kms_key_arn" {
  value = try(aws_kms_key.service["sqs"].arn, null) # SNS topics reuse the sqs-equivalent CMK tier; see docs/cost-analysis.md
}

output "dynamodb_kms_key_arn" {
  value = try(aws_kms_key.service["dynamodb"].arn, null)
}

output "lambda_kms_key_arn" {
  value = try(aws_kms_key.service["lambda"].arn, null)
}

output "s3_kms_key_arn" {
  value = try(aws_kms_key.service["s3"].arn, null)
}

output "s3_kms_key_arn_dr" {
  value = try(aws_kms_key.s3_dr[0].arn, null)
}

output "lambda_execution_role_arn" {
  value = aws_iam_role.lambda_execution.arn
}

output "lambda_execution_role_name" {
  value = aws_iam_role.lambda_execution.name
}

output "lambda_security_group_id" {
  value = aws_security_group.lambda.id
}

output "partner_api_credentials_secret_arn" {
  value = aws_secretsmanager_secret.partner_api_credentials.arn
}
