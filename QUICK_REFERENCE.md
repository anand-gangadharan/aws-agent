# Quick Reference Card

Essential commands for daily development.

## Initial Setup

```bash
# 1. Deploy infrastructure
cd terraform && terraform init && terraform apply

# 2. Upload knowledge base
cd .. && ./scripts/sync-knowledge-base.sh

# 3. Sync knowledge bases (AWS Console)
# Bedrock → Knowledge bases → Select each → Sync

# 4. Start MCP server
cd src/mcp_server && python http_server.py
```

## Testing

```bash
# Get API URL
API_URL=$(cd terraform && terraform output -raw api_gateway_url)

# Test agent
curl -X POST "$API_URL/chat" \
  -H "Content-Type: application/json" \
  -d '{"message": "Create bootstrap for dev"}' | jq

# Test MCP server
curl http://localhost:8000/health
```

## Updating

### Knowledge Base Changed
```bash
./scripts/sync-knowledge-base.sh
# Then sync in AWS Console (Bedrock → Knowledge bases → Sync)
# No restart needed
```

### Lambda Code Changed
```bash
cd terraform && terraform apply
# No restart needed
```

### MCP Server Changed
```bash
# Stop (Ctrl+C) and restart
cd src/mcp_server && python http_server.py
```

### Agent Instructions Changed
```bash
cd terraform && terraform apply
AGENT_ID=$(terraform output -raw orchestrator_agent_id)
aws bedrock-agent prepare-agent --agent-id $AGENT_ID
```

## CloudWatch Logs

```bash
# Lambda logs
aws logs tail /aws/lambda/cicd-agent-chat-handler --follow
aws logs tail /aws/lambda/cicd-agent-mcp-proxy --follow
aws logs tail /aws/lambda/cicd-agent-agent-invoker --follow
aws logs tail /aws/lambda/cicd-agent-memory-manager --follow

# Find errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/cicd-agent-mcp-proxy \
  --filter-pattern "ERROR"
```

## Debugging

```bash
# Check knowledge base sync
KB_ID=$(cd terraform && terraform output -raw orchestrator_kb_id)
aws bedrock-agent list-ingestion-jobs \
  --knowledge-base-id $KB_ID \
  --data-source-id $(aws bedrock-agent list-data-sources \
    --knowledge-base-id $KB_ID \
    --query 'dataSourceSummaries[0].dataSourceId' --output text)

# Check memory
TABLE_NAME=$(cd terraform && terraform output -raw memory_table_name)
aws dynamodb scan --table-name $TABLE_NAME

# Test Lambda directly
aws lambda invoke \
  --function-name cicd-agent-chat-handler \
  --payload '{"body": "{\"message\": \"Hello\"}"}' \
  response.json && cat response.json | jq

# Check agent status
AGENT_ID=$(cd terraform && terraform output -raw orchestrator_agent_id)
aws bedrock-agent get-agent --agent-id $AGENT_ID \
  | jq -r '.agent.agentStatus'
```

## Common Issues

### Model Access Denied
```bash
# Go to AWS Console → Bedrock → Model access
# Request: Amazon Nova Pro, Titan Embeddings v2
```

### Knowledge Base Not Working
```bash
# Re-sync
./scripts/sync-knowledge-base.sh
# Then sync in Console
```

### Lambda Timeout
```hcl
# In terraform/lambda.tf, increase timeout
timeout = 300  # 5 minutes
```

### Agent Changes Not Applied
```bash
# Prepare agent
aws bedrock-agent prepare-agent --agent-id $AGENT_ID
```

## Useful Outputs

```bash
cd terraform

# All outputs
terraform output

# Specific outputs
terraform output api_gateway_url
terraform output orchestrator_agent_id
terraform output knowledge_base_bucket
terraform output memory_table_name
```

## Clean Up

```bash
# Destroy everything
cd terraform && terraform destroy

# Or keep infrastructure, just clear memory
TABLE_NAME=$(terraform output -raw memory_table_name)
aws dynamodb scan --table-name $TABLE_NAME \
  --attributes-to-get session_id timestamp \
  | jq -r '.Items[] | "\(.session_id.S) \(.timestamp.N)"' \
  | while read sid ts; do
      aws dynamodb delete-item \
        --table-name $TABLE_NAME \
        --key "{\"session_id\":{\"S\":\"$sid\"},\"timestamp\":{\"N\":\"$ts\"}}"
    done
```

## File Locations

```
terraform/              # Infrastructure
src/lambda/            # Lambda functions
src/mcp_server/        # MCP server
knowledge_base/        # Documentation for RAG
scripts/               # Helper scripts
```

## Key Concepts

- **Agents**: Bedrock Agents with LLM brains (Nova Pro)
- **Knowledge Base**: S3 vector store with markdown docs
- **Memory**: DynamoDB for deployment history
- **MCP Server**: Executes actual pipelines (stubbed)
- **Lambdas**: Bridge between Bedrock and external systems

## Getting Help

- **Deployment**: See DEVELOPMENT_GUIDE.md
- **Architecture**: See ARCHITECTURE.md
- **Testing**: See QUICK_START.md
- **MCP Server**: See docs/mcp-architecture.md
- **Logs**: CloudWatch → `/aws/lambda/*` and `/aws/bedrock/agent/*`
