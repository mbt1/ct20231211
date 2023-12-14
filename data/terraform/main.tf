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

#---------------------------------------------------------------------------------------------
#---- staging_bucket: S3 Bucket
#---------------------------------------------------------------------------------------------

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

#---------------------------------------------------------------------------------------------
#---- ProductivityDataImport: AWS Lambda Function
#---------------------------------------------------------------------------------------------

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_iam_role" "productivity_iam_role" {
  name = "productivity_iam_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
      },
    ],
  })
}
resource "aws_iam_policy" "productivity_secrets_policy" {
  name = "productivity_secrets_policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "secretsmanager:GetSecretValue",
        Effect = "Allow",
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:CT20231211_*"
      }
    ]
  })
}
resource "aws_iam_policy" "productivity_s3_policy" {
  name        = "productivity_s3_policy"
  description = "IAM policy for Lambda to access S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ],
        Resource = [
          "${aws_s3_bucket.staging_bucket.arn}",
          "${aws_s3_bucket.staging_bucket.arn}/*"
        ]
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "attach_productivity_s3_policy" {
  role       = aws_iam_role.productivity_iam_role.name
  policy_arn = aws_iam_policy.productivity_s3_policy.arn
}
resource "aws_iam_role_policy_attachment" "attach_productivity_secrets_policy" {
  role       = aws_iam_role.productivity_iam_role.name
  policy_arn = aws_iam_policy.productivity_secrets_policy.arn
}
resource "aws_iam_role_policy_attachment" "attach_productivity_lambda_policy" {
  role       = aws_iam_role.productivity_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "productivity_lambda" {
  function_name    = "ProductivityDataImport"
  role             = aws_iam_role.productivity_iam_role.arn
  handler          = "productivity.main"
  runtime          = "python3.11"  # Match your runtime
  timeout          = 300

  filename         = "${path.module}/../.aws-sam/ProductivityDataImport.zip"
  source_code_hash = filebase64sha256("${path.module}/../.aws-sam/ProductivityDataImport.zip")
}
resource "aws_cloudwatch_event_rule" "productivity_lambda_schedule" {
  name                = "productivity-lambda-schedule-rule"
  description         = "Trigger ProductivityDataImport on a schedule"
  schedule_expression = "rate(6 hours)"  
}
resource "aws_cloudwatch_event_target" "productivity_lambda_target" {
  rule = aws_cloudwatch_event_rule.productivity_lambda_schedule.name
  arn  = aws_lambda_function.productivity_lambda.arn
}
resource "aws_lambda_permission" "allow_cloudwatch_to_invoke_productivity_lambda" {
  statement_id  = "AllowProductivityDataImportExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.productivity_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.productivity_lambda_schedule.arn
}
#---------------------------------------------------------------------------------------------
#---- Print Output Values
#---------------------------------------------------------------------------------------------

output "staging_bucket_url" {value = aws_s3_bucket.staging_bucket.bucket_domain_name}
output "staging_bucket_arn" {value = aws_s3_bucket.staging_bucket.arn}
output "staging_bucket_name" {value = local.staging_bucket_name}