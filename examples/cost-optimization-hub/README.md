# Cost Optimization Hub Integration Example

This example demonstrates how to use the AWS CUR Terraform module with Cost Optimization Hub (COH) data exports enabled. This creates a comprehensive FinOps data lake that includes both cost/usage data and cost optimization recommendations in the same S3 bucket.

## What This Example Creates

- **CUR Report**: Daily cost and usage data with detailed resource information
- **Cost Optimization Hub Export**: Cost optimization recommendations in Parquet format
- **Unified S3 Storage**: Both datasets stored in the same encrypted S3 bucket with different prefixes
- **SNS Notifications**: Alerts when new data files are available
- **Security**: KMS encryption, versioning, and public access blocking

## Prerequisites

Before running this example:

1. **Enable Cost Optimization Hub** in your AWS account:

   ```bash
   aws cost-optimization-hub update-preferences \
     --savings-estimation-mode BEFORE_DISCOUNTS \
     --member-account-discount-visibility INCLUDE
   ```

2. **Enable AWS Compute Optimizer** (required for rightsizing recommendations):

   ```bash
   aws compute-optimizer update-enrollment-status \
     --status Active \
     --include-member-accounts
   ```

3. **Ensure you have appropriate permissions** for:
   - Creating CUR reports
   - Managing Data Exports
   - S3 bucket operations
   - KMS key management

## S3 Bucket Structure

After deployment, your S3 bucket will contain:

```
my-company-finops-data-123456789012/
├── cur-reports/                          # CUR data
│   ├── 20240115-20240216/
│   │   ├── manifest.json
│   │   └── my-company-cost-report-00001.snappy.parquet
│   └── ...
└── coh/123456789012/                     # COH recommendations (account-specific)
    ├── year=2024/month=01/day=15/
    │   └── recommendations-00001.parquet
    └── ...
```

## Key Configuration Options

### Cost Optimization Hub Settings

- **`coh_include_all_recommendations`**: Set to `false` to export only the highest savings recommendations per resource (recommended to avoid double-counting)
- **`coh_s3_prefix`**: Directory prefix for COH exports (default: "coh", with account ID appended automatically)
- **`coh_export_name`**: Name for the Data Export (used in AWS console)
- **`coh_filter`**: Filter configuration for COH recommendations (default: "{}" for no filtering)

### CUR Settings

- **`additional_schema_elements`**: Includes `RESOURCES` and `SPLIT_COST_ALLOCATION_DATA` for detailed analysis
- **`additional_artifacts`**: Enables integration with Athena, QuickSight, and Redshift

## Usage

1. **Initialize Terraform**:

   ```bash
   terraform init
   ```

2. **Plan the deployment**:

   ```bash
   terraform plan
   ```

3. **Apply the configuration**:

   ```bash
   terraform apply
   ```

4. **Verify exports in AWS Console**:
   - Navigate to Billing & Cost Management > Data Exports
   - Check that both CUR and COH exports are listed and active

## Expected Timeline

- **CUR Data**: Available 8-24 hours after first AWS usage
- **COH Data**: Available 24-48 hours after enabling COH and Compute Optimizer
- **Subsequent Updates**: Daily for both datasets

## Cost Considerations

- **S3 Storage**: ~$0.023/GB/month for standard storage
- **Data Transfer**: Minimal within same region
- **KMS**: ~$1/month per key + $0.03 per 10,000 requests
- **COH Service**: Free (only S3 storage costs apply)

## Integration with Analytics Tools

This setup is ready for integration with:

- **Amazon Athena**: Query both CUR and COH data using SQL
- **Amazon QuickSight**: Create dashboards combining cost and optimization data
- **AWS Glue**: ETL processing for custom analytics
- **Third-party BI tools**: Power BI, Tableau, etc.

## Example Queries

Once data is available, you can query both datasets:

```sql
-- Top 10 cost optimization opportunities
SELECT 
    resource_id,
    estimated_monthly_savings_after_discount,
    action_type,
    implementation_effort
FROM cost_optimization_recommendations
WHERE estimated_monthly_savings_after_discount > 100
ORDER BY estimated_monthly_savings_after_discount DESC
LIMIT 10;

-- Correlate costs with optimization opportunities
SELECT 
    cur.line_item_resource_id,
    cur.line_item_unblended_cost,
    coh.estimated_monthly_savings_after_discount,
    coh.action_type
FROM cost_and_usage_report cur
JOIN cost_optimization_recommendations coh 
    ON cur.line_item_resource_id = coh.resource_id
WHERE cur.line_item_usage_start_date >= '2024-01-01';
```

## Cleanup

To remove all resources:

```bash
terraform destroy
```

**Note**: S3 bucket will only be deleted if empty. You may need to manually empty the bucket first if it contains data.

<!-- BEGIN_TF_DOCS -->
## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |

## Inputs

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_data_exports_summary"></a> [data\_exports\_summary](#output\_data\_exports\_summary) | Summary of enabled data exports |
| <a name="output_s3_bucket_structure"></a> [s3\_bucket\_structure](#output\_s3\_bucket\_structure) | S3 bucket structure showing where data will be stored |
<!-- END_TF_DOCS -->