resource "aws_kms_key" "state_bucket_key" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = var.default_tags
}

resource "aws_kms_alias" "state_bucket_key_alias" {
  name_prefix   = var.state_bucket_key_alias_prefix
  target_key_id = aws_kms_key.state_bucket_key.key_id
}

resource "aws_s3_bucket" "this" {
  bucket = var.state_bucket_name

  tags = var.default_tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.state_bucket_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_acl" "this" {
  bucket = aws_s3_bucket.this.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  // Will be default for new buckets since April 2023
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
