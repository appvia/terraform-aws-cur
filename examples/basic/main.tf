#
# Simple CUR setup example
# This example shows the minimum configuration needed to set up a CUR report
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

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Basic CUR setup
module "simple_cur" {
  source = "../../" # Path to the module root

  # Required: S3 bucket name (must be globally unique)
  s3_bucket_name = "my-company-cur-reports-${data.aws_caller_identity.current.account_id}"

  # Optional: Report name
  report_name = "my-company-cost-report"

  # Basic configuration with secure defaults
  time_unit   = "DAILY"
  format      = "Parquet"
  compression = "Parquet"

  # Include resources for detailed analysis
  additional_schema_elements = ["RESOURCES"]
  additional_artifacts       = ["ATHENA", "QUICKSIGHT"]

  enable_bucket_notification = false
  enable_kms_encryption      = false
  enable_public_access_block = true
  enable_replication         = true
  enable_versioning          = true

  replication_destination_account_id = "123456789012"
  replication_destination_bucket     = "arn:aws:s3:::my-company-cur-reports-123456789012"
  replication_destination_region     = "eu-west-2"
  replication_prefix                 = "cur-reports"
  replication_storage_class          = "STANDARD"

  # Basic tags
  tags = {
    Environment = "production"
    Purpose     = "cost-reporting"
    ManagedBy   = "terraform"
  }
}
