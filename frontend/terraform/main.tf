provider "aws" {
  region = "us-east-1" 
}

variable "github_repository_url" {
  description = "URL of the GitHub repository"
  type        = string
  default     = "https://github.com/mbt1/ct20231211.git"
}

#---------------------------------------------------------------------------------------------
#---- react_app: S3 Bucket for static website (the report viewer)
#---------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "react_app" {
  bucket = "ct20231211-react-app-bucket" 
}
resource "aws_s3_bucket_public_access_block" "react_app_public_access_block" {
  bucket = aws_s3_bucket.react_app.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
resource "aws_s3_bucket_policy" "react_app_policy" {
  bucket = aws_s3_bucket.react_app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource = "arn:aws:s3:::${aws_s3_bucket.react_app.id}/*"  
      },
    ]
  })
}
resource "aws_s3_bucket_cors_configuration" "react_app_cors_configuration" {
  bucket = aws_s3_bucket.react_app.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    expose_headers  = []
    max_age_seconds = 3000
  }
}
resource "aws_s3_bucket_website_configuration" "react_app_website_configuration" {
  bucket = aws_s3_bucket.react_app.id

  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "index.html"
  }
}
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.react_app.bucket_regional_domain_name}"
    origin_id   = "S3-${aws_s3_bucket.react_app.id}"
  }

  enabled             = true
  default_root_object = "index.html"
  
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Default Cache Behavior
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.react_app.id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Viewer Certificate
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

#---------------------------------------------------------------------------------------------
#---- provide output values
#---------------------------------------------------------------------------------------------

output "CLOUDFRONT_URL" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}
output "CLOUDFRONT_ID" {
  value = aws_cloudfront_distribution.s3_distribution.id
}
output "S3_WEBSITE_URL" {
  value = "http://${aws_s3_bucket.react_app.id}.${aws_s3_bucket_website_configuration.react_app_website_configuration.website_domain}"
}
output "S3_WEBSITE_BUCKET" {
  value = aws_s3_bucket.react_app.id
}
