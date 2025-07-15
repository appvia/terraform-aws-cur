#
# Cost Optimization Hub Integration Example
# This example shows how to enable Cost Optimization Hub data exports alongside CUR
#

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Provider must be configured for us-east-1 as CUR can only be created there
provider "aws" {
  region = "us-east-1"
}

# Data sources
data "aws_caller_identity" "current" {}

# CUR module with Cost Optimization Hub enabled
module "cur_with_coh" {
  source = "../../" # Path to the module root

  # Required: S3 bucket name (must be globally unique)
  s3_bucket_name = "my-company-finops-data-${data.aws_caller_identity.current.account_id}"

  # CUR configuration
  report_name = "my-company-cost-report"
  time_unit   = "DAILY"
  format      = "Parquet"
  compression = "Parquet"

  # Include detailed schema elements for comprehensive analysis
  additional_schema_elements = ["RESOURCES", "SPLIT_COST_ALLOCATION_DATA"]
  additional_artifacts       = ["ATHENA", "QUICKSIGHT", "REDSHIFT"]

  # Enable Cost Optimization Hub exports
  enable_cost_optimization_hub    = true
  coh_export_name                 = "my-company-optimization-recommendations"
  coh_s3_prefix                   = "coh" # Account ID will be appended automatically
  coh_filter                      = "{}"  # No filtering (CloudFormation pattern)
  coh_include_all_recommendations = false # Only export highest savings per resource to avoid duplication

  # Security configuration
  enable_kms_encryption      = true
  enable_public_access_block = true
  enable_versioning          = true

  # Enable notifications for both CUR and COH files
  enable_bucket_notification = true

  # Tags
  tags = {
    Environment = "production"
    Purpose     = "finops-data-lake"
    Team        = "finance"
    ManagedBy   = "terraform"
  }
}

# Output the S3 bucket structure for reference
output "s3_bucket_structure" {
  description = "S3 bucket structure showing where data will be stored"
  value = {
    bucket_name = module.cur_with_coh.s3_bucket_id
    structure = {
      cur_reports = "${module.cur_with_coh.s3_bucket_id}/cur-reports/"
      coh_reports = "${module.cur_with_coh.s3_bucket_id}/${module.cur_with_coh.coh_s3_prefix}/"
    }
  }
}

# Output configuration summary
output "data_exports_summary" {
  description = "Summary of enabled data exports"
  value = {
    cur_enabled           = true
    cur_report            = module.cur_with_coh.cur_report_name
    coh_enabled           = module.cur_with_coh.coh_configuration.enabled
    coh_export            = module.cur_with_coh.coh_configuration.export_name
    s3_bucket             = module.cur_with_coh.s3_bucket_id
    kms_encrypted         = true
    notifications_enabled = true
  }
}
