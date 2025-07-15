![Github Actions](../../actions/workflows/terraform.yml/badge.svg)

# AWS Cost and Usage Report (CUR) Terraform Module

This Terraform module provisions an AWS Cost and Usage Report (CUR) with comprehensive S3 bucket configuration, including optional cross-account replication, KMS encryption, lifecycle management, and notification capabilities.

## Features

- **Complete CUR Setup**: Creates and configures AWS Cost and Usage Reports
- **Cost Optimization Hub Integration**: Export Cost Optimization Hub recommendations to the same S3 bucket
- **Secure S3 Storage**: S3 bucket with KMS encryption, versioning, and public access blocking
- **Cross-Account Replication**: Optional S3 bucket replication to another AWS account
- **Notifications**: Optional SNS notifications for new CUR files and COH recommendations
- **Access Control**: Configurable cross-account access policies
- **Security Best Practices**: Enforced encryption, secure policies, and access controls

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0.0
- AWS Provider >= 5.0.0
- **Important**: CUR reports can only be created in the `us-east-1` region, regardless of where your resources are deployed

## Required AWS Permissions

The executing role/user needs the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cur:DescribeReportDefinitions",
        "cur:PutReportDefinition",
        "cur:DeleteReportDefinition",
        "cur:ModifyReportDefinition",
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:GetBucketLocation",
        "s3:GetBucketPolicy",
        "s3:PutBucketPolicy",
        "s3:PutBucketAcl",
        "s3:GetBucketAcl",
        "kms:CreateKey",
        "kms:CreateAlias",
        "kms:DescribeKey",
        "kms:GetKeyPolicy",
        "kms:PutKeyPolicy",
        "iam:CreateRole",
        "iam:AttachRolePolicy",
        "iam:PutRolePolicy",
        "sns:CreateTopic",
        "sns:SetTopicAttributes"
      ],
      "Resource": "*"
    }
  ]
}
```

## Usage

### Basic Usage

```hcl
module "cur_report" {
  source = "github.com/appvia/terraform-aws-cur"

  # Required variables
  s3_bucket_name = "my-organization-cur-reports"
  report_name    = "my-organization-cur"

  # Optional: Configure report settings
  time_unit    = "DAILY"
  format       = "Parquet"
  compression  = "Parquet"

  tags = {
    Environment = "production"
    Project     = "finops"
    Owner       = "finance-team"
  }
}
```

### Advanced Usage with Cross-Account Replication and Cost Optimization Hub

```hcl
module "cur_report" {
  source = "github.com/appvia/terraform-aws-cur"

  # Basic configuration
  s3_bucket_name = "my-organization-cur-reports"
  report_name    = "my-organization-cur"

  # Enable Cost Optimization Hub exports
  enable_cost_optimization_hub     = true
  coh_export_name                  = "org-cost-optimization-export"
  coh_s3_prefix                    = "coh"
  coh_include_all_recommendations  = false  # Only highest savings per resource

  # Enable cross-account replication
  enable_replication                   = true
  replication_destination_bucket       = "arn:aws:s3:::backup-account-cur-reports"
  replication_destination_account_id   = "123456789012"
  replication_destination_region       = "eu-west-1"
  replication_storage_class           = "STANDARD_IA"
  replication_replica_kms_key_id      = "arn:aws:kms:eu-west-1:123456789012:key/12345678-1234-1234-1234-123456789012"

  # Enable notifications (will notify for both CUR and COH files)
  enable_bucket_notification = true

  tags = {
    Environment = "production"
    Project     = "finops"
    Owner       = "finance-team"
  }
}
```

### Multi-Account Organization Setup

```hcl
# In the management account (payer account)
module "cur_report_source" {
  source = "github.com/appvia/terraform-aws-cur"

  s3_bucket_name = "org-management-cur-reports"
  report_name    = "organization-billing-report"

  # Include all schema elements for comprehensive reporting
  additional_schema_elements = ["RESOURCES", "SPLIT_COST_ALLOCATION_DATA"]
  additional_artifacts       = ["REDSHIFT", "QUICKSIGHT", "ATHENA"]

  # Enable replication to analytics account
  enable_replication                   = true
  replication_destination_bucket       = "arn:aws:s3:::analytics-account-cur-data"
  replication_destination_account_id   = var.analytics_account_id
  replication_destination_region       = "us-west-2"

  tags = var.common_tags
}
```

## Architecture

The module creates the following AWS resources:

```
┌─────────────────────┐
│   AWS Billing       │
│   Service           │
└─────────┬───────────┘
          │ Writes CUR data
          ▼
┌─────────────────────┐    ┌─────────────────────┐
│   S3 Bucket         │    │   KMS Key           │
│   (CUR Storage)     │◄──►│   (Encryption)      │
└─────────┬───────────┘    └─────────────────────┘
          │
          │ Replication (Optional)
          ▼
┌─────────────────────┐    ┌─────────────────────┐
│   Destination       │    │   SNS Topic         │
│   Bucket            │    │   (Notifications)   │
│   (Other Account)   │    └─────────────────────┘
└─────────────────────┘
```

## Important Notes

1. **Region Limitation**: AWS CUR reports can only be created in `us-east-1`. However, the S3 bucket can be in any region.

2. **Billing Permissions**: The account creating the CUR must be the management account (payer account) in an AWS Organization or the account responsible for billing.

3. **Cost Optimization Hub Prerequisites**:
   - Cost Optimization Hub must be enabled in your AWS account
   - AWS Compute Optimizer must be enabled to receive rightsizing recommendations
   - Data Exports service-linked role will be created automatically if needed

4. **Replication Requirements**:
   - Source bucket must have versioning enabled
   - Destination bucket must exist and have versioning enabled
   - Destination bucket must be in a different region
   - Both CUR and COH data will be replicated if replication is enabled

5. **Cost Considerations**:
   - S3 storage costs for CUR and COH data
   - Cross-region replication costs
   - KMS encryption costs
   - Cost Optimization Hub is free, but exports incur standard S3 storage costs

## Examples

### Basic CUR Setup

```hcl
module "basic_cur" {
  source = "github.com/appvia/terraform-aws-cur"

  s3_bucket_name = "company-billing-reports"
  report_name    = "daily-usage-report"

  tags = {
    Purpose = "billing"
    Team    = "finance"
  }
}
```

### Enterprise Setup with Replication

```hcl
module "enterprise_cur" {
  source = "github.com/appvia/terraform-aws-cur"

  s3_bucket_name = "enterprise-cur-primary"
  report_name    = "enterprise-cost-analysis"

  # Enhanced reporting
  additional_schema_elements = ["RESOURCES", "SPLIT_COST_ALLOCATION_DATA"]
  additional_artifacts       = ["REDSHIFT", "QUICKSIGHT", "ATHENA"]

  # Cross-account replication
  enable_replication                 = true
  replication_destination_bucket     = "arn:aws:s3:::enterprise-cur-backup"
  replication_destination_account_id = "111111111111"
  replication_destination_region     = "eu-central-1"

  # Notifications
  enable_bucket_notification = true

  tags = {
    Environment = "production"
    Project     = "cost-management"
    Compliance  = "required"
  }
}
```

## Best Practices

1. **Use Descriptive Names**: Choose meaningful names for reports and buckets
2. **Enable Notifications**: Set up SNS notifications to track when new reports are available
3. **Implement Lifecycle Policies**: Use appropriate lifecycle rules to manage costs
4. **Cross-Account Access**: Limit access to only necessary accounts
5. **Monitor Costs**: Regularly review S3 and replication costs
6. **Backup Strategy**: Consider replication for business-critical cost data
7. **Compliance**: Ensure data retention meets your organization's requirements

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure the executing role has billing permissions
2. **Region Errors**: Remember CUR can only be created in us-east-1
3. **Bucket Conflicts**: S3 bucket names must be globally unique
4. **Replication Failures**: Verify destination bucket exists and has versioning enabled

### Debugging

Enable Terraform debugging:

```bash
export TF_LOG=DEBUG
terraform apply
```

## Update Documentation

The `terraform-docs` utility is used to generate this README. Follow the below steps to update:

1. Make changes to the `.terraform-docs.yml` file
2. Fetch the `terraform-docs` binary (<https://terraform-docs.io/user-guide/installation/>)
3. Run `terraform-docs markdown table --output-file ${PWD}/README.md --output-mode inject .`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add/update tests
5. Submit a pull request

## License

This module is released under the MIT License. See [LICENSE](LICENSE) for details.

## Support

For issues and questions:

- Create an issue in the repository
- Contact the maintainers
- Check AWS CUR documentation

<!-- BEGIN_TF_DOCS -->
## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_s3_bucket_name"></a> [s3\_bucket\_name](#input\_s3\_bucket\_name) | The name of the S3 bucket where CUR reports will be stored | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to resources | `map(string)` | n/a | yes |
| <a name="input_additional_artifacts"></a> [additional\_artifacts](#input\_additional\_artifacts) | A list of additional artifacts to include in CUR report | `list(string)` | <pre>[<br/>  "REDSHIFT",<br/>  "QUICKSIGHT",<br/>  "ATHENA"<br/>]</pre> | no |
| <a name="input_additional_schema_elements"></a> [additional\_schema\_elements](#input\_additional\_schema\_elements) | A list of additional schema elements for CUR report | `list(string)` | <pre>[<br/>  "RESOURCES"<br/>]</pre> | no |
| <a name="input_coh_export_name"></a> [coh\_export\_name](#input\_coh\_export\_name) | Name for the Cost Optimization Hub data export | `string` | `"cost-optimization-hub-export"` | no |
| <a name="input_coh_filter"></a> [coh\_filter](#input\_coh\_filter) | Filter configuration for Cost Optimization Hub recommendations | `string` | `"{}"` | no |
| <a name="input_coh_include_all_recommendations"></a> [coh\_include\_all\_recommendations](#input\_coh\_include\_all\_recommendations) | Whether to include all COH recommendations (true) or only highest savings per resource (false) | `bool` | `false` | no |
| <a name="input_coh_refresh_frequency"></a> [coh\_refresh\_frequency](#input\_coh\_refresh\_frequency) | Frequency for Cost Optimization Hub data export refresh | `string` | `"SYNCHRONOUS"` | no |
| <a name="input_coh_s3_prefix"></a> [coh\_s3\_prefix](#input\_coh\_s3\_prefix) | S3 prefix for Cost Optimization Hub exports | `string` | `"coh"` | no |
| <a name="input_compression"></a> [compression](#input\_compression) | The compression type for CUR report | `string` | `"GZIP"` | no |
| <a name="input_enable_bucket_notification"></a> [enable\_bucket\_notification](#input\_enable\_bucket\_notification) | Whether to enable bucket notification for new CUR files | `bool` | `false` | no |
| <a name="input_enable_cost_optimization_hub"></a> [enable\_cost\_optimization\_hub](#input\_enable\_cost\_optimization\_hub) | Whether to enable Cost Optimization Hub data exports | `bool` | `false` | no |
| <a name="input_enable_kms_encryption"></a> [enable\_kms\_encryption](#input\_enable\_kms\_encryption) | Whether to enable KMS encryption for the S3 bucket | `bool` | `false` | no |
| <a name="input_enable_public_access_block"></a> [enable\_public\_access\_block](#input\_enable\_public\_access\_block) | Whether to enable public access block for the S3 bucket | `bool` | `true` | no |
| <a name="input_enable_replication"></a> [enable\_replication](#input\_enable\_replication) | Whether to enable cross-account S3 bucket replication | `bool` | `true` | no |
| <a name="input_enable_versioning"></a> [enable\_versioning](#input\_enable\_versioning) | Whether to enable versioning for the S3 bucket | `bool` | `true` | no |
| <a name="input_format"></a> [format](#input\_format) | The format for CUR report | `string` | `"Parquet"` | no |
| <a name="input_kms_key_deletion_window"></a> [kms\_key\_deletion\_window](#input\_kms\_key\_deletion\_window) | The waiting period, specified in number of days, after which the KMS key is deleted | `number` | `7` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | The KMS key ID for S3 bucket encryption. If not provided, a new key will be created | `string` | `""` | no |
| <a name="input_notification_topic_arn"></a> [notification\_topic\_arn](#input\_notification\_topic\_arn) | SNS topic ARN for bucket notifications | `string` | `""` | no |
| <a name="input_refresh_closed_reports"></a> [refresh\_closed\_reports](#input\_refresh\_closed\_reports) | Whether to refresh reports after they have been finalized | `bool` | `true` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region where resources will be created | `string` | `""` | no |
| <a name="input_replication_destination_account_id"></a> [replication\_destination\_account\_id](#input\_replication\_destination\_account\_id) | The AWS account ID of the destination bucket for replication | `string` | `""` | no |
| <a name="input_replication_destination_bucket"></a> [replication\_destination\_bucket](#input\_replication\_destination\_bucket) | The destination bucket ARN for replication | `string` | `""` | no |
| <a name="input_replication_destination_region"></a> [replication\_destination\_region](#input\_replication\_destination\_region) | The AWS region of the destination bucket for replication | `string` | `""` | no |
| <a name="input_replication_prefix"></a> [replication\_prefix](#input\_replication\_prefix) | Object prefix for replication rule | `string` | `""` | no |
| <a name="input_replication_replica_kms_key_id"></a> [replication\_replica\_kms\_key\_id](#input\_replication\_replica\_kms\_key\_id) | KMS key ID for encryption of replicated objects | `string` | `""` | no |
| <a name="input_replication_storage_class"></a> [replication\_storage\_class](#input\_replication\_storage\_class) | Storage class for replicated objects | `string` | `"STANDARD_IA"` | no |
| <a name="input_report_name"></a> [report\_name](#input\_report\_name) | The name of the CUR report | `string` | `"cost-and-usage-report"` | no |
| <a name="input_report_versioning"></a> [report\_versioning](#input\_report\_versioning) | Whether to overwrite the previous version of the report or to create new reports | `string` | `"OVERWRITE_REPORT"` | no |
| <a name="input_s3_bucket_prefix"></a> [s3\_bucket\_prefix](#input\_s3\_bucket\_prefix) | The prefix for CUR files in the S3 bucket | `string` | `"cur2"` | no |
| <a name="input_time_unit"></a> [time\_unit](#input\_time\_unit) | The time unit for CUR report generation | `string` | `"DAILY"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_coh_configuration"></a> [coh\_configuration](#output\_coh\_configuration) | Summary of Cost Optimization Hub configuration |
| <a name="output_coh_export_arn"></a> [coh\_export\_arn](#output\_coh\_export\_arn) | The ARN of the Cost Optimization Hub data export |
| <a name="output_coh_s3_prefix"></a> [coh\_s3\_prefix](#output\_coh\_s3\_prefix) | The S3 prefix for Cost Optimization Hub exports (including account ID) |
| <a name="output_cur_configuration"></a> [cur\_configuration](#output\_cur\_configuration) | Summary of CUR configuration |
| <a name="output_cur_report_arn"></a> [cur\_report\_arn](#output\_cur\_report\_arn) | The ARN of the CUR report |
| <a name="output_cur_report_name"></a> [cur\_report\_name](#output\_cur\_report\_name) | The name of the CUR report |
| <a name="output_kms_alias_arn"></a> [kms\_alias\_arn](#output\_kms\_alias\_arn) | The Amazon Resource Name (ARN) of the key alias |
| <a name="output_kms_alias_name"></a> [kms\_alias\_name](#output\_kms\_alias\_name) | The display name of the alias |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | The Amazon Resource Name (ARN) of the KMS key |
| <a name="output_kms_key_id"></a> [kms\_key\_id](#output\_kms\_key\_id) | The globally unique identifier for the KMS key |
| <a name="output_replication_configuration"></a> [replication\_configuration](#output\_replication\_configuration) | Summary of replication configuration |
| <a name="output_replication_configuration_id"></a> [replication\_configuration\_id](#output\_replication\_configuration\_id) | The ID of the S3 bucket replication configuration |
| <a name="output_replication_role_arn"></a> [replication\_role\_arn](#output\_replication\_role\_arn) | The ARN of the IAM role used for S3 replication |
| <a name="output_replication_role_id"></a> [replication\_role\_id](#output\_replication\_role\_id) | The ID of the IAM role used for S3 replication |
| <a name="output_s3_bucket_arn"></a> [s3\_bucket\_arn](#output\_s3\_bucket\_arn) | The ARN of the S3 bucket |
| <a name="output_s3_bucket_domain_name"></a> [s3\_bucket\_domain\_name](#output\_s3\_bucket\_domain\_name) | The bucket domain name |
| <a name="output_s3_bucket_hosted_zone_id"></a> [s3\_bucket\_hosted\_zone\_id](#output\_s3\_bucket\_hosted\_zone\_id) | The Route 53 Hosted Zone ID for this bucket's region |
| <a name="output_s3_bucket_id"></a> [s3\_bucket\_id](#output\_s3\_bucket\_id) | The ID of the S3 bucket |
| <a name="output_s3_bucket_region"></a> [s3\_bucket\_region](#output\_s3\_bucket\_region) | The AWS region this bucket resides in |
| <a name="output_s3_bucket_regional_domain_name"></a> [s3\_bucket\_regional\_domain\_name](#output\_s3\_bucket\_regional\_domain\_name) | The bucket region-specific domain name |
| <a name="output_s3_configuration"></a> [s3\_configuration](#output\_s3\_configuration) | Summary of S3 bucket configuration |
| <a name="output_sns_topic_arn"></a> [sns\_topic\_arn](#output\_sns\_topic\_arn) | The ARN of the SNS topic for bucket notifications |
| <a name="output_sns_topic_name"></a> [sns\_topic\_name](#output\_sns\_topic\_name) | The name of the SNS topic for bucket notifications |
<!-- END_TF_DOCS -->