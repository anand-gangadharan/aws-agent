# Quick Start Guide

## Understanding the Architecture (5 minutes)

This solution uses **LLM-driven orchestration** where AWS Bedrock Agents (powered by Claude 3 Sonnet) dynamically decide what to do based on:

1. **Natural language instructions** (in agent definitions)
2. **Knowledge base searches** (RAG - automatic)
3. **Deployment history** (memory queries)
4. **Available tools** (MCP server)

**No hardcoded routing** - the LLM orchestrates everything!

### Quick Concept Check

❌ **Traditional approach**:
```python
if request == "deploy app":
    if not bootstrap_exists():
        run_bootstrap()
    if not compute_exists():
        run_compute()
    run_app()
```

✅ **This solution**:
```
User: "Deploy MyApp to tenant ABC"
    ↓
Orchestrator LLM:
  - Searches knowledge base: "What's needed?"
  - Queries memory: "What exists?"
  - Decides: "Need compute first, then app"
  - Invokes Compute Agent LLM
    ↓
Compute Agent LLM:
  - Searches its knowledge base
  - Decides to call MCP tool
  - Executes pipeline
```

## Setup (15 minutes)

### 1. Prerequisites

```bash
# Check you have these installed
python3 --version  # 3.11+
terraform --version  # 1.5+
aws --version  # AWS CLI configured
```

### 2. Install Dependencies

```bash
# Clone/navigate to project
cd aws-bedrock-cicd-agent

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install Python packages
pip install -r requirements.txt
```

### 3. Configure AWS

```bash
# Ensure AWS credentials are configured
aws configure

# Enable Bedrock model access (one-time)
# Go to AWS Console → Bedrock → Model access
# Request access to: 
#   - Amazon Nova Pro
#   - Amazon Titan Embeddings v2
```

### 4. Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Deploy (takes ~10-15 minutes)
terraform apply

# Save the outputs
terraform output > ../outputs.txt
```

### 5. Upload Knowledge Base Documents

```bash
# Get the S3 bucket name from outputs
KB_BUCKET=$(terraform output -raw knowledge_base_bucket)

# Upload knowledge base documents
aws s3 sync ../knowledge_base/ s3://$KB_BUCKET/

# Trigger knowledge base sync (in AWS Console)
# Bedrock → Knowledge bases → Select each KB → Sync
```

### 6. Start MCP Server

```bash
cd ../src/mcp_server

# Start the HTTP server
python http_server.py

# Server runs on http://localhost:8000
# Keep this terminal open
```

### 7. Test the System

```bash
# In a new terminal
cd ../..

# Get API Gateway URL
API_URL=$(cd terraform && terraform output -raw api_gateway_url)

# Send a test request
curl -X POST "$API_URL/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Deploy a new dev environment for tenant ABC"
  }'
```

## Understanding the Response

The orchestrator LLM will:
1. Analyze your request
2. Search its knowledge base
3. Query memory (nothing exists yet)
4. Decide to run: Bootstrap → Compute → App
5. Invoke each agent in sequence
6. Return a comprehensive summary

Example response:
```json
{
  "response": "I've successfully set up a new dev environment for tenant ABC.\n\nHere's what I did:\n✓ Created bootstrap infrastructure (VPC vpc-123)\n✓ Provisioned compute resources (2 EC2 instances)\n✓ Deployed default applications\n\nAll systems are operational.",
  "session_id": "session-abc-123"
}
```

## Key Files to Understand

### 1. Agent Definitions (The Brains)
**File**: `terraform/bedrock_agents.tf`

This defines the 4 LLM agents and their instructions. The instructions guide how each LLM reasons.

### 2. Knowledge Bases (The Context)
**Files**: `knowledge_base/orchestrator/`, `knowledge_base/bootstrap/`, etc.

These markdown files are automatically searched by LLMs via RAG to get context.

### 3. Action Groups (The Tools)
**File**: `terraform/bedrock_action_groups.tf`

Defines tools that LLMs can call. LLMs read the OpenAPI descriptions and decide when to use each tool.

### 4. Agent Invocation (LLM-to-LLM)
**File**: `src/lambda/agent_invoker.py`

Enables the orchestrator LLM to invoke specialized agents. Pure natural language communication.

### 5. MCP Tools (Pipeline Execution)
**File**: `src/mcp_server/http_server.py`

The actual pipeline execution runtime. Called when an agent's LLM decides to execute a pipeline.

## Example Interactions

### Deploy to New Tenant
```bash
curl -X POST "$API_URL/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "I need compute resources for tenant XYZ in prod"
  }'
```

**What happens**:
- Orchestrator LLM checks memory
- Sees bootstrap exists for prod
- Invokes only Compute Agent
- Skips Bootstrap (smart!)

### Deploy Application
```bash
curl -X POST "$API_URL/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Deploy MyApp version 2.0 to tenant ABC in dev"
  }'
```

**What happens**:
- Orchestrator LLM checks memory
- Sees bootstrap and compute exist
- Invokes only App Agent
- Skips Bootstrap and Compute (smart!)

### Complex Request
```bash
curl -X POST "$API_URL/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Set up prod environment for tenants ABC and XYZ, deploy MyApp to both"
  }'
```

**What happens**:
- Orchestrator LLM parses complex request
- Checks memory for prod bootstrap
- Plans: Bootstrap → Compute(ABC) → Compute(XYZ) → App(ABC) → App(XYZ)
- Executes in correct order
- Coordinates entire workflow

## Debugging

### Enable Trace
The agent invocations include `enableTrace=True` which provides detailed logs of:
- What the LLM is thinking
- Which knowledge base searches it performed
- Which tools it decided to call
- Why it made each decision

Check CloudWatch Logs for the Lambda functions.

### Check Knowledge Base
Verify documents are uploaded:
```bash
aws s3 ls s3://$KB_BUCKET/ --recursive
```

### Check Memory
Query DynamoDB to see deployment history:
```bash
aws dynamodb scan --table-name cicd-agent-memory
```

### Test MCP Server
```bash
curl http://localhost:8000/health
```

## Next Steps

1. **Read the docs**: Start with `docs/answering-your-question.md`
2. **Modify agent instructions**: Edit `terraform/bedrock_agents.tf`
3. **Add knowledge**: Update files in `knowledge_base/`
4. **Add tools**: Extend `terraform/bedrock_action_groups.tf`
5. **Customize pipelines**: Modify `src/mcp_server/http_server.py`

## Common Issues

### "Model access denied"
- Go to AWS Console → Bedrock → Model access
- Request access to Amazon Nova Pro and Titan Embeddings v2
- Wait for approval (usually instant)

### "Knowledge base not found"
- Ensure you synced the knowledge bases after uploading to S3
- Go to Bedrock → Knowledge bases → Sync

### "MCP server connection refused"
- Ensure `http_server.py` is running
- Check it's on port 8000
- Update `MCP_SERVER_URL` in Lambda environment variables if needed

### "Agent not responding"
- Check CloudWatch Logs for the Lambda functions
- Look for trace information showing LLM reasoning
- Verify IAM permissions are correct

## Cost Estimate (POC)

- **Bedrock Agents (Nova Pro)**: ~$0.0008 per 1000 input tokens, ~$0.0032 per 1000 output tokens
- **Titan Embeddings v2**: ~$0.0001 per 1000 tokens
- **S3**: Negligible for knowledge base docs and vectors
- **DynamoDB**: Pay per request (minimal for POC)
- **Lambda**: Pay per invocation (minimal for POC)

**Estimated POC cost**: $2-5/day with moderate testing (much cheaper than OpenSearch Serverless!)

## Production Considerations

For production use, consider:
1. **Authentication**: Add Cognito or API keys to API Gateway
2. **MCP Server**: Deploy as Lambda or ECS instead of localhost
3. **Monitoring**: Add CloudWatch dashboards and alarms
4. **Guardrails**: Enhance with more sophisticated policies
5. **Knowledge Base**: Add more comprehensive documentation
6. **Agent Aliases**: Use versioned aliases instead of DRAFT
7. **Error Handling**: Add retry logic and error recovery
8. **Testing**: Add integration tests for agent workflows

## Getting Help

- **Architecture questions**: Read `ARCHITECTURE.md`
- **Component details**: Read `docs/component-mapping.md`
- **Example walkthrough**: Read `docs/example-interaction.md`
- **LLM orchestration**: Read `docs/answering-your-question.md`

## Success Criteria

You'll know it's working when:
1. ✅ You send a natural language request
2. ✅ The orchestrator LLM analyzes it
3. ✅ It queries memory and knowledge bases
4. ✅ It invokes the right agents in the right order
5. ✅ Pipelines execute successfully
6. ✅ You get a comprehensive natural language response

**The key indicator**: The LLM makes different decisions based on what's already deployed (memory) without any code changes!
