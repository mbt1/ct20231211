# To authenticate, run:
# aws configure

# Generate Names
locals {
  current_timestamp     = formatdate("YYYY-MM-DD HH:mm:ss", timestamp())
  resource_prefix       = "ct20231211"
  application_name      = "${local.resource_prefix}"
  staging_bucket_name   = "${local.resource_prefix}-staging"
  common_tags           = {
                            Project = "${local.resource_prefix}"
                            Created = "${local.current_timestamp}"
                          }
}
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}
#----------------------------------------------------------------------------

# Create an S3 bucket
resource "aws_s3_bucket" "staging_bucket" {
  bucket = local.staging_bucket_name
  tags = local.common_tags
}
resource "aws_s3_bucket_public_access_block" "staging_bucket_public_access_block" {
  bucket = aws_s3_bucket.staging_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.staging_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource = "arn:aws:s3:::${aws_s3_bucket.staging_bucket.id}/*"  
      },
    ]
  })
}

output "staging_bucket_url" {value = aws_s3_bucket.staging_bucket.bucket_domain_name}
output "staging_bucket_arn" {value = aws_s3_bucket.staging_bucket.arn}
output "staging_bucket_name" {value = local.staging_bucket_name}