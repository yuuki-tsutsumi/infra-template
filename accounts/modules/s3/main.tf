resource "aws_s3_bucket" "this" {
  bucket = "${var.service_name}-${var.env}"

  tags = {
    Terraform = "true"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_ssm_parameter" "bucketname" {
  name  = "/s3/bucketname"
  type  = "SecureString"
  value = aws_s3_bucket.this.bucket

  tags = {
    Terraform = "true"
  }
}
