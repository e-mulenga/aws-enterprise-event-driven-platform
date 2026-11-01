# ---- Regions ---------------------------------------------------------------
output "primary_region" {
  value = local.o.af_south_1.region
}

output "dr_region" {
  value = local.o.eu_west_1.region
}

# ---- Primary (af-south-1) networking ---------------------------------------
output "primary_vpc_id" {
  value = local.o.af_south_1.vpc_id
}

output "primary_vpc_cidr" {
  value = local.o.af_south_1.vpc_cidr_block
}

output "primary_azs" {
  value = local.o.af_south_1.azs
}

output "primary_public_subnet_ids" {
  value = local.o.af_south_1.public_subnet_ids
}

output "primary_private_subnet_ids" {
  value = local.o.af_south_1.private_subnet_ids
}

output "primary_database_subnet_ids" {
  value = local.o.af_south_1.database_subnet_ids
}

# ---- DR (eu-west-1) networking ----------------------------------------------
output "dr_vpc_id" {
  value = local.o.eu_west_1.vpc_id
}

output "dr_vpc_cidr" {
  value = local.o.eu_west_1.vpc_cidr_block
}

output "dr_azs" {
  value = local.o.eu_west_1.azs
}

output "dr_public_subnet_ids" {
  value = local.o.eu_west_1.public_subnet_ids
}

output "dr_private_subnet_ids" {
  value = local.o.eu_west_1.private_subnet_ids
}

output "dr_database_subnet_ids" {
  value = local.o.eu_west_1.database_subnet_ids
}

# ---- Governance / organisation ----------------------------------------------
output "organization_id" {
  value = local.o.organization_id
}

output "organization_arn" {
  value = local.o.organization_arn
}

output "ou_ids" {
  value = try(local.o.ou_ids, {})
}

# ---- DNS ---------------------------------------------------------------------
output "route53_zone_id" {
  value = local.o.route53_zone_id
}

output "domain_name" {
  value = local.o.route53_domain_name
}

output "acm_certificate_arn" {
  value = try(local.o.acm_certificate_arn, null)
}

output "acm_cloudfront_certificate_arn" {
  value = try(local.o.acm_cloudfront_certificate_arn, null)
}

# ---- Platform ------------------------------------------------------------
output "github_oidc_provider_arn" {
  value = local.o.github_oidc_provider_arn
}

output "ecr_repository_urls" {
  value = try(local.o.ecr_repository_urls, {})
}

# ---- Shared logging (existing buckets — never recreated) -------------------
output "cloudtrail_bucket_name" {
  value = local.o.cloudtrail_bucket_name
}

output "cloudtrail_bucket_arn" {
  value = local.o.cloudtrail_bucket_arn
}

output "config_bucket_name" {
  value = local.o.config_bucket_name
}

output "config_bucket_arn" {
  value = local.o.config_bucket_arn
}

output "guardduty_bucket_name" {
  value = local.o.guardduty_bucket_name
}

output "guardduty_bucket_arn" {
  value = local.o.guardduty_bucket_arn
}

output "access_logs_bucket_name" {
  value = local.o.access_logs_bucket_name
}

output "access_logs_bucket_arn" {
  value = local.o.access_logs_bucket_arn
}

output "log_buckets" {
  value = try(local.o.log_buckets, {})
}

# ---- Encryption strategy -----------------------------------------------------
output "key_strategy" {
  value = local.o.key_strategy
}

output "shared_kms_keys" {
  value = local.o.shared_kms_keys
}

# ---- AI governance (consumed, never recreated) -------------------------------
output "bedrock_guardrail_id" {
  value = try(local.o.bedrock_guardrail_id, null)
}

output "bedrock_guardrail_version" {
  value = try(local.o.bedrock_guardrail_version, null)
}

output "bedrock_guardrails_enabled" {
  value = try(local.o.bedrock_guardrails_enabled, false)
}

output "bedrock_approved_models_policy_arn" {
  value = try(local.o.bedrock_approved_models_policy_arn, null)
}

output "ai_audit_bucket_name" {
  value = try(local.o.ai_audit_bucket_name, null)
}

# ---- Existing monitoring / security posture ----------------------------------
output "landing_zone_dashboard_name" {
  value = try(local.o.landing_zone_dashboard_name, null)
}

output "monitoring_topic_arn" {
  value = try(local.o.monitoring_topic_arn, null)
}

output "security_hub_enabled" {
  value = try(local.o.security_hub_enabled, false)
}

output "default_security_group_id" {
  value = try(local.o.default_security_group_id, null)
}

# ---- VPC Flow Logs (owned by the Landing Zone) -------------------------------
output "vpc_flow_logs" {
  description = "Per-Region VPC Flow Logs info, if the Landing Zone's vpc_flow_logs module/output exists. Empty object on an older Landing Zone state."
  value       = try(local.o.vpc_flow_logs, {})
}
