output "orchestrator_agent_id" {
  value = aws_bedrockagent_agent.orchestrator.id
}

output "bootstrap_agent_id" {
  value = aws_bedrockagent_agent.bootstrap.id
}

output "compute_agent_id" {
  value = aws_bedrockagent_agent.compute.id
}

output "app_agent_id" {
  value = aws_bedrockagent_agent.app.id
}

output "api_gateway_url" {
  value = aws_apigatewayv2_stage.default.invoke_url
}

output "memory_table_name" {
  value = aws_dynamodb_table.memory.name
}

output "knowledge_base_bucket" {
  value = aws_s3_bucket.knowledge_base.id
}
