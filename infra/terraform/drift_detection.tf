# Drift Detection Configuration

# Create an SNS topic for drift notifications
resource "aws_sns_topic" "drift_notifications" {
  name = "${var.project}-drift-notifications-${var.environment}"
  
  tags = {
    Name        = "${var.project}-drift-notifications-${var.environment}"
    Environment = var.environment
    Project     = var.project
  }
}

# Create an SNS subscription for email notifications
resource "aws_sns_topic_subscription" "drift_email_subscription" {
  topic_arn = aws_sns_topic.drift_notifications.arn
  protocol  = "email"
  endpoint  = var.drift_notification_email
}

# Create a Lambda function for drift detection
data "archive_file" "drift_detection_lambda" {
  type        = "zip"
  output_path = "${path.module}/drift_detection_lambda.zip"

  source {
    content  = <<-EOT
    import json
    import boto3
    import os
    import subprocess
    import tempfile
    import urllib.parse

    def lambda_handler(event, context):
        # Initialize clients
        sns = boto3.client('sns')
        s3 = boto3.client('s3')
        
        # Get environment variables
        sns_topic_arn = os.environ['SNS_TOPIC_ARN']
        s3_bucket = os.environ['S3_BUCKET']
        s3_key = os.environ['S3_KEY']
        approval_url = os.environ.get('APPROVAL_URL', 'https://example.com/approve')
        reject_url = os.environ.get('REJECT_URL', 'https://example.com/reject')
        
        # Create a temporary directory for Terraform files
        with tempfile.TemporaryDirectory() as temp_dir:
            # Download Terraform state from S3
            state_file_path = os.path.join(temp_dir, 'terraform.tfstate')
            s3.download_file(s3_bucket, s3_key, state_file_path)
            
            # Change to the temp directory
            os.chdir(temp_dir)
            
            # Create a basic Terraform configuration file
            with open('main.tf', 'w') as f:
                f.write('''
                terraform {
                  required_providers {
                    aws = {
                      source  = "hashicorp/aws"
                      version = "~> 4.0"
                    }
                  }
                }
                
                provider "aws" {
                  region = "us-east-1"
                }
                ''')
            
            # Initialize Terraform
            subprocess.run(['terraform', 'init'], check=True, capture_output=True)
            
            # Run terraform plan to detect drift
            result = subprocess.run(
                ['terraform', 'plan', '-detailed-exitcode', '-no-color'],
                capture_output=True,
                text=True
            )
            
            # Check if drift was detected (exit code 2)
            if result.returncode == 2:
                # Drift detected
                plan_output = result.stdout
                
                # Create approval/reject URLs with plan output as parameter
                encoded_plan = urllib.parse.quote_plus(plan_output)
                approve_link = f"{approval_url}?plan={encoded_plan}"
                reject_link = f"{reject_url}?plan={encoded_plan}"
                
                # Create email message
                subject = "Terraform Drift Detected - Manual Approval Required"
                message = f"""
                Terraform drift has been detected in your infrastructure.
                
                Plan Output:
                {plan_output}
                
                Please review the changes and take action:
                
                Approve Changes: {approve_link}
                Reject Changes: {reject_link}
                
                The CI/CD pipeline will wait for your approval before proceeding.
                """
                
                # Send notification
                sns.publish(
                    TopicArn=sns_topic_arn,
                    Subject=subject,
                    Message=message
                )
                
                return {
                    'statusCode': 200,
                    'body': json.dumps('Drift detected and notification sent')
                }
            else:
                # No drift detected
                return {
                    'statusCode': 200,
                    'body': json.dumps('No drift detected')
                }
    EOT
    filename = "lambda_function.py"
  }
}

# Create IAM role for the Lambda function
resource "aws_iam_role" "drift_detection_lambda_role" {
  name = "${var.project}-drift-detection-lambda-role-${var.environment}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name        = "${var.project}-drift-detection-lambda-role-${var.environment}"
    Environment = var.environment
    Project     = var.project
  }
}

# Create IAM policy for the Lambda function
resource "aws_iam_policy" "drift_detection_lambda_policy" {
  name        = "${var.project}-drift-detection-lambda-policy-${var.environment}"
  description = "Policy for drift detection Lambda function"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.terraform_state.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.drift_notifications.arn
      }
    ]
  })
  
  tags = {
    Name        = "${var.project}-drift-detection-lambda-policy-${var.environment}"
    Environment = var.environment
    Project     = var.project
  }
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "drift_detection_lambda_policy_attachment" {
  role       = aws_iam_role.drift_detection_lambda_role.name
  policy_arn = aws_iam_policy.drift_detection_lambda_policy.arn
}

# Create the Lambda function
resource "aws_lambda_function" "drift_detection" {
  filename         = data.archive_file.drift_detection_lambda.output_path
  function_name    = "${var.project}-drift-detection-${var.environment}"
  role            = aws_iam_role.drift_detection_lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  source_code_hash = data.archive_file.drift_detection_lambda.output_base64sha256
  
  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.drift_notifications.arn
      S3_BUCKET     = aws_s3_bucket.terraform_state.bucket
      S3_KEY        = "terraform.tfstate"
      APPROVAL_URL  = "https://todoforge.mooo.com/approve"  # Replace with your actual approval endpoint
      REJECT_URL    = "https://todoforge.mooo.com/reject"   # Replace with your actual reject endpoint
    }
  }
  
  tags = {
    Name        = "${var.project}-drift-detection-${var.environment}"
    Environment = var.environment
    Project     = var.project
  }
}

# Create CloudWatch Events rule to run drift detection periodically
resource "aws_cloudwatch_event_rule" "drift_detection_schedule" {
  name                = "${var.project}-drift-detection-schedule-${var.environment}"
  description         = "Schedule for drift detection"
  schedule_expression = "rate(24 hours)"  # Run daily
  
  tags = {
    Name        = "${var.project}-drift-detection-schedule-${var.environment}"
    Environment = var.environment
    Project     = var.project
  }
}

# Create CloudWatch Events target to invoke the Lambda function
resource "aws_cloudwatch_event_target" "drift_detection_target" {
  rule      = aws_cloudwatch_event_rule.drift_detection_schedule.name
  target_id = "DriftDetectionLambda"
  arn       = aws_lambda_function.drift_detection.arn
}

# Create permission for CloudWatch Events to invoke the Lambda function
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.drift_detection.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.drift_detection_schedule.arn
}

# Add drift notification email variable
variable "drift_notification_email" {
  description = "Email address to send drift notifications to"
  type        = string
  default     = "devops@example.com"  # Replace with your email
}