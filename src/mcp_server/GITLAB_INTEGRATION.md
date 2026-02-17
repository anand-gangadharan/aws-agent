# GitLab CI/CD Integration Guide

## Current Status

The MCP server is **STUBBED** - it logs parameters but doesn't call real GitLab APIs.

When you run it, you'll see logs like:

```
================================================================================
PIPELINE EXECUTION REQUEST
================================================================================
Execution ID: abc-123-def-456
Pipeline Type: bootstrap
Environment: dev
Tenant ID: ABC
Parameters: {'region': 'us-east-1'}
================================================================================
GitLab Pipeline Variables:
  PIPELINE_TYPE: bootstrap
  ENVIRONMENT: dev
  EXECUTION_ID: abc-123-def-456
  AWS_REGION: us-east-1
================================================================================
STUBBED GITLAB API CALL
================================================================================
This is a stub. In production, this would call:
POST https://gitlab.com/api/v4/projects/12345/pipeline
Headers: PRIVATE-TOKEN: glpat-xxxx...
Body:
  ref: main
  variables:
    - PIPELINE_TYPE: bootstrap
    - ENVIRONMENT: dev
    - AWS_REGION: us-east-1
================================================================================
Returning fake pipeline ID: stub-a1b2c3d4
================================================================================
```

## How to Integrate with Real GitLab

### Step 1: Set Environment Variables

```bash
export GITLAB_URL="https://gitlab.com"  # or your GitLab instance
export GITLAB_TOKEN="glpat-your-token-here"
export GITLAB_PROJECT_ID="12345"  # your project ID
```

### Step 2: Update the Stub Function

Replace the `trigger_gitlab_pipeline` function in `http_server.py`:

```python
def trigger_gitlab_pipeline(pipeline_type: str, variables: Dict[str, str]) -> str:
    """
    Trigger a GitLab CI/CD pipeline.
    """
    import requests
    
    # Determine which branch/ref to use
    ref = "main"  # or map environment to branch
    if variables.get("ENVIRONMENT") == "dev":
        ref = "develop"
    elif variables.get("ENVIRONMENT") == "prod":
        ref = "main"
    
    # Call GitLab API
    response = requests.post(
        f"{GITLAB_URL}/api/v4/projects/{GITLAB_PROJECT_ID}/pipeline",
        headers={
            "PRIVATE-TOKEN": GITLAB_TOKEN,
            "Content-Type": "application/json"
        },
        json={
            "ref": ref,
            "variables": [
                {"key": k, "value": v, "variable_type": "env_var"}
                for k, v in variables.items()
            ]
        },
        timeout=30
    )
    
    response.raise_for_status()
    
    pipeline_data = response.json()
    pipeline_id = pipeline_data["id"]
    
    logger.info(f"GitLab pipeline triggered: {pipeline_id}")
    logger.info(f"Pipeline URL: {pipeline_data['web_url']}")
    
    return str(pipeline_id)
```

### Step 3: Update Status Checking

Replace the `get_status` function:

```python
@app.get("/status/{execution_id}")
async def get_status(execution_id: str):
    """Get pipeline execution status from GitLab"""
    import requests
    
    if execution_id not in executions:
        raise HTTPException(status_code=404, detail="Execution not found")
    
    execution = executions[execution_id]
    gitlab_pipeline_id = execution["gitlab_pipeline_id"]
    
    # Poll GitLab API for status
    response = requests.get(
        f"{GITLAB_URL}/api/v4/projects/{GITLAB_PROJECT_ID}/pipelines/{gitlab_pipeline_id}",
        headers={"PRIVATE-TOKEN": GITLAB_TOKEN},
        timeout=10
    )
    
    response.raise_for_status()
    pipeline_data = response.json()
    
    # Map GitLab status to our status
    status_map = {
        "created": "pending",
        "waiting_for_resource": "pending",
        "preparing": "pending",
        "pending": "pending",
        "running": "running",
        "success": "completed",
        "failed": "failed",
        "canceled": "canceled",
        "skipped": "skipped",
        "manual": "waiting"
    }
    
    execution["status"] = status_map.get(pipeline_data["status"], "unknown")
    execution["gitlab_status"] = pipeline_data["status"]
    execution["gitlab_url"] = pipeline_data["web_url"]
    
    if execution["status"] in ["completed", "failed", "canceled"]:
        execution["completed_at"] = pipeline_data.get("finished_at")
    
    return execution
```

### Step 4: Configure Your GitLab CI/CD

Your `.gitlab-ci.yml` should accept the variables:

```yaml
# .gitlab-ci.yml

variables:
  PIPELINE_TYPE: "bootstrap"  # Will be overridden by API
  ENVIRONMENT: "dev"          # Will be overridden by API
  TENANT_ID: ""               # Will be overridden by API

stages:
  - validate
  - execute
  - verify

# Bootstrap pipeline
bootstrap:
  stage: execute
  rules:
    - if: '$PIPELINE_TYPE == "bootstrap"'
  script:
    - echo "Running bootstrap pipeline for $ENVIRONMENT"
    - echo "AWS Region: $AWS_REGION"
    - cd terraform/bootstrap
    - terraform init
    - terraform apply -var="environment=$ENVIRONMENT" -auto-approve

# Compute pipeline
compute:
  stage: execute
  rules:
    - if: '$PIPELINE_TYPE == "compute"'
  script:
    - echo "Running compute pipeline for $ENVIRONMENT"
    - echo "Tenant: $TENANT_ID"
    - echo "Instance Type: $INSTANCE_TYPE"
    - echo "Instance Count: $INSTANCE_COUNT"
    - cd terraform/compute
    - terraform init
    - terraform apply \
        -var="environment=$ENVIRONMENT" \
        -var="tenant_id=$TENANT_ID" \
        -var="instance_type=$INSTANCE_TYPE" \
        -var="instance_count=$INSTANCE_COUNT" \
        -auto-approve

# App pipeline
app:
  stage: execute
  rules:
    - if: '$PIPELINE_TYPE == "app"'
  script:
    - echo "Running app pipeline for $ENVIRONMENT"
    - echo "Tenant: $TENANT_ID"
    - echo "App: $APP_NAME version $APP_VERSION"
    - cd ansible
    - ansible-playbook deploy-app.yml \
        -e "environment=$ENVIRONMENT" \
        -e "tenant_id=$TENANT_ID" \
        -e "app_name=$APP_NAME" \
        -e "app_version=$APP_VERSION"
```

## Testing

### 1. Test Locally (Stub Mode)

```bash
# Start MCP server
cd src/mcp_server
python http_server.py

# In another terminal, test
curl -X POST http://localhost:8000/execute \
  -H "Content-Type: application/json" \
  -d '{
    "pipeline_type": "bootstrap",
    "environment": "dev",
    "parameters": {"region": "us-east-1"}
  }'
```

You'll see detailed logs showing what would be sent to GitLab.

### 2. Test with Real GitLab

```bash
# Set environment variables
export GITLAB_URL="https://gitlab.com"
export GITLAB_TOKEN="glpat-your-token"
export GITLAB_PROJECT_ID="12345"

# Start server
python http_server.py

# Trigger pipeline
curl -X POST http://localhost:8000/execute \
  -H "Content-Type: application/json" \
  -d '{
    "pipeline_type": "bootstrap",
    "environment": "dev",
    "parameters": {"region": "us-east-1"}
  }'

# Check status
curl http://localhost:8000/status/{execution_id}
```

## Production Deployment

### Option 1: Deploy MCP Server to ECS

```yaml
# docker-compose.yml or ECS task definition
services:
  mcp-server:
    image: your-registry/mcp-server:latest
    environment:
      - GITLAB_URL=https://gitlab.com
      - GITLAB_TOKEN=${GITLAB_TOKEN}
      - GITLAB_PROJECT_ID=12345
    ports:
      - "8000:8000"
```

Update Lambda environment variable:
```
MCP_SERVER_URL=http://mcp-server.internal:8000
```

### Option 2: Deploy as Lambda Function

Convert `http_server.py` to Lambda handler:

```python
# lambda_handler.py
from mangum import Mangum
from http_server import app

handler = Mangum(app)
```

Update `mcp_proxy.py` to invoke Lambda instead of HTTP:

```python
lambda_client = boto3.client('lambda')

response = lambda_client.invoke(
    FunctionName='mcp-server',
    InvocationType='RequestResponse',
    Payload=json.dumps({
        'pipeline_type': 'bootstrap',
        'environment': 'dev',
        ...
    })
)
```

## Security Considerations

### 1. Protect GitLab Token

```python
# Use AWS Secrets Manager
import boto3

secrets_client = boto3.client('secretsmanager')
response = secrets_client.get_secret_value(SecretId='gitlab-token')
GITLAB_TOKEN = json.loads(response['SecretString'])['token']
```

### 2. Add Authentication to MCP Server

```python
from fastapi import Header, HTTPException

API_KEY = os.getenv('MCP_API_KEY')

async def verify_api_key(x_api_key: str = Header(...)):
    if x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")

@app.post("/execute", dependencies=[Depends(verify_api_key)])
async def execute_pipeline(request: PipelineRequest):
    ...
```

### 3. Use VPC Endpoints

Deploy MCP server in private subnet, use VPC endpoint for Lambda communication.

## Monitoring

### Add CloudWatch Logging

```python
import watchtower

logger.addHandler(watchtower.CloudWatchLogHandler(
    log_group='/aws/mcp-server',
    stream_name='pipeline-executions'
))
```

### Add Metrics

```python
import boto3

cloudwatch = boto3.client('cloudwatch')

cloudwatch.put_metric_data(
    Namespace='MCPServer',
    MetricData=[{
        'MetricName': 'PipelineExecutions',
        'Value': 1,
        'Unit': 'Count',
        'Dimensions': [
            {'Name': 'PipelineType', 'Value': pipeline_type},
            {'Name': 'Environment', 'Value': environment}
        ]
    }]
)
```

## Summary

1. **Current**: Stubbed - logs parameters but doesn't call GitLab
2. **To integrate**: Update `trigger_gitlab_pipeline()` and `get_status()`
3. **GitLab setup**: Configure `.gitlab-ci.yml` to accept variables
4. **Production**: Deploy to ECS/Lambda with proper networking
5. **Security**: Use Secrets Manager, add authentication, use VPC

The stub implementation clearly shows what parameters the agent identified and what would be sent to GitLab!
