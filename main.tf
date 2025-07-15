#
# Cost and Usage Report (CUR) Terraform Module
# This module creates a CUR report with S3 bucket storage and optional cross-account replication
#

#
# KMS Key for S3 Encryption
#
resource "aws_kms_key" "cur_s3_key" {
  count = var.enable_kms_encryption && var.kms_key_id == "" ? 1 : 0

  description             = "KMS key for Cost and Usage Report S3 bucket encryption"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = true

  tags = merge(local.tags, {
    Name = "${var.report_name}-s3-key"
  })
}

## Provision a KMS alias for the S3 key
resource "aws_kms_alias" "cur_s3_key_alias" {
  count = var.enable_kms_encryption && var.kms_key_id == "" ? 1 : 0

  name          = "alias/${var.report_name}-s3-key"
  target_key_id = aws_kms_key.cur_s3_key[0].key_id
}

# KMS key policy for S3 and CUR service access
data "aws_iam_policy_document" "cur_s3_key_policy" {
  count = var.enable_kms_encryption && var.kms_key_id == "" ? 1 : 0

  statement {
    sid    = "EnableRootAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowCURService"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["billingreports.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowS3Service"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = var.enable_replication ? [1] : []
    content {
      sid    = "AllowReplicationDestinationAccess"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = ["arn:aws:iam::${var.replication_destination_account_id}:root"]
      }
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      resources = ["*"]
    }
  }
}

## Provision a KMS key policy for the S3 key
resource "aws_kms_key_policy" "cur_s3_key_policy" {
  count = var.enable_kms_encryption && var.kms_key_id == "" ? 1 : 0

  key_id = aws_kms_key.cur_s3_key[0].id
  policy = data.aws_iam_policy_document.cur_s3_key_policy[0].json
}

#
# S3 Bucket for CUR Storage
#
resource "aws_s3_bucket" "cur_bucket" {
  bucket = var.s3_bucket_name

  tags = merge(local.tags, {
    Name = var.s3_bucket_name
  })
}

# S3 Bucket versioning
resource "aws_s3_bucket_versioning" "cur_bucket_versioning" {
  bucket = aws_s3_bucket.cur_bucket.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Disabled"
  }
}

# S3 Bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "cur_bucket_encryption" {
  count = var.enable_kms_encryption ? 1 : 0

  bucket = aws_s3_bucket.cur_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_id != "" ? var.kms_key_id : aws_kms_key.cur_s3_key[0].arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# S3 Bucket public access block
resource "aws_s3_bucket_public_access_block" "cur_bucket_pab" {
  count = var.enable_public_access_block ? 1 : 0

  block_public_acls       = true
  block_public_policy     = true
  bucket                  = aws_s3_bucket.cur_bucket.id
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket policy for CUR service
data "aws_iam_policy_document" "cur_bucket_policy" {
  statement {
    sid    = "AllowCURServiceGetBucketAcl"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["billingreports.amazonaws.com"]
    }
    actions = [
      "s3:GetBucketAcl",
      "s3:GetBucketPolicy"
    ]
    resources = [aws_s3_bucket.cur_bucket.arn]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = ["arn:aws:cur:us-east-1:${local.account_id}:definition/*"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [local.account_id]
    }
  }

  statement {
    sid    = "AllowCURServicePutObject"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["billingreports.amazonaws.com"]
    }
    actions = [
      "s3:PutObject"
    ]
    resources = ["${aws_s3_bucket.cur_bucket.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = ["arn:aws:cur:us-east-1:${local.account_id}:definition/*"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [local.account_id]
    }
  }

  # Allow Cost Optimization Hub service access
  dynamic "statement" {
    for_each = var.enable_cost_optimization_hub ? [1] : []
    content {
      sid    = "AllowCOHServiceGetBucketAcl"
      effect = "Allow"
      principals {
        type        = "Service"
        identifiers = ["bcm-data-exports.amazonaws.com"]
      }
      actions = [
        "s3:GetBucketAcl",
        "s3:GetBucketPolicy"
      ]
      resources = [aws_s3_bucket.cur_bucket.arn]
      condition {
        test     = "StringEquals"
        variable = "AWS:SourceAccount"
        values   = [local.account_id]
      }
    }
  }

  dynamic "statement" {
    for_each = var.enable_cost_optimization_hub ? [1] : []
    content {
      sid    = "AllowCOHServicePutObject"
      effect = "Allow"
      principals {
        type        = "Service"
        identifiers = ["bcm-data-exports.amazonaws.com"]
      }
      actions = [
        "s3:PutObject"
      ]
      resources = ["${aws_s3_bucket.cur_bucket.arn}/*"]
      condition {
        test     = "StringEquals"
        variable = "AWS:SourceAccount"
        values   = [local.account_id]
      }
    }
  }

  # Allow replication service access
  dynamic "statement" {
    for_each = var.enable_replication ? [1] : []
    content {
      sid    = "AllowReplicationServiceAccess"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = [aws_iam_role.replication_role[0].arn]
      }
      actions = [
        "s3:GetObjectVersionForReplication",
        "s3:GetObjectVersionAcl",
        "s3:GetObjectVersionTagging"
      ]
      resources = ["${aws_s3_bucket.cur_bucket.arn}/*"]
    }
  }

  dynamic "statement" {
    for_each = var.enable_replication ? [1] : []
    content {
      sid    = "AllowReplicationServiceList"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = [aws_iam_role.replication_role[0].arn]
      }
      actions = [
        "s3:ListBucket"
      ]
      resources = [aws_s3_bucket.cur_bucket.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "cur_bucket_policy" {
  bucket = aws_s3_bucket.cur_bucket.id
  policy = data.aws_iam_policy_document.cur_bucket_policy.json

  depends_on = [aws_s3_bucket_public_access_block.cur_bucket_pab]
}

#
# S3 Bucket Replication Configuration
#

# IAM role for replication
resource "aws_iam_role" "replication_role" {
  count = var.enable_replication ? 1 : 0

  name = "${var.report_name}-replication-role"
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for replication role
data "aws_iam_policy_document" "replication_policy" {
  count = var.enable_replication ? 1 : 0

  # Source bucket permissions
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.cur_bucket.arn,
      "${aws_s3_bucket.cur_bucket.arn}/*"
    ]
  }

  # Destination bucket permissions
  statement {
    effect = "Allow"
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags"
    ]
    resources = ["${var.replication_destination_bucket}/*"]
  }

  # KMS permissions for encryption
  dynamic "statement" {
    for_each = var.enable_kms_encryption ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      resources = [
        var.kms_key_id != "" ? var.kms_key_id : aws_kms_key.cur_s3_key[0].arn
      ]
    }
  }

  # KMS permissions for destination encryption
  dynamic "statement" {
    for_each = var.replication_replica_kms_key_id != "" ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "kms:Encrypt",
        "kms:GenerateDataKey"
      ]
      resources = [var.replication_replica_kms_key_id]
    }
  }
}

resource "aws_iam_role_policy" "replication_policy" {
  count = var.enable_replication ? 1 : 0

  name   = "${var.report_name}-replication-policy"
  role   = aws_iam_role.replication_role[0].id
  policy = data.aws_iam_policy_document.replication_policy[0].json
}

# S3 bucket replication configuration
resource "aws_s3_bucket_replication_configuration" "cur_replication" {
  count = var.enable_replication ? 1 : 0

  role   = aws_iam_role.replication_role[0].arn
  bucket = aws_s3_bucket.cur_bucket.id

  rule {
    id     = "${var.report_name}-replication-rule"
    status = "Enabled"

    dynamic "filter" {
      for_each = var.replication_prefix != "" ? [1] : []
      content {
        prefix = var.replication_prefix
      }
    }

    destination {
      bucket        = var.replication_destination_bucket
      storage_class = var.replication_storage_class

      dynamic "encryption_configuration" {
        for_each = var.replication_replica_kms_key_id != "" ? [1] : []
        content {
          replica_kms_key_id = var.replication_replica_kms_key_id
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.cur_bucket_versioning]
}

#
# SNS Topic for Bucket Notifications (Optional)
#
resource "aws_sns_topic" "cur_notifications" {
  count = var.enable_bucket_notification && var.notification_topic_arn == "" ? 1 : 0

  name = "${var.report_name}-notifications"
  tags = local.tags
}

resource "aws_sns_topic_policy" "cur_notifications_policy" {
  count = var.enable_bucket_notification && var.notification_topic_arn == "" ? 1 : 0

  arn = aws_sns_topic.cur_notifications[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.cur_notifications[0].arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = local.account_id
          }
        }
      }
    ]
  })
}

# S3 bucket notification configuration
resource "aws_s3_bucket_notification" "cur_bucket_notification" {
  count = var.enable_bucket_notification ? 1 : 0

  bucket = aws_s3_bucket.cur_bucket.id

  topic {
    topic_arn     = var.notification_topic_arn != "" ? var.notification_topic_arn : aws_sns_topic.cur_notifications[0].arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = var.s3_bucket_prefix
  }

  # Additional notification for Cost Optimization Hub files
  dynamic "topic" {
    for_each = var.enable_cost_optimization_hub ? [1] : []
    content {
      topic_arn     = var.notification_topic_arn != "" ? var.notification_topic_arn : aws_sns_topic.cur_notifications[0].arn
      events        = ["s3:ObjectCreated:*"]
      filter_prefix = "${var.coh_s3_prefix}/${local.account_id}"
    }
  }

  depends_on = [aws_sns_topic_policy.cur_notifications_policy]
}

#
# Cost and Usage Report Definition
#
resource "aws_cur_report_definition" "cur_report" {
  report_name                = var.report_name
  time_unit                  = var.time_unit
  format                     = var.format
  compression                = var.compression
  additional_schema_elements = var.additional_schema_elements
  s3_bucket                  = aws_s3_bucket.cur_bucket.id
  s3_prefix                  = var.s3_bucket_prefix
  s3_region                  = local.region
  additional_artifacts       = var.additional_artifacts
  refresh_closed_reports     = var.refresh_closed_reports
  report_versioning          = var.report_versioning

  depends_on = [aws_s3_bucket_policy.cur_bucket_policy]
}

#
# Cost Optimization Hub Data Export
#
resource "aws_bcmdataexports_export" "cost_optimization_hub" {
  count = var.enable_cost_optimization_hub ? 1 : 0

  export {
    name        = var.coh_export_name
    description = "Cost Optimization Hub Recommendations export for aggregation in CID"

    data_query {
      query_statement = "SELECT * FROM COST_OPTIMIZATION_RECOMMENDATIONS"
      table_configurations = {
        COST_OPTIMIZATION_RECOMMENDATIONS = {
          FILTER                      = var.coh_filter
          INCLUDE_ALL_RECOMMENDATIONS = var.coh_include_all_recommendations ? "TRUE" : "FALSE"
        }
      }
    }

    destination_configurations {
      s3_destination {
        s3_bucket = aws_s3_bucket.cur_bucket.id
        s3_prefix = "${var.coh_s3_prefix}/${local.account_id}"
        s3_region = local.region
        s3_output_configurations {
          overwrite   = "OVERWRITE_REPORT"
          format      = "PARQUET"
          compression = "PARQUET"
          output_type = "CUSTOM"
        }
      }
    }

    refresh_cadence {
      frequency = var.coh_refresh_frequency
    }
  }

  depends_on = [aws_s3_bucket_policy.cur_bucket_policy]

  tags = merge(local.tags, {
    Name = var.coh_export_name
    Type = "cost-optimization-hub-export"
  })
}
