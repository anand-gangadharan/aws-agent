# Example: LLM-Driven Interaction

This document shows a concrete example of how the LLM orchestrates a deployment.

## User Request

```
POST /chat
{
  "message": "I need to deploy MyApp version 2.0 to tenant ABC in the dev environment"
}
```

## Step-by-Step LLM Reasoning

### 1. Orchestrator Agent LLM Receives Request

**Input to LLM**:
```
User message: "I need to deploy MyApp version 2.0 to tenant ABC in the dev environment"
```

**LLM Internal Reasoning** (what Claude thinks):
```
Let me analyze this request:
- User wants to deploy an application
- Application: MyApp version 2.0
- Tenant: ABC
- Environment: dev

I should check my knowledge base for deployment requirements...
```

**LLM Action**: Searches knowledge base (automatic RAG)

**Knowledge Base Query**: "application deployment requirements"

**Retrieved Context**:
```markdown
## Decision Making

### Deploying New Application
When deploying application to existing tenant:
1. Verify compute resources exist (check memory)
2. Delegate to App Agent only
```

**LLM Reasoning Continues**:
```
According to my knowledge base, I need to:
1. Check if compute resources exist for tenant ABC in dev
2. If yes, just invoke App Agent
3. If no, I need to provision compute first

Let me query memory to check...
```

**LLM Action**: Calls action group `memory-operations`

**Action Group Call**:
```json
{
  "action": "query_memory",
  "parameters": {
    "environment": "dev",
    "tenant_id": "ABC"
  }
}
```

### 2. Memory Manager Returns History

**Memory Query Result**:
```json
{
  "count": 2,
  "deployments": [
    {
      "pipeline_type": "bootstrap",
      "environment": "dev",
      "status": "completed",
      "timestamp": 1708123456
    },
    {
      "pipeline_type": "compute",
      "environment": "dev",
      "tenant_id": "ABC",
      "status": "completed",
      "timestamp": 1708123789
    }
  ]
}
```

**LLM Reasoning**:
```
Great! Memory shows:
- Bootstrap exists for dev ✓
- Compute exists for tenant ABC in dev ✓

This means I can skip Bootstrap and Compute agents.
I only need to invoke the App Agent to deploy MyApp.
```

**LLM Action**: Calls action group `invoke-specialized-agent`

**Action Group Call**:
```json
{
  "action": "invoke_agent",
  "parameters": {
    "agent_type": "app",
    "instruction": "Deploy MyApp version 2.0 to tenant ABC in the dev environment. The compute infrastructure is already provisioned.",
    "environment": "dev",
    "tenant_id": "ABC",
    "parameters": {
      "app_name": "MyApp",
      "app_version": "2.0"
    }
  }
}
```

### 3. Agent Invoker Forwards to App Agent

**Agent Invoker** (`agent_invoker.py`) receives the call and invokes App Agent's LLM:

```python
# Builds full instruction
full_instruction = """
Deploy MyApp version 2.0 to tenant ABC in the dev environment. 
The compute infrastructure is already provisioned.

Environment: dev
Tenant ID: ABC

Please use your MCP tools to execute the pipeline and your knowledge base for guidance.
Store the results in memory when complete.
"""

# Invokes App Agent's LLM
response = bedrock_agent_runtime.invoke_agent(
    agentId=app_agent_id,
    inputText=full_instruction
)
```

### 4. App Agent LLM Processes Request

**Input to App Agent LLM**:
```
Deploy MyApp version 2.0 to tenant ABC in the dev environment. 
The compute infrastructure is already provisioned.

Environment: dev
Tenant ID: ABC

Please use your MCP tools to execute the pipeline and your knowledge base for guidance.
```

**App Agent LLM Reasoning**:
```
I need to deploy an application. Let me check my knowledge base for deployment procedures...
```

**LLM Action**: Searches knowledge base (automatic RAG)

**Knowledge Base Query**: "application deployment process"

**Retrieved Context**:
```markdown
## Deployment Process
1. Download application artifacts
2. Copy to target EC2 instances
3. Install dependencies
4. Configure application
5. Start services
6. Run health checks
```

**App Agent LLM Reasoning**:
```
According to my knowledge base, I need to:
1. Download the application
2. Deploy to EC2
3. Run health checks

I have an MCP tool available: execute-app-pipeline
Let me call it with the appropriate parameters...
```

**LLM Action**: Calls action group `execute-app-pipeline`

**Action Group Call**:
```json
{
  "action": "execute_app_pipeline",
  "parameters": {
    "environment": "dev",
    "tenant_id": "ABC",
    "app_name": "MyApp",
    "app_version": "2.0"
  }
}
```

### 5. MCP Proxy Executes Pipeline

**MCP Proxy** (`mcp_proxy.py`) receives the call:

```python
# Routes to MCP server
result = execute_mcp_tool('execute_app_pipeline', {
    'environment': 'dev',
    'tenant_id': 'ABC',
    'app_name': 'MyApp',
    'app_version': '2.0'
})
```

**MCP Server** executes actual pipeline:

```python
# Actual pipeline execution
execution = {
    "execution_id": "exec-789",
    "pipeline_type": "app",
    "environment": "dev",
    "tenant_id": "ABC",
    "status": "completed",
    "parameters": {
        "app_name": "MyApp",
        "app_version": "2.0"
    },
    "steps": [
        {"name": "Download application", "status": "completed"},
        {"name": "Deploy to EC2", "status": "completed"},
        {"name": "Health check", "status": "completed"}
    ]
}
```

**MCP Proxy** stores in memory:

```python
memory_table.put_item(Item={
    'session_id': 'exec-789',
    'environment': 'dev',
    'tenant_id': 'ABC',
    'pipeline_type': 'app',
    'status': 'completed',
    'details': json.dumps(execution)
})
```

### 6. Results Flow Back to App Agent LLM

**App Agent LLM Receives**:
```json
{
  "execution_id": "exec-789",
  "status": "completed",
  "steps": [
    {"name": "Download application", "status": "completed"},
    {"name": "Deploy to EC2", "status": "completed"},
    {"name": "Health check", "status": "completed"}
  ]
}
```

**App Agent LLM Reasoning**:
```
The pipeline executed successfully. All steps completed.
Let me generate a clear response for the orchestrator...
```

**App Agent LLM Response**:
```
Successfully deployed MyApp version 2.0 to tenant ABC in the dev environment.

Deployment details:
- Execution ID: exec-789
- All deployment steps completed successfully
- Application is healthy and running
- Deployment stored in memory for future reference
```

### 7. Orchestrator Receives App Agent Response

**Orchestrator LLM Receives**:
```
Successfully deployed MyApp version 2.0 to tenant ABC in the dev environment.

Deployment details:
- Execution ID: exec-789
- All deployment steps completed successfully
- Application is healthy and running
```

**Orchestrator LLM Reasoning**:
```
The App Agent successfully completed the deployment.
I should provide a comprehensive response to the user...
```

**Orchestrator LLM Final Response**:
```
I've successfully deployed MyApp version 2.0 to tenant ABC in the dev environment.

Here's what happened:
✓ Verified that bootstrap infrastructure exists for dev
✓ Confirmed compute resources are provisioned for tenant ABC
✓ Deployed MyApp version 2.0 to the tenant's EC2 instances
✓ All health checks passed

Execution ID: exec-789

The application is now running and healthy. The deployment has been recorded in memory for future reference.
```

### 8. User Receives Response

```json
{
  "response": "I've successfully deployed MyApp version 2.0 to tenant ABC in the dev environment.\n\nHere's what happened:\n✓ Verified that bootstrap infrastructure exists for dev\n✓ Confirmed compute resources are provisioned for tenant ABC\n✓ Deployed MyApp version 2.0 to the tenant's EC2 instances\n✓ All health checks passed\n\nExecution ID: exec-789\n\nThe application is now running and healthy. The deployment has been recorded in memory for future reference.",
  "session_id": "session-123"
}
```

## Key Observations

### LLM Decision Points

1. **Orchestrator decided** to check memory first (not hardcoded)
2. **Orchestrator decided** to skip Bootstrap and Compute (based on memory)
3. **Orchestrator decided** to invoke only App Agent (dynamic decision)
4. **App Agent decided** to search its knowledge base (automatic)
5. **App Agent decided** to call the MCP tool (not hardcoded)
6. **App Agent decided** how to format the response (natural language generation)
7. **Orchestrator decided** how to summarize for the user (natural language generation)

### No Static Routing

Notice there's no code like:
```python
if request.contains("deploy") and request.contains("app"):
    call_app_agent()
```

Instead, the LLM:
- Understands natural language
- Searches knowledge bases
- Queries memory
- Makes dynamic decisions
- Generates natural language responses

### RAG in Action

The LLMs automatically searched their knowledge bases:
- Orchestrator: "deployment requirements" → found decision tree
- App Agent: "deployment process" → found step-by-step guide

This context influenced their decisions without any explicit code.

### Memory-Driven Decisions

The orchestrator's decision to skip Bootstrap and Compute was based on querying memory, not hardcoded logic. If memory had shown no compute for tenant ABC, the LLM would have decided to invoke the Compute Agent first.

## Alternative Scenario: New Tenant

If the user had asked: "Deploy MyApp to tenant XYZ in dev"

And memory showed no compute for tenant XYZ, the orchestrator LLM would have reasoned:

```
Memory shows:
- Bootstrap exists for dev ✓
- Compute does NOT exist for tenant XYZ ✗

According to my knowledge base, I need compute before deploying apps.
I should invoke Compute Agent first, then App Agent.
```

The LLM would dynamically adjust the workflow based on the actual state!

This is the power of LLM-driven orchestration.
