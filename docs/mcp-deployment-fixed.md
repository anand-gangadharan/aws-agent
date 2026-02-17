# MCP Server Deployment - FIXED

## Problem Identified

The original Terraform configuration had a **critical flaw**:
- MCP server was NOT deployed
- `MCP_SERVER_URL` was hardcoded to `http://localhost:8000`
- Lambda couldn't reach localhost
- MCP server only worked for local development

## Solution Implemented

Deploy MCP server as a **Lambda function** that Bedrock Agents can invoke directly.

## New Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Bedrock Agent (LLM)                           │
│  Decides to execute bootstrap pipeline                          │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ Calls action group: execute-bootstrap-pipeline
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│              Lambda: mcp_proxy.py                                │
│  • Receives action group invocation                             │
│  • Extracts parameters from agent                               │
│  • Invokes MCP server Lambda (NOT HTTP!)                        │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ lambda_client.invoke()
                         │ FunctionName: cicd-agent-mcp-server
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│              Lambda: mcp_server (NEW!)                           │
│  • Receives pipeline execution request                          │
│  • Logs parameters identified by agent                          │
│  • Calls GitLab API (STUBBED)                                   │
│  • Stores result in DynamoDB                                    │
│  • Returns execution details                                    │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ (STUBBED - Should call GitLab)
                         ▼
                    GitLab CI/CD
```

## What Changed

### 1. New Terraform File: `mcp_server_lambda.tf`

**Creates**:
- Lambda function for MCP server
- Lambda layer for dependencies (FastAPI, etc.)
- IAM role with permissions
- Outputs for Lambda ARN and name

**Key features**:
- Timeout: 300 seconds (5 minutes)
- Memory: 512 MB
- Runtime: Python 3.11
- Environment variables: GitLab config, DynamoDB table

### 2. New Lambda Handler: `src/mcp_server/lambda_handler.py`

**Handles**:
- Bedrock Agent invocations (action groups)
- Direct Lambda invocations
- API Gateway invocations (for testing)

**Functions**:
- `execute_pipeline()` - Execute GitLab pipeline (stubbed)
- `get_status()` - Check pipeline status
- `store_in_dynamodb()` - Store execution in memory

### 3. Updated: `src/lambda/mcp_proxy.py`

**Changed from**:
```python
# OLD: HTTP call (doesn't work)
response = requests.post(
    f"{mcp_server_url}/execute",
    json={...}
)
```

**Changed to**:
```python
# NEW: Lambda invocation (works!)
response = lambda_client.invoke(
    FunctionName=mcp_server_function,
    InvocationType='RequestResponse',
    Payload=json.dumps({...})
)
```

### 4. Updated: `terraform/lambda.tf`

**Changed from**:
```hcl
environment {
  variables = {
    MCP_SERVER_URL = "http://localhost:8000"  # ❌ Doesn't work
  }
}
```

**Changed to**:
```hcl
environment {
  variables = {
    MCP_SERVER_FUNCTION_NAME = aws_lambda_function.mcp_server.function_name  # ✅ Works!
  }
}
```

### 5. Updated: `terraform/iam.tf`

**Added permission**:
```hcl
{
  Effect = "Allow"
  Action = ["lambda:InvokeFunction"]
  Resource = "arn:aws:lambda:...:function:cicd-agent-mcp-server"
}
```

### 6. Updated: `terraform/variables.tf`

**Added GitLab configuration**:
```hcl
variable "gitlab_url" {
  default = "https://gitlab.com"
}

variable "gitlab_token" {
  default = "STUB_TOKEN"  # Change for real integration
  sensitive = true
}

variable "gitlab_project_id" {
  default = "STUB_PROJECT_ID"  # Change for real integration
}
```

## How It Works Now

### 1. Deployment

```bash
cd terraform

# Deploy everything including MCP server Lambda
terraform apply

# MCP server is now deployed as Lambda function
# No need to run http_server.py locally!
```

### 2. Agent Invokes MCP Tool

```
1. Bootstrap Agent LLM decides: "Execute bootstrap pipeline"
2. Calls action group: execute-bootstrap-pipeline
3. Bedrock invokes: mcp_proxy Lambda
4. mcp_proxy invokes: mcp_server Lambda
5. mcp_server executes pipeline (stubbed)
6. Result flows back to agent
```

### 3. Testing

```bash
# Test via agent (end-to-end)
API_URL=$(terraform output -raw api_gateway_url)
curl -X POST "$API_URL/chat" \
  -H "Content-Type: application/json" \
  -d '{"message": "Create bootstrap for dev"}' | jq

# Test MCP server Lambda directly
aws lambda invoke \
  --function-name cicd-agent-mcp-server \
  --payload '{"action":"execute","pipeline_type":"bootstrap","environment":"dev"}' \
  response.json

cat response.json | jq
```

### 4. Logs

**MCP server logs**:
```bash
aws logs tail /aws/lambda/cicd-agent-mcp-server --follow
```

You'll see:
```
================================================================================
PIPELINE EXECUTION REQUEST
================================================================================
Execution ID: abc-123-def-456
Pipeline Type: bootstrap
Environment: dev
Parameters: {'region': 'us-east-1'}
================================================================================
GitLab Pipeline Variables:
  PIPELINE_TYPE: bootstrap
  ENVIRONMENT: dev
  AWS_REGION: us-east-1
================================================================================
STUBBED GITLAB API CALL
Would trigger GitLab pipeline with variables...
================================================================================
```

## Benefits of Lambda Deployment

### ✅ Advantages

1. **Actually works** - No localhost issues
2. **Integrated with Bedrock** - Direct Lambda invocation
3. **Scalable** - Lambda auto-scales
4. **Cost-effective** - Pay per invocation
5. **No server management** - Fully serverless
6. **CloudWatch logs** - Built-in logging
7. **IAM security** - Proper permissions

### ❌ Previous Issues (Fixed)

1. ~~MCP server not deployed~~ → Now deployed as Lambda
2. ~~localhost URL doesn't work~~ → Now uses Lambda invoke
3. ~~Manual server startup~~ → Automatic with terraform
4. ~~No logs in CloudWatch~~ → Now has dedicated log group
5. ~~Not integrated with Bedrock~~ → Fully integrated

## Integrating with Real GitLab

### Step 1: Set GitLab Variables

```bash
# Create terraform.tfvars
cat > terraform/terraform.tfvars <<EOF
gitlab_url        = "https://gitlab.com"
gitlab_token      = "glpat-your-actual-token"
gitlab_project_id = "12345"
EOF
```

### Step 2: Update Lambda Handler

In `src/mcp_server/lambda_handler.py`, replace `trigger_gitlab_pipeline_stub()` with real implementation:

```python
def trigger_gitlab_pipeline(pipeline_type, variables):
    """Trigger real GitLab pipeline"""
    import requests
    
    gitlab_url = os.environ['GITLAB_URL']
    gitlab_token = os.environ['GITLAB_TOKEN']
    project_id = os.environ['GITLAB_PROJECT_ID']
    
    response = requests.post(
        f"{gitlab_url}/api/v4/projects/{project_id}/pipeline",
        headers={"PRIVATE-TOKEN": gitlab_token},
        json={
            "ref": "main",
            "variables": [
                {"key": k, "value": v} for k, v in variables.items()
            ]
        }
    )
    
    response.raise_for_status()
    return response.json()["id"]
```

### Step 3: Deploy

```bash
cd terraform
terraform apply
```

## Comparison: Before vs After

### Before (Broken)

```
Agent → mcp_proxy → HTTP POST to localhost:8000 → ❌ FAILS
                    (Lambda can't reach localhost)
```

### After (Fixed)

```
Agent → mcp_proxy → Lambda invoke → mcp_server Lambda → ✅ WORKS
                    (Direct Lambda-to-Lambda)
```

## Testing the Fix

### 1. Deploy

```bash
cd terraform
terraform init
terraform apply
```

### 2. Verify MCP Server Lambda Exists

```bash
aws lambda get-function --function-name cicd-agent-mcp-server
```

### 3. Test MCP Server Directly

```bash
aws lambda invoke \
  --function-name cicd-agent-mcp-server \
  --payload '{
    "action": "execute",
    "pipeline_type": "bootstrap",
    "environment": "dev",
    "region": "us-east-1"
  }' \
  response.json

cat response.json | jq
```

### 4. Test End-to-End

```bash
API_URL=$(cd terraform && terraform output -raw api_gateway_url)

curl -X POST "$API_URL/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Create bootstrap infrastructure for dev environment"
  }' | jq
```

### 5. Check Logs

```bash
# MCP server logs
aws logs tail /aws/lambda/cicd-agent-mcp-server --follow

# mcp_proxy logs
aws logs tail /aws/lambda/cicd-agent-mcp-proxy --follow
```

## Migration from Old Setup

If you already deployed the old version:

```bash
cd terraform

# Remove old resources (if any)
# The new terraform will create mcp_server Lambda

# Apply new configuration
terraform apply

# No need to run http_server.py anymore!
```

## Summary

### What Was Wrong
- MCP server not deployed
- localhost URL doesn't work from Lambda
- Manual server startup required

### What's Fixed
- ✅ MCP server deployed as Lambda
- ✅ Direct Lambda-to-Lambda invocation
- ✅ Fully automated deployment
- ✅ Integrated with Bedrock Agents
- ✅ CloudWatch logs
- ✅ Scalable and cost-effective

### How to Use
1. `terraform apply` - Deploys everything including MCP server
2. Test via agent - MCP server Lambda is invoked automatically
3. Check logs - `/aws/lambda/cicd-agent-mcp-server`
4. Integrate GitLab - Update variables and Lambda handler

The MCP server is now properly deployed and integrated with Bedrock Agents!
