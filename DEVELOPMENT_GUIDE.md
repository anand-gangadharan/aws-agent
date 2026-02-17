# Development Guide

Complete guide for deploying, testing, updating, and debugging the AWS Bedrock Agent CICD solution.

## Table of Contents

1. [Initial Deployment](#initial-deployment)
2. [Testing the Agent](#testing-the-agent)
3. [Updating Components](#updating-components)
4. [CloudWatch Logs](#cloudwatch-logs)
5. [Debugging](#debugging)
6. [Common Issues](#common-issues)

---

## Initial Deployment

### Prerequisites

```bash
# Check prerequisites
python3 --version  # 3.11+
terraform --version  # 1.5+
aws --version  # AWS CLI configured

# Verify AWS credentials
aws sts get-caller-identity
```

### Step 1: Enable Bedrock Model Access

**IMPORTANT**: Do this BEFORE running terraform!

1. Go to AWS Console → Bedrock → Model access
2. Request access to:
   - ✅ Amazon Nova Pro (`us.amazon.nova-pro-v1:0`)
   - ✅ Amazon Titan Embeddings v2 (`amazon.titan-embed-text-v2:0`)
3. Wait for approval (usually instant)

### Step 2: Deploy Infrastructure

```bash
# Navigate to terraform directory
cd terraform

# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Deploy (takes 5-10 minutes)
terraform apply

# Save outputs for later use
terraform output > ../outputs.txt
```

**What gets created**:
- 4 Bedrock Agents (orchestrator, bootstrap, compute, app)
- 4 Knowledge Bases (S3 vector store)
- DynamoDB table (memory)
- 4 Lambda functions
- API Gateway
- S3 bucket for knowledge base
- IAM roles and policies

### Step 3: Upload Knowledge Base Documents

```bash
# Go back to project root
cd ..

# Run the sync script
chmod +x scripts/sync-knowledge-base.sh
./scripts/sync-knowledge-base.sh
```

**Or manually**:
```bash
# Get bucket name
cd terraform
KB_BUCKET=$(terraform output -raw knowledge_base_bucket)

# Upload files
cd ..
aws s3 sync knowledge_base/ s3://$KB_BUCKET/
```

### Step 4: Sync Knowledge Bases

**Option A: AWS Console (Recommended for first time)**

1. Go to AWS Console → Bedrock → Knowledge bases
2. For each knowledge base (orchestrator, bootstrap, compute, app):
   - Click on the knowledge base
   - Click "Sync" button
   - Wait for sync to complete (~1-2 minutes)

**Option B: AWS CLI**

```bash
cd terraform

# Get knowledge base IDs
ORCH_KB=$(terraform output -raw orchestrator_kb_id)
BOOT_KB=$(terraform output -raw bootstrap_kb_id)
COMP_KB=$(terraform output -raw compute_kb_id)
APP_KB=$(terraform output -raw app_kb_id)

# Sync each knowledge base
for KB_ID in $ORCH_KB $BOOT_KB $COMP_KB $APP_KB; do
    DATA_SOURCE_ID=$(aws bedrock-agent list-data-sources \
        --knowledge-base-id $KB_ID \
        --query 'dataSourceSummaries[0].dataSourceId' \
        --output text)
    
    aws bedrock-agent start-ingestion-job \
        --knowledge-base-id $KB_ID \
        --data-source-id $DATA_SOURCE_ID
    
    echo "Syncing KB: $KB_ID"
done
```

### Step 5: Start MCP Server (Local Testing)

```bash
# Install dependencies
pip install -r requirements.txt

# Start MCP server
cd src/mcp_server
python http_server.py

# Server runs on http://localhost:8000
# Keep this terminal open
```

**Note**: For production, deploy MCP server to ECS/Lambda (see Production Deployment section).

### Step 6: Verify Deployment

```bash
# Get API Gateway URL
cd terraform
API_URL=$(terraform output -raw api_gateway_url)

# Test health endpoint
curl $API_URL/health

# Test chat endpoint
curl -X POST "$API_URL/chat" \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello, can you help me?"}'
```

---

## Testing the Agent

### Test 1: Simple Query

```bash
API_URL=$(cd terraform && terraform output -raw api_gateway_url)

curl -X POST "$API_URL/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What pipelines do you support?"
  }' | jq
```

**Expected**: Agent describes bootstrap, compute, and app pipelines.

### Test 2: Bootstrap Pipeline

```bash
curl -X POST "$API_URL/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Create bootstrap infrastructure for dev environment"
  }' | jq
```

**Expected**: 
- Agent checks memory
- Invokes Bootstrap Agent
- Bootstrap Agent calls MCP tool
- Returns success message

### Test 3: Multi-Pipeline Request

```bash
curl -X POST "$API_URL/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Deploy a complete dev environment for tenant ABC"
  }' | jq
```

**Expected**:
- Agent orchestrates: Bootstrap → Compute → App
- Each agent invoked in sequence
- Returns comprehensive summary

### Test 4: Check Memory

```bash
curl -X POST "$API_URL/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What has been deployed in dev environment?"
  }' | jq
```

**Expected**: Agent queries memory and lists deployments.

### Test 5: Knowledge Base Query

```bash
curl -X POST "$API_URL/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What does the bootstrap pipeline create?"
  }' | jq
```

**Expected**: Agent searches knowledge base and describes VPC, subnets, etc.

### Test with Session Continuity

```bash
# First message
RESPONSE=$(curl -s -X POST "$API_URL/chat" \
  -H "Content-Type: application/json" \
  -d '{"message": "Create bootstrap for dev"}')

# Extract session ID
SESSION_ID=$(echo $RESPONSE | jq -r '.session_id')

# Follow-up message (uses same session)
curl -X POST "$API_URL/chat" \
  -H "Content-Type: application/json" \
  -d "{
    \"message\": \"Now add compute for tenant ABC\",
    \"session_id\": \"$SESSION_ID\"
  }" | jq
```

### Automated Test Script

```bash
#!/bin/bash
# test-agent.sh

API_URL=$(cd terraform && terraform output -raw api_gateway_url)

echo "Testing Agent..."
echo "================"

# Test 1: Health check
echo "1. Health check..."
curl -s $API_URL/health | jq

# Test 2: Simple query
echo "2. Simple query..."
curl -s -X POST "$API_URL/chat" \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello"}' | jq -r '.response'

# Test 3: Pipeline execution
echo "3. Pipeline execution..."
curl -s -X POST "$API_URL/chat" \
  -H "Content-Type: application/json" \
  -d '{"message": "Create bootstrap for dev"}' | jq -r '.response'

echo "================"
echo "Tests complete!"
```

---

## Updating Components

### When Knowledge Base Changes

**Scenario**: You updated markdown files in `knowledge_base/`

```bash
# 1. Upload updated files to S3
./scripts/sync-knowledge-base.sh

# 2. Sync knowledge bases (AWS Console or CLI)
# Via Console: Bedrock → Knowledge bases → Select KB → Sync

# Via CLI:
cd terraform
for KB_ID in $(terraform output -json | jq -r '.[] | select(.type == "string" and (.value | contains("kb-"))) | .value'); do
    DATA_SOURCE_ID=$(aws bedrock-agent list-data-sources \
        --knowledge-base-id $KB_ID \
        --query 'dataSourceSummaries[0].dataSourceId' \
        --output text)
    
    aws bedrock-agent start-ingestion-job \
        --knowledge-base-id $KB_ID \
        --data-source-id $DATA_SOURCE_ID
done

# 3. Test immediately (no agent restart needed)
curl -X POST "$API_URL/chat" \
  -H "Content-Type: application/json" \
  -d '{"message": "What does bootstrap create?"}' | jq
```

**Time to take effect**: 1-2 minutes (sync time)

**Agent restart needed**: ❌ No

### When Lambda Code Changes

**Scenario**: You updated `src/lambda/*.py`

```bash
# 1. Navigate to terraform directory
cd terraform

# 2. Terraform will detect changes and update Lambda
terraform apply

# 3. Test immediately
curl -X POST "$API_URL/chat" \
  -H "Content-Type: application/json" \
  -d '{"message": "Test"}' | jq
```

**Time to take effect**: Immediate (after terraform apply)

**Agent restart needed**: ❌ No (Lambda is stateless)

### When MCP Server Changes

**Scenario**: You updated `src/mcp_server/http_server.py`

**Local Development**:
```bash
# 1. Stop the running MCP server (Ctrl+C)

# 2. Restart it
cd src/mcp_server
python http_server.py

# 3. Test
curl http://localhost:8000/health
```

**Production (ECS)**:
```bash
# 1. Build new Docker image
docker build -t mcp-server:latest src/mcp_server/

# 2. Push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPO
docker tag mcp-server:latest $ECR_REPO/mcp-server:latest
docker push $ECR_REPO/mcp-server:latest

# 3. Update ECS service (forces new deployment)
aws ecs update-service \
    --cluster mcp-cluster \
    --service mcp-server \
    --force-new-deployment
```

**Time to take effect**: Immediate (local) or 2-3 minutes (ECS)

### When Agent Instructions Change

**Scenario**: You updated agent instructions in `terraform/bedrock_agents.tf`

```bash
# 1. Update the instruction text in bedrock_agents.tf

# 2. Apply changes
cd terraform
terraform apply

# 3. Prepare the agent (creates new version)
AGENT_ID=$(terraform output -raw orchestrator_agent_id)
aws bedrock-agent prepare-agent --agent-id $AGENT_ID

# 4. Test immediately
curl -X POST "$API_URL/chat" \
  -H "Content-Type: application/json" \
  -d '{"message": "Test new behavior"}' | jq
```

**Time to take effect**: 1-2 minutes (prepare-agent time)

**Agent restart needed**: ✅ Yes (prepare-agent)

### When Action Groups Change

**Scenario**: You updated action group schemas in `terraform/bedrock_action_groups.tf`

```bash
# 1. Update the OpenAPI schema

# 2. Apply changes
cd terraform
terraform apply

# 3. Prepare all affected agents
for AGENT_ID in $(terraform output -json | jq -r '.[] | select(.type == "string" and (.value | contains("agent-"))) | .value'); do
    aws bedrock-agent prepare-agent --agent-id $AGENT_ID
    echo "Prepared agent: $AGENT_ID"
done

# 4. Test
curl -X POST "$API_URL/chat" \
  -H "Content-Type: application/json" \
  -d '{"message": "Test"}' | jq
```

**Time to take effect**: 1-2 minutes per agent

### Quick Reference: What Needs Restart?

| Component | Change | Restart Needed | Command |
|-----------|--------|----------------|---------|
| Knowledge Base | Updated .md files | ❌ No | Sync KB |
| Lambda | Updated .py files | ❌ No | `terraform apply` |
| MCP Server | Updated http_server.py | ✅ Yes | Restart process |
| Agent Instructions | Updated instructions | ✅ Yes | `prepare-agent` |
| Action Groups | Updated schemas | ✅ Yes | `prepare-agent` |
| Infrastructure | Updated .tf files | ❌ No | `terraform apply` |

---

## CloudWatch Logs

### Where to Find Logs

#### 1. Lambda Function Logs

**Location**: CloudWatch → Log groups

```
/aws/lambda/cicd-agent-chat-handler
/aws/lambda/cicd-agent-agent-invoker
/aws/lambda/cicd-agent-mcp-proxy
/aws/lambda/cicd-agent-memory-manager
```

**View in Console**:
1. Go to CloudWatch → Log groups
2. Click on log group
3. Click on latest log stream
4. View logs

**View via CLI**:
```bash
# Get latest logs from chat handler
aws logs tail /aws/lambda/cicd-agent-chat-handler --follow

# Get logs from specific time
aws logs tail /aws/lambda/cicd-agent-mcp-proxy \
    --since 10m \
    --format short

# Search logs
aws logs filter-log-events \
    --log-group-name /aws/lambda/cicd-agent-mcp-proxy \
    --filter-pattern "ERROR"
```

#### 2. API Gateway Logs

**Location**: CloudWatch → Log groups

```
/aws/apigateway/cicd-agent-api
```

**Enable access logs** (if not already):
```bash
cd terraform

# Add to api_gateway.tf
resource "aws_apigatewayv2_stage" "default" {
  # ... existing config ...
  
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/cicd-agent-api"
  retention_in_days = 7
}
```

#### 3. Bedrock Agent Traces

**Location**: CloudWatch → Log groups

```
/aws/bedrock/agent/orchestrator
/aws/bedrock/agent/bootstrap
/aws/bedrock/agent/compute
/aws/bedrock/agent/app
```

**What you'll see**:
- Agent reasoning steps
- Knowledge base searches
- Action group invocations
- LLM prompts and responses

**Enable traces** (already enabled via `enableTrace=True` in code):
```python
# In agent_invoker.py
response = bedrock_agent_runtime.invoke_agent(
    agentId=agent_id,
    sessionId=session_id,
    inputText=instruction,
    enableTrace=True  # ← This enables CloudWatch traces
)
```

#### 4. MCP Server Logs

**Local Development**:
- Logs appear in terminal where you ran `python http_server.py`

**Production (ECS)**:
```
/aws/ecs/mcp-server
```

**View ECS logs**:
```bash
# Get task ID
TASK_ID=$(aws ecs list-tasks \
    --cluster mcp-cluster \
    --service-name mcp-server \
    --query 'taskArns[0]' \
    --output text | cut -d'/' -f3)

# View logs
aws logs tail /aws/ecs/mcp-server --follow
```

### Useful Log Queries

#### Find All Errors

```bash
# CloudWatch Insights query
aws logs start-query \
    --log-group-name /aws/lambda/cicd-agent-mcp-proxy \
    --start-time $(date -u -d '1 hour ago' +%s) \
    --end-time $(date -u +%s) \
    --query-string 'fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc'
```

#### Find Agent Invocations

```bash
aws logs filter-log-events \
    --log-group-name /aws/lambda/cicd-agent-agent-invoker \
    --filter-pattern "Invoking" \
    --start-time $(date -u -d '1 hour ago' +%s000)
```

#### Find Pipeline Executions

```bash
aws logs filter-log-events \
    --log-group-name /aws/lambda/cicd-agent-mcp-proxy \
    --filter-pattern "Executing MCP tool" \
    --start-time $(date -u -d '1 hour ago' +%s000)
```

#### CloudWatch Insights Queries

**Query 1: Request latency**
```
fields @timestamp, @duration
| filter @type = "REPORT"
| stats avg(@duration), max(@duration), min(@duration) by bin(5m)
```

**Query 2: Error rate**
```
fields @timestamp, @message
| filter @message like /ERROR/
| stats count() by bin(5m)
```

**Query 3: Agent invocations**
```
fields @timestamp, @message
| filter @message like /agent_type/
| parse @message "agent_type='*'" as agent
| stats count() by agent
```

---

## Debugging

### Debug Agent Reasoning

**Enable detailed traces**:

```python
# In agent_invoker.py, already enabled
response = bedrock_agent_runtime.invoke_agent(
    agentId=agent_id,
    sessionId=session_id,
    inputText=instruction,
    enableTrace=True  # ← Captures LLM reasoning
)

# Capture trace
for event in response.get('completion', []):
    if 'trace' in event:
        print(json.dumps(event['trace'], indent=2))
```

**View traces in CloudWatch**:
1. Go to CloudWatch → Log groups → `/aws/bedrock/agent/orchestrator`
2. Look for entries with `trace` in them
3. You'll see:
   - What the LLM is thinking
   - Which knowledge base searches it performed
   - Which action groups it decided to call
   - Why it made each decision

### Debug Knowledge Base

**Check if documents are uploaded**:
```bash
KB_BUCKET=$(cd terraform && terraform output -raw knowledge_base_bucket)
aws s3 ls s3://$KB_BUCKET/ --recursive
```

**Check sync status**:
```bash
KB_ID=$(cd terraform && terraform output -raw orchestrator_kb_id)
DATA_SOURCE_ID=$(aws bedrock-agent list-data-sources \
    --knowledge-base-id $KB_ID \
    --query 'dataSourceSummaries[0].dataSourceId' \
    --output text)

aws bedrock-agent list-ingestion-jobs \
    --knowledge-base-id $KB_ID \
    --data-source-id $DATA_SOURCE_ID
```

**Test knowledge base directly**:
```bash
aws bedrock-agent-runtime retrieve \
    --knowledge-base-id $KB_ID \
    --retrieval-query text="What does bootstrap create?"
```

### Debug Lambda Functions

**Test Lambda directly**:
```bash
# Test chat handler
aws lambda invoke \
    --function-name cicd-agent-chat-handler \
    --payload '{"body": "{\"message\": \"Hello\"}"}' \
    response.json

cat response.json | jq
```

**View recent errors**:
```bash
aws logs filter-log-events \
    --log-group-name /aws/lambda/cicd-agent-mcp-proxy \
    --filter-pattern "ERROR" \
    --start-time $(date -u -d '1 hour ago' +%s000) \
    | jq -r '.events[].message'
```

### Debug MCP Server

**Test MCP server directly**:
```bash
# Health check
curl http://localhost:8000/health

# Execute pipeline
curl -X POST http://localhost:8000/execute \
    -H "Content-Type: application/json" \
    -d '{
        "pipeline_type": "bootstrap",
        "environment": "dev",
        "parameters": {"region": "us-east-1"}
    }' | jq

# Check status
curl http://localhost:8000/status/execution-id | jq
```

**Check MCP server logs**:
- Local: Check terminal output
- ECS: `aws logs tail /aws/ecs/mcp-server --follow`

### Debug Memory (DynamoDB)

**Check what's in memory**:
```bash
TABLE_NAME=$(cd terraform && terraform output -raw memory_table_name)

# Scan all items
aws dynamodb scan --table-name $TABLE_NAME

# Query by environment
aws dynamodb query \
    --table-name $TABLE_NAME \
    --index-name environment-index \
    --key-condition-expression "environment = :env" \
    --expression-attribute-values '{":env":{"S":"dev"}}'
```

**Clear memory** (for testing):
```bash
# Delete all items (careful!)
aws dynamodb scan --table-name $TABLE_NAME \
    --attributes-to-get session_id timestamp \
    | jq -r '.Items[] | "\(.session_id.S) \(.timestamp.N)"' \
    | while read session_id timestamp; do
        aws dynamodb delete-item \
            --table-name $TABLE_NAME \
            --key "{\"session_id\":{\"S\":\"$session_id\"},\"timestamp\":{\"N\":\"$timestamp\"}}"
    done
```

---

## Common Issues

### Issue 1: "Model access denied"

**Symptom**: Error when invoking agent

**Solution**:
```bash
# Check model access
aws bedrock list-foundation-models \
    --by-provider amazon \
    --query 'modelSummaries[?modelId==`us.amazon.nova-pro-v1:0`]'

# If not accessible, go to Console → Bedrock → Model access → Request access
```

### Issue 2: Knowledge base not returning results

**Symptom**: Agent doesn't use knowledge base content

**Debug**:
```bash
# 1. Check if files are uploaded
aws s3 ls s3://$KB_BUCKET/orchestrator/

# 2. Check sync status
aws bedrock-agent list-ingestion-jobs \
    --knowledge-base-id $KB_ID \
    --data-source-id $DATA_SOURCE_ID

# 3. Test retrieval directly
aws bedrock-agent-runtime retrieve \
    --knowledge-base-id $KB_ID \
    --retrieval-query text="test query"
```

**Solution**: Re-sync knowledge base

### Issue 3: Lambda timeout

**Symptom**: Lambda times out after 3 seconds

**Solution**:
```hcl
# In terraform/lambda.tf, increase timeout
resource "aws_lambda_function" "mcp_proxy" {
  # ...
  timeout = 300  # 5 minutes
}
```

### Issue 4: MCP server not reachable

**Symptom**: Lambda can't reach MCP server

**Debug**:
```bash
# Check MCP_SERVER_URL environment variable
aws lambda get-function-configuration \
    --function-name cicd-agent-mcp-proxy \
    | jq -r '.Environment.Variables.MCP_SERVER_URL'
```

**Solution**: 
- Local: Make sure MCP server is running
- Production: Deploy MCP server to ECS/EC2 and update URL

### Issue 5: Agent not preparing

**Symptom**: Changes to agent don't take effect

**Solution**:
```bash
# Prepare the agent
AGENT_ID=$(cd terraform && terraform output -raw orchestrator_agent_id)
aws bedrock-agent prepare-agent --agent-id $AGENT_ID

# Wait for preparation to complete
aws bedrock-agent get-agent --agent-id $AGENT_ID \
    | jq -r '.agent.agentStatus'
# Should show "PREPARED"
```

---

## Quick Reference Commands

```bash
# Deploy
cd terraform && terraform apply

# Upload knowledge base
./scripts/sync-knowledge-base.sh

# Start MCP server
cd src/mcp_server && python http_server.py

# Test agent
API_URL=$(cd terraform && terraform output -raw api_gateway_url)
curl -X POST "$API_URL/chat" -H "Content-Type: application/json" -d '{"message": "Hello"}'

# View logs
aws logs tail /aws/lambda/cicd-agent-chat-handler --follow

# Update Lambda
cd terraform && terraform apply

# Update knowledge base
./scripts/sync-knowledge-base.sh

# Prepare agent
aws bedrock-agent prepare-agent --agent-id $AGENT_ID

# Check memory
aws dynamodb scan --table-name cicd-agent-memory
```

---

## Summary

- **Deploy**: `terraform apply` + sync knowledge base
- **Test**: Use curl or test script
- **Update KB**: Upload to S3 + sync (no restart)
- **Update Lambda**: `terraform apply` (no restart)
- **Update MCP**: Restart process/service
- **Update Agent**: `terraform apply` + `prepare-agent`
- **Logs**: CloudWatch → `/aws/lambda/*` and `/aws/bedrock/agent/*`
- **Debug**: Enable traces, check CloudWatch, test components individually

For detailed troubleshooting, check the logs in CloudWatch and use the debug commands above!
