###############################################################################
# modules/s3/main.tf
#
# General-purpose application/artifact bucket for workloads running on the
# cluster (e.g. app file storage, CI artifact cache, ALB access logs).
# Hardened the same way the Terraform state bucket is: versioning,
# default encryption, and a full public access block. Access from EKS
# workloads should go through IRSA-scoped IAM policies (see
# modules/eks lb_controller_irsa for the pattern), never node-wide
# instance-profile access.
###############################################################################

locals {
  bucket_name = var.bucket_name != "" ? var.bucket_name : "${var.name_prefix}-app-data-${var.account_id}"
}

resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name

  tags = merge(var.tags, {
    Name = local.bucket_name
  })
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    filter {}
  }
}
