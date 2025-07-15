variable "additional_artifacts" {
  description = "A list of additional artifacts to include in CUR report"
  type        = list(string)
  default     = ["REDSHIFT", "QUICKSIGHT", "ATHENA"]
}

variable "additional_schema_elements" {
  description = "A list of additional schema elements for CUR report"
  type        = list(string)
  default     = ["RESOURCES"]
}

variable "coh_export_name" {
  description = "Name for the Cost Optimization Hub data export"
  type        = string
  default     = "cost-optimization-hub-export"
}

variable "coh_include_all_recommendations" {
  description = "Whether to include all COH recommendations (true) or only highest savings per resource (false)"
  type        = bool
  default     = false
}

variable "coh_refresh_frequency" {
  description = "Frequency for Cost Optimization Hub data export refresh"
  type        = string
  default     = "SYNCHRONOUS"
  validation {
    condition     = contains(["SYNCHRONOUS"], var.coh_refresh_frequency)
    error_message = "COH refresh frequency must be SYNCHRONOUS."
  }
}

variable "coh_s3_prefix" {
  description = "S3 prefix for Cost Optimization Hub exports"
  type        = string
  default     = "coh"
}

variable "coh_filter" {
  description = "Filter configuration for Cost Optimization Hub recommendations"
  type        = string
  default     = "{}"
}

variable "compression" {
  description = "The compression type for CUR report"
  type        = string
  default     = "GZIP"
  validation {
    condition     = contains(["ZIP", "GZIP", "Parquet"], var.compression)
    error_message = "Compression must be ZIP, GZIP, or Parquet."
  }
}

variable "enable_bucket_notification" {
  description = "Whether to enable bucket notification for new CUR files"
  type        = bool
  default     = false
}

variable "enable_cost_optimization_hub" {
  description = "Whether to enable Cost Optimization Hub data exports"
  type        = bool
  default     = false
}

variable "enable_kms_encryption" {
  description = "Whether to enable KMS encryption for the S3 bucket"
  type        = bool
  default     = false
}

variable "enable_public_access_block" {
  description = "Whether to enable public access block for the S3 bucket"
  type        = bool
  default     = true
}

variable "enable_replication" {
  description = "Whether to enable cross-account S3 bucket replication"
  type        = bool
  default     = true
}

variable "enable_versioning" {
  description = "Whether to enable versioning for the S3 bucket"
  type        = bool
  default     = true
}

variable "format" {
  description = "The format for CUR report"
  type        = string
  default     = "Parquet"
  validation {
    condition     = contains(["textORcsv", "Parquet"], var.format)
    error_message = "Format must be either textORcsv or Parquet."
  }
}

variable "kms_key_deletion_window" {
  description = "The waiting period, specified in number of days, after which the KMS key is deleted"
  type        = number
  default     = 7
}

variable "kms_key_id" {
  description = "The KMS key ID for S3 bucket encryption. If not provided, a new key will be created"
  type        = string
  default     = ""
}

variable "notification_topic_arn" {
  description = "SNS topic ARN for bucket notifications"
  type        = string
  default     = ""
}

variable "refresh_closed_reports" {
  description = "Whether to refresh reports after they have been finalized"
  type        = bool
  default     = true
}

variable "region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = ""
}

variable "replication_destination_account_id" {
  description = "The AWS account ID of the destination bucket for replication"
  type        = string
  default     = ""
}

variable "replication_destination_bucket" {
  description = "The destination bucket ARN for replication"
  type        = string
  default     = ""
}

variable "replication_destination_region" {
  description = "The AWS region of the destination bucket for replication"
  type        = string
  default     = ""
}

variable "replication_prefix" {
  description = "Object prefix for replication rule"
  type        = string
  default     = ""
}

variable "replication_replica_kms_key_id" {
  description = "KMS key ID for encryption of replicated objects"
  type        = string
  default     = ""
}

variable "replication_storage_class" {
  description = "Storage class for replicated objects"
  type        = string
  default     = "STANDARD_IA"
  validation {
    condition = contains([
      "STANDARD", "REDUCED_REDUNDANCY", "STANDARD_IA",
      "ONEZONE_IA", "INTELLIGENT_TIERING", "GLACIER",
      "DEEP_ARCHIVE", "OUTPOSTS"
    ], var.replication_storage_class)
    error_message = "Invalid storage class specified."
  }
}

variable "report_name" {
  description = "The name of the CUR report"
  type        = string
  default     = "cost-and-usage-report"
}

variable "report_versioning" {
  description = "Whether to overwrite the previous version of the report or to create new reports"
  type        = string
  default     = "OVERWRITE_REPORT"
  validation {
    condition     = contains(["CREATE_NEW_REPORT", "OVERWRITE_REPORT"], var.report_versioning)
    error_message = "Report versioning must be either CREATE_NEW_REPORT or OVERWRITE_REPORT."
  }
}

variable "s3_bucket_name" {
  description = "The name of the S3 bucket where CUR reports will be stored"
  type        = string
}

variable "s3_bucket_prefix" {
  description = "The prefix for CUR files in the S3 bucket"
  type        = string
  default     = "cur2"
}

variable "tags" {
  description = "A map of tags to assign to resources"
  type        = map(string)
}

variable "time_unit" {
  description = "The time unit for CUR report generation"
  type        = string
  default     = "DAILY"
  validation {
    condition     = contains(["HOURLY", "DAILY"], var.time_unit)
    error_message = "Time unit must be either HOURLY or DAILY."
  }
}
