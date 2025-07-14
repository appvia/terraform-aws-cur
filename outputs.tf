# CUR Report Outputs
output "cur_report_name" {
  description = "The name of the CUR report"
  value       = aws_cur_report_definition.cur_report.report_name
}

output "cur_report_arn" {
  description = "The ARN of the CUR report"
  value       = "arn:aws:cur:us-east-1:${local.account_id}:definition/${aws_cur_report_definition.cur_report.report_name}"
}

# S3 Bucket Outputs
output "s3_bucket_id" {
  description = "The ID of the S3 bucket"
  value       = aws_s3_bucket.cur_bucket.id
}

output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.cur_bucket.arn
}

output "s3_bucket_domain_name" {
  description = "The bucket domain name"
  value       = aws_s3_bucket.cur_bucket.bucket_domain_name
}

output "s3_bucket_regional_domain_name" {
  description = "The bucket region-specific domain name"
  value       = aws_s3_bucket.cur_bucket.bucket_regional_domain_name
}

output "s3_bucket_hosted_zone_id" {
  description = "The Route 53 Hosted Zone ID for this bucket's region"
  value       = aws_s3_bucket.cur_bucket.hosted_zone_id
}

output "s3_bucket_region" {
  description = "The AWS region this bucket resides in"
  value       = aws_s3_bucket.cur_bucket.region
}

# KMS Outputs
output "kms_key_id" {
  description = "The globally unique identifier for the KMS key"
  value       = var.enable_kms_encryption && var.kms_key_id == "" ? aws_kms_key.cur_s3_key[0].key_id : var.kms_key_id
}

output "kms_key_arn" {
  description = "The Amazon Resource Name (ARN) of the KMS key"
  value       = var.enable_kms_encryption && var.kms_key_id == "" ? aws_kms_key.cur_s3_key[0].arn : ""
}

output "kms_alias_arn" {
  description = "The Amazon Resource Name (ARN) of the key alias"
  value       = var.enable_kms_encryption && var.kms_key_id == "" ? aws_kms_alias.cur_s3_key_alias[0].arn : ""
}

output "kms_alias_name" {
  description = "The display name of the alias"
  value       = var.enable_kms_encryption && var.kms_key_id == "" ? aws_kms_alias.cur_s3_key_alias[0].name : ""
}

# Replication Outputs
output "replication_role_arn" {
  description = "The ARN of the IAM role used for S3 replication"
  value       = var.enable_replication ? aws_iam_role.replication_role[0].arn : ""
}

output "replication_role_id" {
  description = "The ID of the IAM role used for S3 replication"
  value       = var.enable_replication ? aws_iam_role.replication_role[0].id : ""
}

output "replication_configuration_id" {
  description = "The ID of the S3 bucket replication configuration"
  value       = var.enable_replication ? aws_s3_bucket_replication_configuration.cur_replication[0].id : ""
}

# SNS Outputs
output "sns_topic_arn" {
  description = "The ARN of the SNS topic for bucket notifications"
  value       = var.enable_bucket_notification && var.notification_topic_arn == "" ? aws_sns_topic.cur_notifications[0].arn : var.notification_topic_arn
}

output "sns_topic_name" {
  description = "The name of the SNS topic for bucket notifications"
  value       = var.enable_bucket_notification && var.notification_topic_arn == "" ? aws_sns_topic.cur_notifications[0].name : ""
}

# Configuration Summary Outputs
output "cur_configuration" {
  description = "Summary of CUR configuration"
  value = {
    report_name                = aws_cur_report_definition.cur_report.report_name
    time_unit                  = aws_cur_report_definition.cur_report.time_unit
    format                     = aws_cur_report_definition.cur_report.format
    compression                = aws_cur_report_definition.cur_report.compression
    additional_schema_elements = aws_cur_report_definition.cur_report.additional_schema_elements
    additional_artifacts       = aws_cur_report_definition.cur_report.additional_artifacts
    refresh_closed_reports     = aws_cur_report_definition.cur_report.refresh_closed_reports
    report_versioning          = aws_cur_report_definition.cur_report.report_versioning
    s3_bucket                  = aws_cur_report_definition.cur_report.s3_bucket
    s3_prefix                  = aws_cur_report_definition.cur_report.s3_prefix
    s3_region                  = aws_cur_report_definition.cur_report.s3_region
  }
}

output "s3_configuration" {
  description = "Summary of S3 bucket configuration"
  value = {
    bucket_name           = aws_s3_bucket.cur_bucket.id
    bucket_arn            = aws_s3_bucket.cur_bucket.arn
    versioning_enabled    = var.enable_versioning
    encryption_enabled    = var.enable_kms_encryption
    replication_enabled   = var.enable_replication
    notifications_enabled = var.enable_bucket_notification
    public_access_blocked = var.enable_public_access_block
  }
}

output "replication_configuration" {
  description = "Summary of replication configuration"
  value = var.enable_replication ? {
    destination_bucket     = var.replication_destination_bucket
    destination_account_id = var.replication_destination_account_id
    destination_region     = var.replication_destination_region
    storage_class          = var.replication_storage_class
    prefix                 = var.replication_prefix
    kms_key_id             = var.replication_replica_kms_key_id
  } : {}
}
