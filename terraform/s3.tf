resource "aws_s3_bucket" "kops_state" {
  bucket = "${local.name_prefix}-kops-state"

  tags = {
    Name = "${local.name_prefix}-kops-state"
  }
}

resource "aws_s3_bucket_versioning" "kops_state" {
  bucket = aws_s3_bucket.kops_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "kops_state" {
  bucket = aws_s3_bucket.kops_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "kops_state" {
  bucket = aws_s3_bucket.kops_state.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.public.id,
    aws_route_table.private.id,
    aws_route_table.isolated.id,
  ]

  tags = {
    Name = "${local.name_prefix}-s3-endpoint"
  }
}
