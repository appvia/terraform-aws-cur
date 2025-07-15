# AWS Cost and Usage Report (CUR) CloudFormation Template

This CloudFormation template is a direct conversion of the Terraform AWS CUR module, providing the same comprehensive functionality for setting up AWS Cost and Usage Reports with S3 storage, KMS encryption, cross-account replication, and Cost Optimization Hub integration.

## Features

- **Complete CUR Setup**: Creates and configures AWS Cost and Usage Reports
- **Cost Optimization Hub Integration**: Export Cost Optimization Hub recommendations to the same S3 bucket
- **Secure S3 Storage**: S3 bucket with KMS encryption, versioning, and public access blocking
- **Cross-Account Replication**: Optional S3 bucket replication to another AWS account

- **Access Control**: Configurable cross-account access policies
- **Security Best Practices**: Enforced encryption, secure policies, and access controls

## Prerequisites

- AWS CLI configured with appropriate permissions
- **Important**: CUR reports can only be created in the `us-east-1` region, regardless of where your resources are deployed
- If enabling Cost Optimization Hub, ensure it's enabled in your AWS account
- If enabling replication, the destination bucket must exist and have versioning enabled

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
        "bcm-data-exports:CreateExport",
        "bcm-data-exports:UpdateExport",
        "bcm-data-exports:DeleteExport"
      ],
      "Resource": "*"
    }
  ]
}
```

## Usage

### Basic Usage

Deploy with minimal required parameters:

```bash
aws cloudformation create-stack \
  --stack-name my-cur-stack \
  --template-body file://cur-template.yaml \
  --parameters ParameterKey=S3BucketName,ParameterValue=my-organization-cur-reports \
               ParameterKey=ReportName,ParameterValue=my-organization-cur \
  --capabilities CAPABILITY_IAM \
  --region us-east-1
```

### Advanced Usage with All Features

Deploy with Cost Optimization Hub, KMS encryption, and replication:

```bash
aws cloudformation create-stack \
  --stack-name enterprise-cur-stack \
  --template-body file://cur-template.yaml \
  --parameters \
    ParameterKey=S3BucketName,ParameterValue=enterprise-cur-reports \
    ParameterKey=ReportName,ParameterValue=enterprise-cost-analysis \
    ParameterKey=EnableKMSEncryption,ParameterValue=true \
    ParameterKey=EnableCostOptimizationHub,ParameterValue=true \
    ParameterKey=EnableReplication,ParameterValue=true \
    ParameterKey=ReplicationDestinationBucket,ParameterValue=arn:aws:s3:::backup-account-cur-reports \
    ParameterKey=ReplicationDestinationAccountId,ParameterValue=123456789012 \
    ParameterKey=ReplicationDestinationRegion,ParameterValue=eu-west-1 \
    
    ParameterKey=Environment,ParameterValue=production \
    ParameterKey=Project,ParameterValue=finops \
    ParameterKey=Owner,ParameterValue=finance-team \
  --capabilities CAPABILITY_IAM \
  --region us-east-1
```

### Using Parameter Files

Create a parameters file `parameters.json`:

```json
[
  {
    "ParameterKey": "S3BucketName",
    "ParameterValue": "my-organization-cur-reports"
  },
  {
    "ParameterKey": "ReportName",
    "ParameterValue": "my-organization-cur"
  },
  {
    "ParameterKey": "EnableKMSEncryption",
    "ParameterValue": "true"
  },
  {
    "ParameterKey": "EnableCostOptimizationHub",
    "ParameterValue": "true"
  },
  {
    "ParameterKey": "Environment",
    "ParameterValue": "production"
  },
  {
    "ParameterKey": "Project",
    "ParameterValue": "cost-management"
  }
]
```

Deploy using the parameters file:

```bash
aws cloudformation create-stack \
  --stack-name my-cur-stack \
  --template-body file://cur-template.yaml \
  --parameters file://parameters.json \
  --capabilities CAPABILITY_IAM \
  --region us-east-1
```

## Parameters

### Required Parameters

| Parameter | Description | Default | Type |
|-----------|-------------|---------|------|
| `S3BucketName` | The name of the S3 bucket where CUR reports will be stored | - | String |

### Core Configuration Parameters

| Parameter | Description | Default | Allowed Values |
|-----------|-------------|---------|----------------|
| `ReportName` | The name of the CUR report | `cost-and-usage-report` | String |
| `TimeUnit` | The time unit for CUR report generation | `DAILY` | `HOURLY`, `DAILY` |
| `Format` | The format for CUR report | `Parquet` | `textORcsv`, `Parquet` |
| `Compression` | The compression type for CUR report | `GZIP` | `ZIP`, `GZIP`, `Parquet` |
| `S3BucketPrefix` | The prefix for CUR files in the S3 bucket | `cur2` | String |
| `ReportVersioning` | Whether to overwrite or create new reports | `OVERWRITE_REPORT` | `CREATE_NEW_REPORT`, `OVERWRITE_REPORT` |
| `RefreshClosedReports` | Whether to refresh finalized reports | `true` | `true`, `false` |

### Feature Toggle Parameters

| Parameter | Description | Default | Allowed Values |
|-----------|-------------|---------|----------------|
| `EnableKMSEncryption` | Enable KMS encryption for S3 bucket | `false` | `true`, `false` |
| `EnableVersioning` | Enable S3 bucket versioning | `true` | `true`, `false` |
| `EnablePublicAccessBlock` | Enable S3 public access block | `true` | `true`, `false` |
| `EnableReplication` | Enable cross-account S3 replication | `false` | `true`, `false` |

| `EnableCostOptimizationHub` | Enable COH data exports | `false` | `true`, `false` |

### KMS Parameters

| Parameter | Description | Default | Type |
|-----------|-------------|---------|------|
| `KMSKeyId` | Existing KMS key ID (if empty, new key created) | `` | String |
| `KMSKeyDeletionWindow` | KMS key deletion window in days | `7` | Number (7-30) |

### Replication Parameters

| Parameter | Description | Default | Type |
|-----------|-------------|---------|------|
| `ReplicationDestinationBucket` | Destination bucket ARN for replication | `` | String |
| `ReplicationDestinationAccountId` | Destination AWS account ID | `` | String (12 digits) |
| `ReplicationDestinationRegion` | Destination AWS region | `` | String |
| `ReplicationPrefix` | Object prefix for replication | `` | String |
| `ReplicationStorageClass` | Storage class for replicated objects | `STANDARD_IA` | Various S3 storage classes |
| `ReplicationReplicaKMSKeyId` | KMS key for replica encryption | `` | String |

### Cost Optimization Hub Parameters

| Parameter | Description | Default | Type |
|-----------|-------------|---------|------|
| `COHExportName` | Name for COH data export | `cost-optimization-hub-export` | String |
| `COHS3Prefix` | S3 prefix for COH exports | `coh` | String |
| `COHFilter` | Filter for COH recommendations | `{}` | String (JSON) |
| `COHIncludeAllRecommendations` | Include all recommendations | `false` | `true`, `false` |
| `COHRefreshFrequency` | COH refresh frequency | `SYNCHRONOUS` | `SYNCHRONOUS` |

### Schema and Artifact Parameters

| Parameter | Description | Default | Type |
|-----------|-------------|---------|------|
| `AdditionalSchemaElements` | Additional schema elements | `RESOURCES` | CommaDelimitedList |
| `AdditionalArtifacts` | Additional artifacts to include | `REDSHIFT,QUICKSIGHT,ATHENA` | CommaDelimitedList |

### Tagging Parameters

| Parameter | Description | Default | Type |
|-----------|-------------|---------|------|
| `Environment` | Environment tag | `` | String |
| `Project` | Project tag | `` | String |
| `Owner` | Owner tag | `` | String |

## Outputs

The template provides comprehensive outputs including:

- **CUR Configuration**: Report name, ARN, and configuration summary
- **S3 Configuration**: Bucket details, ARNs, and domain names
- **KMS Configuration**: Key and alias details (if KMS enabled)
- **Replication Configuration**: Replication role ARN (if replication enabled)

- **COH Configuration**: Export details (if COH enabled)

## Architecture

The template creates the following AWS resources:

```
┌─────────────────────────────────────────────────────────────────┐
│                    AWS Account (us-east-1)                     │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌──────────────────┐                   │
│  │   KMS Key       │────│   S3 Bucket      │                   │
│  │   (Optional)    │    │   - Versioning   │                   │
│  └─────────────────┘    │   - Encryption   │                   │
│  ┌─────────────────┐    │   - Policies     │                   │
│  │   CUR Report    │────┤                  │                   │
│  │   Definition    │    └──────────────────┘                   │
│  └─────────────────┘               │                           │
│                                    │                           │
│  ┌─────────────────┐               │                           │
│  │   COH Export    │───────────────┘                           │
│  │   (Optional)    │                                           │
│  └─────────────────┘                                           │
│                                                                │
│                                                                │
│  ┌─────────────────┐                                           │
│  │ Replication Role│────────────────────────────────────────┐  │
│  │   (Optional)    │                                        │  │
│  └─────────────────┘                                        │  │
└─────────────────────────────────────────────────────────────┼──┘
┌─────────────────────────────────────────────────────────────┼──┐
│                 Destination Account                         │  │
│                                                             │  │
│  ┌──────────────────┐                                       │  │
│  │ Destination      │◄──────────────────────────────────────┘  │
│  │ S3 Bucket        │                                          │
│  │                  │                                          │
│  └──────────────────┘                                          │
─────────────────────────────────────────────────────────────────┘
```

## Important Notes

1. **Region Requirement**: CUR reports can only be created in the `us-east-1` region
2. **S3 Bucket Names**: Must be globally unique
3. **Replication Requirements**:
   - Source bucket must have versioning enabled
   - Destination bucket must exist and have versioning enabled
   - Destination bucket must be in a different region
4. **Cost Optimization Hub**:
   - Must be enabled in your AWS account before using
   - Requires additional permissions for bcm-data-exports service
5. **KMS Encryption**:
   - If you provide an existing KMS key ID, ensure proper permissions
   - If not provided, a new key will be created with appropriate policies

## Migration from Terraform

If you're migrating from the Terraform module:

1. **Export Terraform State**: Note the current resource names and configurations
2. **Parameter Mapping**: Map Terraform variables to CloudFormation parameters
3. **Import Existing Resources**: Use CloudFormation import functionality for existing resources
4. **Validate Configuration**: Ensure all features are properly configured

### Terraform to CloudFormation Parameter Mapping

| Terraform Variable | CloudFormation Parameter |
|---------------------|---------------------------|
| `s3_bucket_name` | `S3BucketName` |
| `report_name` | `ReportName` |
| `time_unit` | `TimeUnit` |
| `format` | `Format` |
| `compression` | `Compression` |
| `enable_kms_encryption` | `EnableKMSEncryption` |
| `enable_cost_optimization_hub` | `EnableCostOptimizationHub` |
| `enable_replication` | `EnableReplication` |
| `replication_destination_bucket` | `ReplicationDestinationBucket` |
| `coh_export_name` | `COHExportName` |

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure the executing role has appropriate billing and service permissions
2. **Region Errors**: Remember CUR can only be created in us-east-1
3. **Bucket Conflicts**: S3 bucket names must be globally unique
4. **Replication Failures**: Verify destination bucket exists and has versioning enabled
5. **COH Export Failures**: Ensure Cost Optimization Hub is enabled in your account

### Stack Rollback Issues

If the stack fails to create:

1. Check CloudFormation events for specific error messages
2. Verify all prerequisite resources exist (destination bucket for replication)
3. Ensure all required permissions are granted
4. Check parameter values are valid

## Support

For issues and questions:

- Review AWS CloudFormation documentation
- Check AWS CUR documentation  
- Verify AWS service quotas and limits
- Contact AWS Support for service-specific issues

## License

This template is provided under the same license as the original Terraform module.
