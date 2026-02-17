# MCP Server Architecture Explained

## Overview

The MCP (Model Context Protocol) server is where **actual pipeline execution happens**. Currently it's stubbed - it doesn't call real GitLab APIs. Let me explain the architecture and show you how to integrate with GitLab.

## Architecture Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     AWS Bedrock Agent (LLM)                      │
│  "I need to execute the bootstrap pipeline for dev environment" │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ LLM decides to call MCP tool
                         │ Action Group: execute-bootstrap-pipeline
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Lambda: mcp_proxy.py                          │
│  • Receives action group invocation from Bedrock                 │
│  • Extracts parameters identified by agent                       │
│  • Makes HTTP call to MCP server                                 │
│  • Returns result to agent                                       │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ HTTP POST to http://localhost:8000/execute
                         │ (or VPC endpoint in production)
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│              MCP Server: http_server.py                          │
│  • Receives pipeline execution request                           │
│  • Calls GitLab API to trigger pipeline (STUBBED)                │
│  • Monitors pipeline status                                      │
│  • Returns execution result                                      │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ (Currently stubbed)
                         │ Should call GitLab API
                         ▼
                    GitLab CI/CD
                    (Your actual pipelines)
```

## Component Breakdown

### 1. Bedrock Agent (LLM Decision)

**What happens**:
- Agent LLM receives instruction: "Create bootstrap infrastructure for dev"
- LLM searches knowledge base for guidance
- LLM decides to call action group: `execute-bootstrap-pipeline`
- LLM provides parameters: `{environment: "dev", region: "us-east-1"}`

**Where**: AWS Bedrock (managed service)

### 2. Lambda: mcp_proxy.py (Bridge)

**Purpose**: Bridge between Bedrock Agents and MCP Server

**What it does**:
1. Receives action group invocation from Bedrock
2. Extracts parameters identified by the agent
3. Makes HTTP call to MCP server
4. Stores result in DynamoDB (memory)
5. Returns result to agent

**Location**: `src/lambda/mcp_proxy.py`

**Runtime**: AWS Lambda (Python 3.11)

**Invocation**: Direct from Bedrock Agents (no auth needed - IAM role)

**Code flow**:
```python
# 1. Bedrock calls Lambda
handler(event, context)
    ↓
# 2. Extract parameters from agent
params = extract_params(event)
# params = {
#   'environment': 'dev',
#   'region': 'us-east-1',
#   'tenant_id': 'ABC'
# }
    ↓
# 3. Call MCP server
response = requests.post(
    "http://localhost:8000/execute",
    json={'pipeline_type': 'bootstrap', ...}
)
    ↓
# 4. Store in memory
store_in_memory(response.json())
    ↓
# 5. Return to agent
return format_response(response.json())
```

### 3. MCP Server: http_server.py (Pipeline Executor)

**Purpose**: Execute actual pipelines (GitLab, Jenkins, etc.)

**What it does**:
1. Receives pipeline execution request
2. Calls GitLab API to trigger pipeline (CURRENTLY STUBBED)
3. Monitors pipeline status
4. Returns execution result

**Location**: `src/mcp_server/http_server.py`

**Runtime**: 
- **POC**: Runs locally (`python http_server.py`)
- **Production**: Should run in ECS/Lambda/EC2

**Authentication**: 
- **POC**: No auth (localhost)
- **Production**: Should add API key or VPC endpoint

**Current status**: STUBBED - doesn't call real GitLab

## Question 1: Does it invoke real GitLab API?

**Answer: NO, it's currently stubbed.**

The current implementation just returns fake success responses:

```python
# Current (STUBBED)
execution = {
    "execution_id": "abc-123",
    "status": "completed",  # Fake!
    "steps": [
        {"name": "Create VPC", "status": "completed"}  # Fake!
    ]
}
```

**It should call GitLab API like this** (see updated implementation below).

## Question 2: How does Runtime call MCP servers?

**Answer: Lambda makes HTTP calls to MCP server**

### Current Setup (POC)

```
Lambda (mcp_proxy.py)
    ↓ HTTP POST
MCP Server (localhost:8000)
```

**Configuration**:
```python
# In Lambda environment variable
MCP_SERVER_URL = "http://localhost:8000"

# Lambda makes HTTP call
response = requests.post(
    f"{mcp_server_url}/execute",
    json={...}
)
```

**Authentication**: None (localhost, same runtime)

**Limitations**:
- ❌ Lambda can't actually reach localhost
- ❌ This only works if MCP server runs in same container
- ❌ Not production-ready

### Production Setup (Recommended)

**Option 1: MCP Server in ECS with VPC Endpoint**
```
Lambda (VPC)
    ↓ HTTP POST via VPC endpoint
MCP Server (ECS Fargate)
    ↓ HTTPS
GitLab API
```

**Option 2: MCP Server as Lambda Function**
```
Lambda (mcp_proxy.py)
    ↓ Lambda invoke
Lambda (mcp_server.py)
    ↓ HTTPS
GitLab API
```

**Option 3: API Gateway + ECS**
```
Lambda (mcp_proxy.py)
    ↓ HTTPS via API Gateway
API Gateway
    ↓ VPC Link
MCP Server (ECS)
    ↓ HTTPS
GitLab API
```

## Question 3: Purpose of Lambdas

### Lambda 1: mcp_proxy.py

**Purpose**: Bridge between Bedrock Agents and MCP Server

**When invoked**: When agent LLM calls MCP tool action groups

**What it does**:
- Receives action group invocation from Bedrock
- Translates to HTTP call to MCP server
- Stores result in DynamoDB
- Returns result to agent

**Why needed**: Bedrock action groups can only call Lambda, not arbitrary HTTP endpoints

**Flow**:
```
Bedrock Agent → Lambda (mcp_proxy) → MCP Server → GitLab
```

### Lambda 2: agent_invoker.py

**Purpose**: Enable orchestrator to invoke specialized agents

**When invoked**: When orchestrator LLM calls `invoke-specialized-agent` action group

**What it does**:
- Receives agent invocation request from orchestrator
- Calls Bedrock Agent Runtime API to invoke specialized agent
- Returns specialized agent's response to orchestrator

**Why needed**: Enables multi-agent orchestration

**Flow**:
```
Orchestrator Agent → Lambda (agent_invoker) → Bedrock API → Specialized Agent
```

### Lambda 3: memory_manager.py

**Purpose**: Provide deployment history to agents

**When invoked**: When agent LLM calls `memory-operations` action group

**What it does**:
- Queries DynamoDB for deployment history
- Returns results to agent for decision-making

**Why needed**: Agents need to check what's already deployed

**Flow**:
```
Agent → Lambda (memory_manager) → DynamoDB → Agent
```

### Lambda 4: chat_handler.py

**Purpose**: Entry point for user chat requests

**When invoked**: When user sends message via API Gateway

**What it does**:
- Receives user message
- Invokes orchestrator agent
- Returns agent response to user

**Why needed**: API Gateway can only invoke Lambda

**Flow**:
```
User → API Gateway → Lambda (chat_handler) → Bedrock Agent → User
```

## Lambda Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          USER REQUEST                            │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
                  ┌──────────────┐
                  │ API Gateway  │
                  └──────┬───────┘
                         │
                         ▼
            ┌────────────────────────┐
            │ Lambda: chat_handler   │ ← Entry point
            │ • Invoke orchestrator  │
            └────────────┬───────────┘
                         │
                         ▼
            ┌─────────────────────────────────────┐
            │   Orchestrator Agent (Bedrock)      │
            │   • Analyzes request                │
            │   • Searches knowledge base         │
            │   • Decides what to do              │
            └─────────────┬───────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
┌───────────────┐ ┌──────────────┐ ┌──────────────┐
│ Lambda:       │ │ Lambda:      │ │ Lambda:      │
│ agent_invoker │ │ memory_mgr   │ │ mcp_proxy    │
│               │ │              │ │              │
│ Invoke other  │ │ Query/store  │ │ Execute      │
│ agents        │ │ history      │ │ pipelines    │
└───────┬───────┘ └──────┬───────┘ └──────┬───────┘
        │                │                │
        ▼                ▼                ▼
┌───────────────┐ ┌──────────────┐ ┌──────────────┐
│ Specialized   │ │ DynamoDB     │ │ MCP Server   │
│ Agents        │ │ (Memory)     │ │ (Pipelines)  │
└───────────────┘ └──────────────┘ └──────┬───────┘
                                           │
                                           ▼
                                    ┌──────────────┐
                                    │ GitLab API   │
                                    └──────────────┘
```

## Summary

### MCP Server Organization
- **Location**: `src/mcp_server/http_server.py`
- **Purpose**: Execute actual pipelines
- **Current**: Stubbed (fake responses)
- **Should**: Call GitLab API to trigger real pipelines

### Runtime Communication
- **Lambda → MCP Server**: HTTP POST (currently localhost, should be VPC endpoint)
- **Authentication**: None in POC (should add API key in production)
- **Same runtime**: No - Lambda and MCP server are separate processes

### Lambda Purposes
1. **mcp_proxy**: Bridge Bedrock → MCP Server
2. **agent_invoker**: Enable multi-agent orchestration
3. **memory_manager**: Provide deployment history
4. **chat_handler**: User interface entry point

### Next Steps
1. Update MCP server to call real GitLab API (see updated implementation)
2. Deploy MCP server to ECS/Lambda (not localhost)
3. Add authentication between Lambda and MCP server
4. Configure VPC networking for Lambda → MCP communication
