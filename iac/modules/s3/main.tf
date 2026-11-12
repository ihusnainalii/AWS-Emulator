locals {
  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

data "aws_iam_policy_document" "kms_key_policy" {
  count = var.enable_kms_encryption ? 1 : 0

  statement {
    sid       = "EnableRootAndIAMPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::000000000000:root"]
    }
  }

  statement {
    sid       = "AllowCloudFrontServicePrincipalSSEKMS"
    effect    = "Allow"
    actions   = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
  }

  dynamic "statement" {
    for_each = var.allow_public_read ? [1] : []
    content {
      sid       = "AllowPublicDecryptForS3"
      effect    = "Allow"
      actions   = ["kms:Decrypt"]
      resources = ["*"]

      principals {
        type        = "*"
        identifiers = ["*"]
      }
    }
  }
}

resource "aws_kms_key" "s3" {
  count = var.enable_kms_encryption ? 1 : 0

  description             = "KMS CMK for S3 bucket ${var.bucket_name} encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_key_policy[0].json

  tags = local.common_tags
}

resource "aws_kms_alias" "s3" {
  count = var.enable_kms_encryption ? 1 : 0

  name          = "alias/s3-${var.bucket_name}"
  target_key_id = aws_kms_key.s3[0].key_id
}

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "this" {
  count = var.enable_versioning ? 1 : 0

  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count = var.enable_kms_encryption ? 1 : 0

  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3[0].arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  count = var.block_public_access ? 1 : 0

  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = !var.allow_public_read
  restrict_public_buckets = !var.allow_public_read
}
