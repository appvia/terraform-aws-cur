# Basic outputs for the simple CUR setup

output "cur_report_name" {
  description = "Name of the created CUR report"
  value       = module.simple_cur.cur_report_name
}

output "s3_bucket_id" {
  description = "ID of the S3 bucket storing CUR data"
  value       = module.simple_cur.s3_bucket_id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket storing CUR data"
  value       = module.simple_cur.s3_bucket_arn
}

output "kms_key_id" {
  description = "KMS key ID used for S3 encryption"
  value       = module.simple_cur.kms_key_id
  sensitive   = true
}

output "aws_account_id" {
  description = "AWS account ID where CUR is created"
  value       = data.aws_caller_identity.current.account_id
}

output "setup_summary" {
  description = "Summary of the CUR setup"
  value = {
    report_name   = module.simple_cur.cur_report_name
    bucket_name   = module.simple_cur.s3_bucket_id
    region        = data.aws_region.current.name
    encryption    = "KMS"
    replication   = "Disabled"
    notifications = "Disabled"
  }
}
