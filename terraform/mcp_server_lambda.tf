# Deploy MCP server as Lambda function for Bedrock Agent runtime
# This allows Bedrock Agents to invoke MCP tools directly

# Package MCP server code
data "archive_file" "mcp_server" {
  type        = "zip"
  source_dir  = "${path.module}/../src/mcp_server"
  output_path = "${path.module}/mcp_server.zip"
  
  excludes = [
    "__pycache__",
    "*.pyc",
    ".pytest_cache",
    "server.py"  # Exclude the stdio version, we use http_server.py
  ]
}

# Lambda function for MCP server
resource "aws_lambda_function" "mcp_server" {
  filename         = data.archive_file.mcp_server.output_path
  function_name    = "${var.project_name}-mcp-server"
  role            = aws_iam_role.mcp_server.arn
  handler         = "lambda_handler.handler"
  source_code_hash = data.archive_file.mcp_server.output_base64sha256
  runtime         = "python3.11"
  timeout         = 300
  memory_size     = 512

  environment {
    variables = {
      GITLAB_URL        = var.gitlab_url
      GITLAB_TOKEN      = var.gitlab_token
      GITLAB_PROJECT_ID = var.gitlab_project_id
      MEMORY_TABLE_NAME = aws_dynamodb_table.memory.name
    }
  }

  layers = [aws_lambda_layer_version.mcp_dependencies.arn]
}

# Lambda layer for MCP server dependencies
resource "aws_lambda_layer_version" "mcp_dependencies" {
  filename            = "${path.module}/mcp_layer.zip"
  layer_name          = "${var.project_name}-mcp-dependencies"
  compatible_runtimes = ["python3.11"]
  
  # This will be created by a script
  depends_on = [null_resource.build_mcp_layer]
}

# Build MCP dependencies layer
resource "null_resource" "build_mcp_layer" {
  triggers = {
    requirements = filemd5("${path.module}/../requirements.txt")
  }

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.module}/layer/python
      pip install -r ${path.module}/../requirements.txt -t ${path.module}/layer/python --upgrade
      cd ${path.module}/layer && zip -r ../mcp_layer.zip python
      rm -rf ${path.module}/layer
    EOT
  }
}

# IAM role for MCP server Lambda
resource "aws_iam_role" "mcp_server" {
  name = "${var.project_name}-mcp-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "mcp_server_basic" {
  role       = aws_iam_role.mcp_server.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "mcp_server" {
  name = "${var.project_name}-mcp-server-policy"
  role = aws_iam_role.mcp_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.memory.arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:gitlab-token-*"
      }
    ]
  })
}

# Allow Bedrock to invoke MCP server Lambda
resource "aws_lambda_permission" "bedrock_invoke_mcp" {
  statement_id  = "AllowBedrockInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mcp_server.function_name
  principal     = "bedrock.amazonaws.com"
}

# Output MCP server Lambda ARN
output "mcp_server_lambda_arn" {
  value       = aws_lambda_function.mcp_server.arn
  description = "ARN of MCP server Lambda function"
}

output "mcp_server_lambda_name" {
  value       = aws_lambda_function.mcp_server.function_name
  description = "Name of MCP server Lambda function"
}
