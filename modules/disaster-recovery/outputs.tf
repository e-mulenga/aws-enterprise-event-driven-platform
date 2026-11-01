output "event_archive_bucket_name" {
  value = aws_s3_bucket.event_archive.id
}

output "event_archive_bucket_arn" {
  value = aws_s3_bucket.event_archive.arn
}

output "event_archive_dr_bucket_name" {
  value = try(aws_s3_bucket.event_archive_dr[0].id, null)
}

output "replication_enabled" {
  value = var.enable_cross_region_replication
}

output "health_check_id" {
  value = try(aws_route53_health_check.api[0].id, null)
}
