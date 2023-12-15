# To authenticate, run:
# aws configure

# Generate Names
locals {
  current_timestamp     = formatdate("YYYY-MM-DD HH:mm:ss", timestamp())
  resource_prefix       = "ct20231211"
  container-image-name  = "${local.resource_prefix}-ecs-image"
  application_name      = "${local.resource_prefix}"
  staging_bucket_name   = "${local.resource_prefix}-staging"
  report_bucket_name    = "${local.resource_prefix}-reports"
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
resource "aws_s3_bucket_policy" "staging_bucket_policy" {
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
#---- report_bucket: S3 Bucket
#---------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "report_bucket" {
  bucket = local.report_bucket_name
  tags = local.common_tags
}
resource "aws_s3_bucket_public_access_block" "report_bucket_public_access_block" {
  bucket = aws_s3_bucket.report_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
resource "aws_s3_bucket_policy" "report_bucket_policy" {
  bucket = aws_s3_bucket.report_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource = "arn:aws:s3:::${aws_s3_bucket.report_bucket.id}/*"  
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
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${local.resource_prefix}_*"
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
#---- Set up ECS Cluster
#---------------------------------------------------------------------------------------------

resource "aws_ecr_repository" "ecr_repository" {
  name                 = "${local.resource_prefix}-ecr-repository"
  image_tag_mutability = "MUTABLE"  

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${local.resource_prefix}-ecs-cluster"
}

resource "aws_ecs_task_definition" "ecs_task" {
  family                   = "${local.resource_prefix}-ecs-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "${local.resource_prefix}-ecs-container",
      image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/${local.container-image-name}:latest",
    }
  ])
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_policy" "ecs_s3_policy" {
  name        = "ecs_s3_policy"
  description = "IAM policy for ecs to access S3 bucket"

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
          "${aws_s3_bucket.report_bucket.arn}",
          "${aws_s3_bucket.report_bucket.arn}/*"
        ]
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "attach_ecs_s3_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.ecs_s3_policy.arn
}

resource "aws_vpc" "ecs_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.resource_prefix}-ecs-vpc"
  }
}
resource "aws_internet_gateway" "ecs_igw" {
  vpc_id = aws_vpc.ecs_vpc.id

  tags = {
    Name = "${local.resource_prefix}-ecs-internet-gateway"
  }
}
resource "aws_subnet" "ecs_subnet" {
  vpc_id                  = aws_vpc.ecs_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.resource_prefix}-ecs-public-subnet"
  }
}
resource "aws_route_table" "ecs_route_table" {
  vpc_id = aws_vpc.ecs_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ecs_igw.id
  }

  tags = {
    Name = "${local.resource_prefix}-ecs-route-table"
  }
}
resource "aws_route_table_association" "ecs_route_table_association" {
  subnet_id      = aws_subnet.ecs_subnet.id
  route_table_id = aws_route_table.ecs_route_table.id
}
resource "aws_security_group" "ecs_sg" {
  name        = "${local.resource_prefix}-ecs-security-group"
  description = "Security group for ECS task"
  vpc_id      = aws_vpc.ecs_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.resource_prefix}-ecs-security-group"
  }
}

#---------------------------------------------------------------------------------------------
#---- Set up SQSListener lambda function
#---------------------------------------------------------------------------------------------

resource "aws_iam_role" "sqslistener_iam_role" {
  name = "sqslistener_iam_role"

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
resource "aws_iam_policy" "sqslistener_s3_policy" {
  name        = "sqslistener_s3_policy"
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
          "${aws_s3_bucket.staging_bucket.arn}/*",
          "${aws_s3_bucket.report_bucket.arn}",
          "${aws_s3_bucket.report_bucket.arn}/*"
        ]
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "attach_sqslistener_s3_policy" {
  role       = aws_iam_role.sqslistener_iam_role.name
  policy_arn = aws_iam_policy.sqslistener_s3_policy.arn
}
resource "aws_iam_role_policy_attachment" "attach_sqslistener_lambda_policy" {
  role       = aws_iam_role.sqslistener_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_lambda_function" "sqslistener_lambda" {
  function_name    = "SQSListener"
  role             = aws_iam_role.sqslistener_iam_role.arn
  handler          = "sqs-listener.main"
  runtime          = "python3.11"  # Match your runtime
  timeout          = 10

  filename         = "${path.module}/../.aws-sam/SQSListener.zip"
  source_code_hash = filebase64sha256("${path.module}/../.aws-sam/SQSListener.zip")
  environment {
    variables = {
      TF_VAR_ECS_CLUSTER_NAME    = aws_ecs_cluster.ecs_cluster.name
      TF_VAR_ECS_TASK_DEFINITION = aws_ecs_task_definition.ecs_task.arn
    }
  }
}



#------------------------------------------------------------------------------------
/*
resource "aws_lambda_function" "trigger_ecs_lambda" {
  // Lambda function configuration...
  environment {
    variables = {
      TF_VAR_ECS_CLUSTER_NAME    = aws_ecs_cluster.ecs_cluster.name
      TF_VAR_ECS_TASK_DEFINITION = aws_ecs_task_definition.ecs_task.arn
      TF_VAR_ECS_SUBNET_ID                = aws_subnet.ecs_subnet.id
      TF_VAR_ECS_SECURITY_GROUP_ID        = aws_security_group.ecs_sg.id
      TF_VAR_ECS_SUBNET_MAP_PUBLIC_IP     = tostring(aws_subnet.ecs_subnet.map_public_ip_on_launch)
    }
  }
}

// IAM role and policy for Lambda to interact with ECS and SQS
resource "aws_iam_role" "lambda_iam_role" {
  // IAM role configuration...
}

resource "aws_iam_role_policy" "lambda_policy" {
  // IAM policy allowing Lambda to start ECS task and read from SQS
}

resource "aws_sqs_queue" "ecs_queue" {
  // SQS queue configuration...
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.ecs_queue.arn
  function_name    = aws_lambda_function.trigger_ecs_lambda.arn
}
*/

#---------------------------------------------------------------------------------------------
#---- Print Output Values
#---------------------------------------------------------------------------------------------

output "staging_bucket_url" {value = aws_s3_bucket.staging_bucket.bucket_domain_name}
output "staging_bucket_arn" {value = aws_s3_bucket.staging_bucket.arn}
output "staging_bucket_name" {value = local.staging_bucket_name}
output ECS_CLUSTER_NAME {value = aws_ecs_cluster.ecs_cluster.name}
output ECS_TASK_DEFINITION {value = aws_ecs_task_definition.ecs_task.arn}
output ECS_SUBNET_ID {value = aws_subnet.ecs_subnet.id}
output ECS_SECURITY_GROUP_ID {value = aws_security_group.ecs_sg.id}
output ECS_SUBNET_MAP_PUBLIC_IP {value = aws_subnet.ecs_subnet.map_public_ip_on_launch}