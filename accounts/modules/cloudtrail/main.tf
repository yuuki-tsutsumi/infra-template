resource "aws_cloudtrail" "this" {
  name                          = "trails"
  s3_bucket_name                = aws_s3_bucket.this.id
  include_global_service_events = true
  enable_log_file_validation    = true
  is_multi_region_trail         = true

  tags = {
    Terraform = "true"
  }
}

resource "aws_s3_bucket" "this" {
  bucket        = "awslogs-cloudtrail-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Terraform = "true"
  }
}

data "aws_iam_policy_document" "this" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = ["arn:aws:s3:::awslogs-cloudtrail-${data.aws_caller_identity.current.account_id}"]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::awslogs-cloudtrail-${data.aws_caller_identity.current.account_id}/*"]
  }

  statement {
    sid    = "EnforceHTTPS"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::awslogs-cloudtrail-${data.aws_caller_identity.current.account_id}",
      "arn:aws:s3:::awslogs-cloudtrail-${data.aws_caller_identity.current.account_id}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.this.json
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_caller_identity" "current" {}
