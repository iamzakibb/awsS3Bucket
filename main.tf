


resource "aws_s3_bucket" "log_bucket" {
  bucket = "s3-log-bucket-example001" 

  lifecycle {
    prevent_destroy = true
  }
}
# Add this to your existing main.tf
resource "aws_s3_bucket_policy" "enforce_https" {
  bucket = aws_s3_bucket.log_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnforceSecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          "${aws_s3_bucket.log_bucket.arn}",
          "${aws_s3_bucket.log_bucket.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Enable versioning
resource "aws_s3_bucket_versioning" "log_versioning" {
  bucket = aws_s3_bucket.log_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "log_block_public" {
  bucket = aws_s3_bucket.log_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable SSE-S3 encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# IAM Role with full access except deletion
resource "aws_iam_role" "s3_log_role" {
  name = "s3_log_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Custom policy with delete restrictions
resource "aws_iam_policy" "s3_log_policy" {
  name = "s3_log_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:*"
        Resource = [
          "${aws_s3_bucket.log_bucket.arn}",
          "${aws_s3_bucket.log_bucket.arn}/*"
        ]
      },
      {
        Effect   = "Deny"
        Action   = [
          "s3:DeleteBucket",
          "s3:DeleteObject",
          "s3:DeleteObjects",
          "s3:DeleteBucketPolicy"
        ]
        Resource = [
          "${aws_s3_bucket.log_bucket.arn}",
          "${aws_s3_bucket.log_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_log_attachment" {
  role       = aws_iam_role.s3_log_role.name
  policy_arn = aws_iam_policy.s3_log_policy.arn
}

output "bucket_name" {
  value = aws_s3_bucket.log_bucket.bucket
}

output "role_arn" {
  value = aws_iam_role.s3_log_role.arn
}