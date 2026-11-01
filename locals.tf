# ============================================================
# Shared locals
# ============================================================
locals {
  name_prefix = "shopsphere-${var.environment}"

  default_tags = merge(var.additional_tags, {
    Project           = "aws-enterprise-event-driven-platform"
    Company           = "ShopSphere Global"
    Environment       = var.environment
    ManagedBy         = "Terraform"
    LandingZoneSource = module.landing_zone.organization_id
  })

  # Resolved once, used throughout. Every other module receives these as
  # explicit variables — no module reaches into module.landing_zone itself.
  lz = {
    primary_vpc_id                     = module.landing_zone.primary_vpc_id
    primary_private_subnet_ids         = module.landing_zone.primary_private_subnet_ids
    primary_public_subnet_ids          = module.landing_zone.primary_public_subnet_ids
    primary_database_subnet_ids        = module.landing_zone.primary_database_subnet_ids
    dr_vpc_id                          = module.landing_zone.dr_vpc_id
    dr_private_subnet_ids              = module.landing_zone.dr_private_subnet_ids
    dr_public_subnet_ids               = module.landing_zone.dr_public_subnet_ids
    route53_zone_id                    = module.landing_zone.route53_zone_id
    domain_name                        = module.landing_zone.domain_name
    acm_certificate_arn                = module.landing_zone.acm_certificate_arn
    github_oidc_provider_arn           = module.landing_zone.github_oidc_provider_arn
    bedrock_approved_models_policy_arn = module.landing_zone.bedrock_approved_models_policy_arn
    organization_id                    = module.landing_zone.organization_id
    cloudtrail_bucket_name             = module.landing_zone.cloudtrail_bucket_name
    bedrock_guardrail_id               = module.landing_zone.bedrock_guardrail_id
    bedrock_guardrails_enabled         = module.landing_zone.bedrock_guardrails_enabled
    ai_audit_bucket_name               = module.landing_zone.ai_audit_bucket_name
    key_strategy                       = module.landing_zone.key_strategy
  }

  # Per-service KMS key ARN, resolved by environment encryption strategy
  # (see variables.tf: kms_strategy). null in dev/test (AWS managed keys);
  # a repository-scoped CMK ARN in prod (created by modules/security) unless
  # the Landing Zone already publishes one with a matching alias.
  use_cmk = var.kms_strategy == "customer-managed"
}
