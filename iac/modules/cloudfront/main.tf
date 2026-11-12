locals {
  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.s3_bucket_id}-oac"
  description                       = "OAC for ${var.s3_bucket_id}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name              = var.s3_bucket_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    origin_id                = var.origin_id
  }

  enabled             = true
  default_root_object = var.default_root_object

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = var.origin_id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = local.common_tags
}

data "aws_iam_policy_document" "s3_policy" {
  count = var.attach_s3_policy ? 1 : 0

  dynamic "statement" {
    for_each = var.enforce_tls ? [1] : []
    content {
      sid     = "EnforceTLSRequestsOnly"
      effect  = "Deny"
      actions = ["s3:*"]
      resources = [
        var.s3_bucket_arn,
        "${var.s3_bucket_arn}/*"
      ]

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      condition {
        test     = "Bool"
        variable = "aws:SecureTransport"
        values   = ["false"]
      }
    }
  }

  statement {
    sid     = "AllowCloudFrontOACAccess"
    effect  = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "${var.s3_bucket_arn}/*"
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cdn.arn]
    }
  }

  dynamic "statement" {
    for_each = var.allow_public_read ? [1] : []
    content {
      sid     = "AllowPublicReadGetObject"
      effect  = "Allow"
      actions = ["s3:GetObject"]
      resources = [
        "${var.s3_bucket_arn}/*"
      ]

      principals {
        type        = "*"
        identifiers = ["*"]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "cloudfront_access" {
  count  = var.attach_s3_policy ? 1 : 0
  bucket = var.s3_bucket_id
  policy = data.aws_iam_policy_document.s3_policy[0].json
}
