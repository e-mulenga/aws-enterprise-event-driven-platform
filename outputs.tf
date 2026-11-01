# ============================================================
# Root outputs
# ============================================================

# ---- Landing Zone context (pass-through, for visibility / downstream repos)
output "landing_zone_organization_id" {
  value = module.landing_zone.organization_id
}

output "primary_vpc_id" {
  description = "Landing Zone VPC this platform deploys into (not created here)."
  value       = module.landing_zone.primary_vpc_id
}

# ---- Event backbone ----------------------------------------------------------
output "event_bus_name" {
  value = module.eventbridge.event_bus_name
}

output "event_bus_arn" {
  value = module.eventbridge.event_bus_arn
}

output "event_archive_name" {
  value = module.eventbridge.archive_name
}

# ---- Messaging -----------------------------------------------------------------
output "queue_urls" {
  value = module.sqs.queue_urls
}

output "dlq_urls" {
  value = module.sqs.dlq_urls
}

output "topic_arns" {
  value = module.sns.topic_arns
}

# ---- Data layer ------------------------------------------------------------------
output "dynamodb_table_names" {
  value = module.dynamodb.table_names
}

# ---- Compute / API ----------------------------------------------------------------
output "lambda_function_names" {
  value = module.lambda.function_names
}

output "api_endpoint" {
  value = module.api_gateway.api_endpoint
}

output "api_custom_domain_name" {
  value = var.enable_custom_domain ? module.api_gateway.custom_domain_name : null
}

# ---- Resilience ---------------------------------------------------------------------
output "event_archive_bucket_name" {
  value = module.disaster_recovery.event_archive_bucket_name
}

# ---- Observability ----------------------------------------------------------------
output "monitoring_dashboard_name" {
  value = module.monitoring.dashboard_name
}

# ---- Security ------------------------------------------------------------------------
output "kms_strategy_in_effect" {
  value = var.kms_strategy
}

output "lambda_execution_role_arn" {
  value = module.security.lambda_execution_role_arn
}
