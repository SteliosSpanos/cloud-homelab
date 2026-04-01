/*
    The S3 bucket (with versioning) accessed by the main VM through a VPC endpoint.
    The access to the bucket follows the bucket policies and has server side encryption.
*/

resource "aws_s3_bucket" "homelab" {
  bucket = "${var.project_name}-storage-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-storage"
  }
}

// Bucker versioning

resource "aws_s3_bucket_versioning" "homelab" {
  bucket = aws_s3_bucket.homelab.id

  versioning_configuration {
    status = "Enabled"
  }
}

// Restrict public access to the bucket

resource "aws_s3_bucket_public_access_block" "homelab" {
  bucket = aws_s3_bucket.homelab.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

// Configuration of lifecycle of shadow files

resource "aws_s3_bucket_lifecycle_configuration" "homelab" {
  bucket = aws_s3_bucket.homelab.id

  rule {
    id     = "cleanup-old-version"
    status = "Enabled"

    filter {} // Applies to every object in the bucket

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

// S3 Bucket Policy (Resource based)

resource "aws_s3_bucket_policy" "homelab" {
  bucket = aws_s3_bucket.homelab.id

  policy = data.aws_iam_policy_document.s3_bucket_policy.json

  # Ensure the policy is applied last so it doesn't block other configurations
  depends_on = [
    aws_s3_bucket_versioning.homelab,
    aws_s3_bucket_server_side_encryption_configuration.homelab,
    aws_s3_bucket_public_access_block.homelab,
    aws_s3_bucket_lifecycle_configuration.homelab
  ]
}


// VPC Endpoint

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.homelab_vpc.id
  service_name = "com.amazonaws.${var.region}.s3"

  route_table_ids = [aws_route_table.homelab_private_rt.id]

  tags = {
    Name = "${var.project_name}-s3-endpoint"
  }
}

resource "aws_vpc_endpoint_policy" "s3_policy" {
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
  policy          = data.aws_iam_policy_document.s3_endpoint_policy.json
}

// Server side encryption

resource "aws_s3_bucket_server_side_encryption_configuration" "homelab" {
  bucket = aws_s3_bucket.homelab.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_alias.homelab.arn
    }
    bucket_key_enabled = true
  }
}
