# Lambda function for action groups
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../src/lambda"
  output_path = "${path.module}/lambda.zip"
}

# Lambda for orchestrator to invoke specialized agents
resource "aws_lambda_function" "agent_invoker" {
  filename         = data.archive_file.lambda.output_path
  function_name    = "${var.project_name}-agent-invoker"
  role            = aws_iam_role.lambda.arn
  handler         = "agent_invoker.handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime         = "python3.11"
  timeout         = 300

  environment {
    variables = {
      BOOTSTRAP_AGENT_ID = aws_bedrockagent_agent.bootstrap.id
      COMPUTE_AGENT_ID   = aws_bedrockagent_agent.compute.id
      APP_AGENT_ID       = aws_bedrockagent_agent.app.id
    }
  }
}

resource "aws_lambda_permission" "bedrock_invoke_agent_invoker" {
  statement_id  = "AllowBedrockInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.agent_invoker.function_name
  principal     = "bedrock.amazonaws.com"
}

# Lambda for MCP tool proxy (used by specialized agents)
resource "aws_lambda_function" "mcp_proxy" {
  filename         = data.archive_file.lambda.output_path
  function_name    = "${var.project_name}-mcp-proxy"
  role            = aws_iam_role.lambda.arn
  handler         = "mcp_proxy.handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime         = "python3.11"
  timeout         = 300

  environment {
    variables = {
      MEMORY_TABLE_NAME = aws_dynamodb_table.memory.name
      MCP_SERVER_URL    = "http://localhost:8000"
    }
  }
}

resource "aws_lambda_permission" "bedrock_invoke_mcp_proxy" {
  statement_id  = "AllowBedrockInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mcp_proxy.function_name
  principal     = "bedrock.amazonaws.com"
}

resource "aws_lambda_function" "memory_manager" {
  filename         = data.archive_file.lambda.output_path
  function_name    = "${var.project_name}-memory-manager"
  role            = aws_iam_role.lambda.arn
  handler         = "memory_manager.handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime         = "python3.11"
  timeout         = 30

  environment {
    variables = {
      MEMORY_TABLE_NAME = aws_dynamodb_table.memory.name
    }
  }
}

resource "aws_lambda_permission" "bedrock_invoke_memory" {
  statement_id  = "AllowBedrockInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.memory_manager.function_name
  principal     = "bedrock.amazonaws.com"
}

resource "aws_lambda_function" "chat_handler" {
  filename         = data.archive_file.lambda.output_path
  function_name    = "${var.project_name}-chat-handler"
  role            = aws_iam_role.lambda.arn
  handler         = "chat_handler.handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime         = "python3.11"
  timeout         = 60

  environment {
    variables = {
      ORCHESTRATOR_AGENT_ID = aws_bedrockagent_agent.orchestrator.id
      MEMORY_TABLE_NAME     = aws_dynamodb_table.memory.name
    }
  }
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chat_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
