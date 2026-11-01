# ============================================================
# Root module — wires the Landing Zone data module into every
# workload module. No resource in this file (or any module other
# than modules/landingzone-data) reads terraform_remote_state
# directly, and none creates a VPC, subnet, Organization resource,
# central log bucket, OIDC provider, Route 53 zone or Bedrock
# guardrail — all of those are owned by the Landing Zone.
# See docs/landing-zone-dependency-matrix.md.
# ============================================================

module "landing_zone" {
  source = "./modules/landingzone-data"

  state_bucket = var.landing_zone_state_bucket
  state_key    = var.landing_zone_state_key
  state_region = var.landing_zone_state_region
}

# ---- Security: KMS (prod only), IAM execution roles, Secrets Manager ------
module "security" {
  source = "./modules/security"

  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

  name_prefix  = local.name_prefix
  environment  = var.environment
  kms_strategy = var.kms_strategy
  vpc_id       = local.lz.primary_vpc_id

  lambda_dlq_arns = values(module.sqs.dlq_arns)

  landing_zone_key_strategy = local.lz.key_strategy
  primary_region            = var.primary_region
  dr_region                 = var.dr_region
  enable_dr_replica_keys    = var.environment == "prod"

  ai_audit_bucket_name = local.lz.ai_audit_bucket_name

  tags = local.default_tags
}

# ---- DynamoDB: Customer Profiles, Orders, Event Metadata -------------------
module "dynamodb" {
  source = "./modules/dynamodb"

  name_prefix          = local.name_prefix
  environment          = var.environment
  enable_global_tables = var.enable_global_tables
  dr_region            = var.dr_region
  kms_key_arn          = module.security.dynamodb_kms_key_arn

  tags = local.default_tags
}

# ---- SQS: per-domain queues + DLQs -----------------------------------------
module "sqs" {
  source = "./modules/sqs"

  name_prefix               = local.name_prefix
  environment               = var.environment
  kms_key_arn               = module.security.sqs_kms_key_arn
  enable_dlq                = var.enable_dlq
  dlq_max_receive_count     = var.dlq_max_receive_count
  message_retention_seconds = var.message_retention_seconds

  tags = local.default_tags
}

# ---- SNS: fan-out topics -----------------------------------------------------
module "sns" {
  source = "./modules/sns"

  name_prefix = local.name_prefix
  environment = var.environment
  kms_key_arn = module.security.sns_kms_key_arn
  alert_email = var.alert_email

  tags = local.default_tags
}

# ---- EventBridge: custom bus, rules, archive/replay -------------------------
module "eventbridge" {
  source = "./modules/eventbridge"

  name_prefix          = local.name_prefix
  environment          = var.environment
  event_retention_days = var.event_retention_days
  enable_event_replay  = var.enable_event_replay
  kms_key_arn          = module.security.eventbridge_kms_key_arn

  orders_queue_arn        = module.sqs.queue_arns["orders"]
  orders_queue_url        = module.sqs.queue_urls["orders"]
  inventory_queue_arn     = module.sqs.queue_arns["inventory"]
  inventory_queue_url     = module.sqs.queue_urls["inventory"]
  notifications_topic_arn = module.sns.topic_arns["order-events"]
  dlq_arn                 = module.sqs.dlq_arns["eventbridge-rule-targets"]

  tags = local.default_tags
}

# ---- Lambda: API handler, order/inventory workers, event router, DLQ processor
module "lambda" {
  source = "./modules/lambda"

  name_prefix = local.name_prefix
  environment = var.environment

  primary_vpc_private_subnet_ids = local.lz.primary_private_subnet_ids
  security_group_ids             = [module.security.lambda_security_group_id]

  kms_key_arn         = module.security.lambda_kms_key_arn
  execution_role_arn  = module.security.lambda_execution_role_arn
  execution_role_name = module.security.lambda_execution_role_name

  orders_queue_arn             = module.sqs.queue_arns["orders"]
  orders_queue_url             = module.sqs.queue_urls["orders"]
  inventory_queue_arn          = module.sqs.queue_arns["inventory"]
  inventory_queue_url          = module.sqs.queue_urls["inventory"]
  orders_table_name            = module.dynamodb.table_names["orders"]
  orders_table_arn             = module.dynamodb.table_arns["orders"]
  customer_profiles_table_name = module.dynamodb.table_names["customer_profiles"]
  event_metadata_table_name    = module.dynamodb.table_names["event_metadata"]
  event_bus_name               = module.eventbridge.event_bus_name
  event_bus_arn                = module.eventbridge.event_bus_arn
  dlq_arn                      = module.sqs.dlq_arns["orders"]

  enable_xray_tracing = var.enable_xray_tracing
  log_retention_days  = var.lambda_log_retention_days

  tags = local.default_tags
}

# ---- API Gateway: HTTP API fronting the order-intake Lambda ----------------
module "api_gateway" {
  source = "./modules/api-gateway"

  name_prefix = local.name_prefix
  environment = var.environment

  lambda_invoke_arn    = module.lambda.function_invoke_arns["api_handler"]
  lambda_function_name = module.lambda.function_names["api_handler"]

  enable_custom_domain = var.enable_custom_domain
  route53_zone_id      = local.lz.route53_zone_id
  domain_name          = local.lz.domain_name
  acm_certificate_arn  = local.lz.acm_certificate_arn # Landing Zone's existing wildcard cert — never recreated here

  throttle_burst_limit = var.api_throttle_burst_limit
  throttle_rate_limit  = var.api_throttle_rate_limit
  log_retention_days   = var.lambda_log_retention_days

  tags = local.default_tags
}

# ---- Disaster Recovery: event-archive bucket (+CRR), Route 53 failover ----
module "disaster_recovery" {
  source = "./modules/disaster-recovery"

  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

  name_prefix = local.name_prefix
  environment = var.environment

  enable_cross_region_replication = var.enable_cross_region_replication
  kms_key_arn                     = module.security.s3_kms_key_arn
  kms_key_arn_dr                  = module.security.s3_kms_key_arn_dr

  route53_zone_id      = local.lz.route53_zone_id
  domain_name          = local.lz.domain_name
  enable_custom_domain = var.enable_custom_domain
  api_domain_name      = var.enable_custom_domain ? module.api_gateway.custom_domain_name : null

  tags = local.default_tags
}

# ---- AI integration: consumes Landing Zone Bedrock guardrails --------------
module "ai_integration" {
  source = "./modules/ai-integration"
  count  = var.enable_ai_integration ? 1 : 0

  name_prefix = local.name_prefix
  environment = var.environment

  bedrock_guardrail_id               = local.lz.bedrock_guardrail_id
  bedrock_guardrails_enabled         = local.lz.bedrock_guardrails_enabled
  bedrock_approved_models_policy_arn = local.lz.bedrock_approved_models_policy_arn
  ai_audit_bucket_name               = local.lz.ai_audit_bucket_name

  event_bus_arn      = module.eventbridge.event_bus_arn
  execution_role_arn = module.security.lambda_execution_role_arn
  kms_key_arn        = module.security.lambda_kms_key_arn
  log_retention_days = var.lambda_log_retention_days

  tags = local.default_tags
}

# ---- Monitoring: dashboard, alarms, optional Managed Grafana --------------
module "monitoring" {
  source = "./modules/monitoring"

  name_prefix = local.name_prefix
  environment = var.environment

  queue_names           = module.sqs.queue_names
  dlq_names             = module.sqs.dlq_names
  lambda_function_names = module.lambda.function_names
  event_bus_name        = module.eventbridge.event_bus_name
  api_name              = module.api_gateway.api_id
  alerts_topic_arn      = module.sns.topic_arns["platform-alerts"]

  enable_managed_grafana = var.enable_managed_grafana

  tags = local.default_tags
}
