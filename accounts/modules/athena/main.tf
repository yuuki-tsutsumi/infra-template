resource "aws_athena_workgroup" "this" {
  name = var.service_name

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = false
    result_configuration {
      output_location = "s3://${aws_s3_bucket.this.id}/"
    }
  }

  force_destroy = true

  tags = {
    Terraform = "true"
  }
}

resource "aws_athena_database" "this" {
  name   = var.service_name_underscore
  bucket = aws_s3_bucket.this.id

  force_destroy = true
}

resource "aws_s3_bucket" "this" {
  bucket        = "athena-output-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Terraform = "true"
  }
}

data "aws_iam_policy_document" "this" {
  statement {
    sid    = "EnforceHTTPS"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::athena-output-${data.aws_caller_identity.current.account_id}",
      "arn:aws:s3:::athena-output-${data.aws_caller_identity.current.account_id}/*"
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
