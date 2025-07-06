provider "aws" {
  region = "us-east-1"
}

# ================================
# 🔐 IAM Role
# ================================
data "aws_iam_role" "existing" {
  name = "LabRole"
}

# ================================
# 🗃️ DynamoDB Table
# ================================
resource "aws_dynamodb_table" "notes_table" {
  name         = "NotesTable"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"
  range_key    = "noteId"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "noteId"
    type = "S"
  }

  tags = {
    Environment = "Dev"
    Project     = "NoteTakingApp"
  }
}
# ================================
# 🪣 S3 Bucket for Image Uploads
# ================================
resource "aws_s3_bucket" "note_images" {
  bucket = "note-app-images-sajid12345"

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }

  tags = {
    Environment = "Dev"
    Project     = "NoteTakingApp"
  }
}

resource "aws_s3_bucket_ownership_controls" "note_images" {
  bucket = aws_s3_bucket.note_images.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "note_images_block" {
  bucket = aws_s3_bucket.note_images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}




# ================================
# ⚙️ Lambda Function
# ================================
resource "aws_lambda_function" "note_lambda" {
  function_name    = "note-taking-lambda"
  handler          = "handler.handler"
  runtime          = "nodejs18.x"
  role             = "arn:aws:iam::119537643270:role/LabRole"
  filename         = "./lambda.zip"
  source_code_hash = filebase64sha256("./lambda.zip")
  timeout          = 10

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.note_images.bucket
    }
  }
}

# ================================
# 🌐 API Gateway
# ================================
resource "aws_api_gateway_rest_api" "api" {
  name = "note-api"
}

resource "aws_api_gateway_resource" "notes" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "notes"
}

resource "aws_api_gateway_method" "any_notes" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.notes.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_notes" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.notes.id
  http_method             = aws_api_gateway_method.any_notes.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.note_lambda.invoke_arn
}

resource "aws_api_gateway_method" "options_notes" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.notes.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_notes_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.notes.id
  http_method             = aws_api_gateway_method.options_notes.http_method
  type                    = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_notes_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.notes.id
  http_method = aws_api_gateway_method.options_notes.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "options_notes_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.notes.id
  http_method = aws_api_gateway_method.options_notes.http_method
  status_code = aws_api_gateway_method_response.options_notes_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = ""
  }
}

resource "aws_api_gateway_resource" "notes_proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.notes.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "any_notes_proxy" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.notes_proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_notes_proxy" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.notes_proxy.id
  http_method             = aws_api_gateway_method.any_notes_proxy.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.note_lambda.invoke_arn
}

resource "aws_api_gateway_method" "options_notes_proxy" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.notes_proxy.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_notes_proxy_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.notes_proxy.id
  http_method             = aws_api_gateway_method.options_notes_proxy.http_method
  type                    = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_notes_proxy_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.notes_proxy.id
  http_method = aws_api_gateway_method.options_notes_proxy.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "options_notes_proxy_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.notes_proxy.id
  http_method = aws_api_gateway_method.options_notes_proxy.http_method
  status_code = aws_api_gateway_method_response.options_notes_proxy_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = ""
  }
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.note_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "api_deploy" {
  depends_on = [
    aws_api_gateway_integration.lambda_notes,
    aws_api_gateway_integration.options_notes_integration,
    aws_api_gateway_integration.lambda_notes_proxy,
    aws_api_gateway_integration.options_notes_proxy_integration
  ]
  rest_api_id = aws_api_gateway_rest_api.api.id
}

resource "aws_api_gateway_stage" "prod_stage" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.api_deploy.id
}


# ================================
# 📈 CloudWatch + 🔔 SNS
# ================================
resource "aws_cloudwatch_log_metric_filter" "lambda_error_filter" {
  name           = "lambda-error-metric"
  log_group_name = "/aws/lambda/${aws_lambda_function.note_lambda.function_name}"
  pattern        = "ERROR"

  metric_transformation {
    name      = "LambdaErrorCount"
    namespace = "MyApp/Metrics"
    value     = "1"
  }
}

resource "aws_sns_topic" "error_topic" {
  name = "lambda-error-topic"
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.error_topic.arn
  protocol  = "email"
  endpoint  = "sajid3krahman@gmail.com"
}

resource "aws_cloudwatch_metric_alarm" "lambda_error_alarm" {
  alarm_name          = "lambda-error-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.lambda_error_filter.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.lambda_error_filter.metric_transformation[0].namespace
  period              = 60
  statistic           = "Sum"
  threshold           = 1

  alarm_description   = "Triggers when there is at least one ERROR in logs."
  alarm_actions       = [aws_sns_topic.error_topic.arn]
  ok_actions          = [aws_sns_topic.error_topic.arn]
}


# ================================
# 🔐 EC2 Key Pair
# ================================
resource "aws_key_pair" "frontend_key" {
  key_name   = "frontend-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# ================================
# 🔒 Security Group for EC2
# ================================
resource "aws_security_group" "frontend_sg" {
  name        = "frontend-sg"
  description = "Allow HTTP and SSH"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow React development server"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ================================
# 🖥️ EC2 Instance to host frontend
# ================================
resource "aws_instance" "frontend_vm" {
  ami                    = "ami-0c02fb55956c7d316"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.frontend_key.key_name
  security_groups        = [aws_security_group.frontend_sg.name]
  user_data = <<-EOF
#!/bin/bash

# Update and install required packages
yum update -y
yum install -y git curl gcc-c++ make

# Switch to ec2-user and run the setup
su - ec2-user -c "
  # Install NVM and Node.js
  echo ' Loading NVM...'
  export NVM_DIR=\"/home/ec2-user/.nvm\"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  source \$NVM_DIR/nvm.sh
  export PATH=\$NVM_DIR/versions/node/v16.*/bin:\$PATH
  nvm install 16
  nvm use 16

  echo ' Cloning frontend repo...'

  git clone https://github.com/Sajidrahman-tech/note-frontend.git /home/ec2-user/note-frontend
  cd /home/ec2-user/note-frontend

  # Inject API URL into .env
  echo ' Injecting API URL into .env...'
  echo 'REACT_APP_API_BASE=https://${aws_api_gateway_rest_api.api.id}.execute-api.us-east-1.amazonaws.com/${aws_api_gateway_stage.prod_stage.stage_name}/notes' > /home/ec2-user/note-frontend/.env

  echo ' Installing npm dependencies...'
  npm install

  nohup npm start > app.log 2>&1 &
  echo ' App started and running in background'
"
EOF

  tags = {
    Name = "React-Frontend-EC2"
  }
}


# ================================
# 📤 Outputs
# ================================
output "api_url" {
  value = "https://${aws_api_gateway_rest_api.api.id}.execute-api.us-east-1.amazonaws.com/${aws_api_gateway_stage.prod_stage.stage_name}/notes"
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.notes_table.name
}

output "s3_bucket_name" {
  value = aws_s3_bucket.note_images.bucket
}

output "s3_bucket_url" {
  value = "https://${aws_s3_bucket.note_images.bucket}.s3.amazonaws.com"
}


output "sns_topic_arn" {
  value = aws_sns_topic.error_topic.arn
}

output "cloudwatch_alarm_name" {
  value = aws_cloudwatch_metric_alarm.lambda_error_alarm.alarm_name
}



output "frontend_app_url" {
  value = "http://${aws_instance.frontend_vm.public_ip}"
}
