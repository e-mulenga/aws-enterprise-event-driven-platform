# ============================================================
# modules/disaster-recovery
# ============================================================
# Owns the platform's event-archive S3 bucket (File Uploads, Event Payload
# Archives, Replay Data, Audit Data — the Object Storage requirement) with
# Lifecycle Policies, Versioning and optional Cross-Region Replication to
# the DR Region, plus a Route 53 health check against the API's custom
# domain. This is the repository's own operational bucket — distinct from
# the Landing Zone's central CloudTrail/Config/GuardDuty log buckets, which
# are never recreated here.
#
# Reliability target: 99.95% availability / 15 min RTO / 5 min RPO. CRR
# (near-real-time, typically seconds-to-minutes) plus DynamoDB Global
# Tables (modules/dynamodb, toggled by enable_global_tables) are what make
# that RPO achievable across a Regional failure; see docs/dr-strategy.md.
# ============================================================

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.dr]
    }
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  bucket_name    = "${var.name_prefix}-event-archive-${random_id.suffix.hex}"
  dr_bucket_name = "${var.name_prefix}-event-archive-dr-${random_id.suffix.hex}"
}

# ---- Primary bucket (af-south-1) --------------------------------------------
resource "aws_s3_bucket" "event_archive" {
  bucket = local.bucket_name

  tags = merge(var.tags, { Name = local.bucket_name, Purpose = "event-payload-archive" })
}

resource "aws_s3_bucket_versioning" "event_archive" {
  bucket = aws_s3_bucket.event_archive.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "event_archive" {
  bucket = aws_s3_bucket.event_archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "event_archive" {
  bucket = aws_s3_bucket.event_archive.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "event_archive" {
  bucket = aws_s3_bucket.event_archive.id

  rule {
    id     = "replay-data-tiering"
    status = "Enabled"

    filter {
      prefix = "replay-data/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }

  rule {
    id     = "event-archive-expiry"
    status = "Enabled"

    filter {
      prefix = "event-archive/"
    }

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  rule {
    id     = "audit-data-retention"
    status = "Enabled"

    filter {
      prefix = "audit-data/"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
}

# ---- DR replica bucket (eu-west-1) ------------------------------------------
resource "aws_s3_bucket" "event_archive_dr" {
  count    = var.enable_cross_region_replication ? 1 : 0
  provider = aws.dr

  bucket = local.dr_bucket_name

  tags = merge(var.tags, { Name = local.dr_bucket_name, Purpose = "event-payload-archive-dr-replica" })
}

resource "aws_s3_bucket_versioning" "event_archive_dr" {
  count    = var.enable_cross_region_replication ? 1 : 0
  provider = aws.dr

  bucket = aws_s3_bucket.event_archive_dr[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "event_archive_dr" {
  count    = var.enable_cross_region_replication ? 1 : 0
  provider = aws.dr

  bucket = aws_s3_bucket.event_archive_dr[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn_dr != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn_dr
    }
  }
}

resource "aws_s3_bucket_public_access_block" "event_archive_dr" {
  count    = var.enable_cross_region_replication ? 1 : 0
  provider = aws.dr

  bucket = aws_s3_bucket.event_archive_dr[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---- Replication role + configuration ---------------------------------------
resource "aws_iam_role" "replication" {
  count = var.enable_cross_region_replication ? 1 : 0

  name = "${var.name_prefix}-s3-replication"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowS3Assume"
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "replication" {
  count = var.enable_cross_region_replication ? 1 : 0

  name = "${var.name_prefix}-s3-replication"
  role = aws_iam_role.replication[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SourceBucketRead"
        Effect   = "Allow"
        Action   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
        Resource = [aws_s3_bucket.event_archive.arn]
      },
      {
        Sid      = "SourceObjectRead"
        Effect   = "Allow"
        Action   = ["s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging"]
        Resource = ["${aws_s3_bucket.event_archive.arn}/*"]
      },
      {
        Sid      = "DestinationWrite"
        Effect   = "Allow"
        Action   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags"]
        Resource = ["${aws_s3_bucket.event_archive_dr[0].arn}/*"]
      }
    ]
  })
}

resource "aws_s3_bucket_replication_configuration" "event_archive" {
  count = var.enable_cross_region_replication ? 1 : 0

  # Replication requires versioning on the source bucket to already exist.
  depends_on = [aws_s3_bucket_versioning.event_archive]

  bucket = aws_s3_bucket.event_archive.id
  role   = aws_iam_role.replication[0].arn

  rule {
    id     = "replicate-all"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.event_archive_dr[0].arn
      storage_class = "STANDARD"
    }
  }
}

# ---- Route 53 health check against the API's custom domain -----------------
resource "aws_route53_health_check" "api" {
  count = var.enable_custom_domain ? 1 : 0

  fqdn              = var.api_domain_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = merge(var.tags, { Name = "${var.name_prefix}-api-health-check" })
}
