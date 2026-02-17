# Lambda and MCP Server Flow

## Complete Request Flow

```
┌──────────────────────────────────────────────────────────────────────┐
│                         USER REQUEST                                  │
│  "Deploy bootstrap infrastructure for dev environment"               │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │   API Gateway        │
                  │   POST /chat         │
                  └──────────┬───────────┘
                             │
                             ▼
            ┌────────────────────────────────┐
            │  Lambda: chat_handler.py       │
            │  Purpose: Entry point          │
            │  • Parse user message          │
            │  • Invoke orchestrator agent   │
            └────────────┬───────────────────┘
                         │
                         │ bedrock_agent_runtime.invoke_agent()
                         ▼
┌────────────────────────────────────────────────────────────────────────┐
│                    ORCHESTRATOR AGENT (Bedrock)                        │
│  • LLM analyzes: "Need bootstrap for dev"                             │
│  • Searches knowledge base (RAG)                                       │
│  • Queries memory: "Does dev bootstrap exist?"                         │
│  • Decides: "Need to invoke Bootstrap Agent"                           │
└────────────────────────┬───────────────────────────────────────────────┘
                         │
                         │ Calls action group: invoke-specialized-agent
                         ▼
            ┌────────────────────────────────┐
            │  Lambda: agent_invoker.py      │
            │  Purpose: Multi-agent coord    │
            │  • Receives: agent_type="bootstrap" │
            │  • Invokes Bootstrap Agent     │
            └────────────┬───────────────────┘
                         │
                         │ bedrock_agent_runtime.invoke_agent()
                         ▼
┌────────────────────────────────────────────────────────────────────────┐
│                    BOOTSTRAP AGENT (Bedrock)                           │
│  • LLM receives: "Create bootstrap for dev"                            │
│  • Searches knowledge base for bootstrap details                       │
│  • Decides: "Need to execute bootstrap pipeline"                       │
│  • Calls action group: execute-bootstrap-pipeline                      │
│  • Parameters: {environment: "dev", region: "us-east-1"}               │
└────────────────────────┬───────────────────────────────────────────────┘
                         │
                         │ Bedrock invokes Lambda (action group)
                         ▼
            ┌────────────────────────────────┐
            │  Lambda: mcp_proxy.py          │
            │  Purpose: Bridge to MCP        │
            │  • Receives action group call  │
            │  • Extracts parameters         │
            │  • Makes HTTP call to MCP      │
            └────────────┬───────────────────┘
                         │
                         │ HTTP POST to http://mcp-server:8000/execute
                         │ Body: {
                         │   pipeline_type: "bootstrap",
                         │   environment: "dev",
                         │   parameters: {region: "us-east-1"}
                         │ }
                         ▼
            ┌────────────────────────────────┐
            │  MCP Server: http_server.py    │
            │  Purpose: Execute pipelines    │
            │  • Receives request            │
            │  • Logs parameters             │
            │  • Calls GitLab API (STUBBED)  │
            │  • Returns execution ID        │
            └────────────┬───────────────────┘
                         │
                         │ (STUBBED - Should call GitLab)
                         │ POST https://gitlab.com/api/v4/projects/123/pipeline
                         │ Variables: PIPELINE_TYPE=bootstrap, ENVIRONMENT=dev
                         ▼
                    GitLab CI/CD
                    (Your actual pipelines)
                         │
                         │ Results flow back
                         ▼
            ┌────────────────────────────────┐
            │  Lambda: mcp_proxy.py          │
            │  • Receives result from MCP    │
            │  • Stores in DynamoDB          │
            │  • Returns to Bootstrap Agent  │
            └────────────┬───────────────────┘
                         │
                         ▼
┌────────────────────────────────────────────────────────────────────────┐
│                    BOOTSTRAP AGENT (Bedrock)                           │
│  • Receives: "Pipeline executed, ID: abc-123"                          │
│  • Generates response: "Bootstrap completed for dev"                   │
└────────────────────────┬───────────────────────────────────────────────┘
                         │
                         ▼
            ┌────────────────────────────────┐
            │  Lambda: agent_invoker.py      │
            │  • Returns result to orchestrator │
            └────────────┬───────────────────┘
                         │
                         ▼
┌────────────────────────────────────────────────────────────────────────┐
│                    ORCHESTRATOR AGENT (Bedrock)                        │
│  • Receives: "Bootstrap completed"                                     │
│  • Generates final response for user                                   │
└────────────────────────┬───────────────────────────────────────────────┘
                         │
                         ▼
            ┌────────────────────────────────┐
            │  Lambda: chat_handler.py       │
            │  • Returns response to user    │
            └────────────┬───────────────────┘
                         │
                         ▼
                  ┌──────────────────────┐
                  │   API Gateway        │
                  │   Response           │
                  └──────────┬───────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│                         USER RESPONSE                                 │
│  "Successfully created bootstrap infrastructure for dev environment" │
└──────────────────────────────────────────────────────────────────────┘
```

## Lambda Functions Explained

### 1. chat_handler.py

**Purpose**: Entry point for user requests

**Triggered by**: API Gateway

**What it does**:
```python
def handler(event, context):
    message = extract_message(event)
    
    # Invoke orchestrator agent
    response = bedrock_agent_runtime.invoke_agent(
        agentId=ORCHESTRATOR_AGENT_ID,
        inputText=message
    )
    
    return format_response(response)
```

**Why needed**: API Gateway can only invoke Lambda, not Bedrock directly

### 2. agent_invoker.py

**Purpose**: Enable multi-agent orchestration

**Triggered by**: Orchestrator Agent (via action group)

**What it does**:
```python
def invoke_specialized_agent(params):
    agent_type = params['agent_type']  # "bootstrap", "compute", "app"
    instruction = params['instruction']
    
    # Invoke the specialized agent
    response = bedrock_agent_runtime.invoke_agent(
        agentId=AGENT_IDS[agent_type],
        inputText=instruction
    )
    
    return response
```

**Why needed**: Enables orchestrator to delegate to specialized agents

### 3. mcp_proxy.py

**Purpose**: Bridge between Bedrock Agents and MCP Server

**Triggered by**: Specialized Agents (via action group)

**What it does**:
```python
def execute_mcp_tool(tool_name, params):
    # Extract parameters identified by agent
    pipeline_type = map_tool_to_pipeline(tool_name)
    
    # Call MCP server
    response = requests.post(
        f"{MCP_SERVER_URL}/execute",
        json={
            'pipeline_type': pipeline_type,
            'environment': params['environment'],
            'tenant_id': params.get('tenant_id'),
            'parameters': params
        }
    )
    
    # Store in memory
    store_in_memory(response.json())
    
    return response.json()
```

**Why needed**: Bedrock action groups can only call Lambda, not arbitrary HTTP endpoints

### 4. memory_manager.py

**Purpose**: Provide deployment history to agents

**Triggered by**: Orchestrator Agent (via action group)

**What it does**:
```python
def query_memory(params):
    environment = params['environment']
    
    # Query DynamoDB
    items = memory_table.query(
        IndexName='environment-index',
        KeyConditionExpression=Key('environment').eq(environment)
    )
    
    return {'deployments': items}
```

**Why needed**: Agents need to check what's already deployed

## MCP Server Architecture

### Current Setup (POC)

```
┌─────────────────────────────────────────────────────────┐
│  Lambda: mcp_proxy.py                                   │
│  Environment: MCP_SERVER_URL=http://localhost:8000      │
└────────────────────────┬────────────────────────────────┘
                         │
                         │ HTTP POST (won't work - Lambda can't reach localhost)
                         ▼
┌─────────────────────────────────────────────────────────┐
│  MCP Server: http_server.py                             │
│  Running: python http_server.py                         │
│  Port: 8000                                             │
│  Location: Your local machine or EC2                    │
└─────────────────────────────────────────────────────────┘
```

**Problem**: Lambda can't reach localhost. You need to deploy MCP server separately.

### Production Setup (Recommended)

**Option 1: ECS Fargate**
```
┌─────────────────────────────────────────────────────────┐
│  Lambda: mcp_proxy.py (in VPC)                          │
│  Environment: MCP_SERVER_URL=http://mcp.internal:8000   │
└────────────────────────┬────────────────────────────────┘
                         │
                         │ HTTP POST via VPC
                         ▼
┌─────────────────────────────────────────────────────────┐
│  ECS Service: mcp-server                                │
│  Task: http_server.py                                   │
│  Service Discovery: mcp.internal                        │
│  Environment:                                           │
│    GITLAB_URL=https://gitlab.com                        │
│    GITLAB_TOKEN=<from Secrets Manager>                  │
│    GITLAB_PROJECT_ID=12345                              │
└────────────────────────┬────────────────────────────────┘
                         │
                         │ HTTPS
                         ▼
                    GitLab API
```

**Option 2: Lambda Function**
```
┌─────────────────────────────────────────────────────────┐
│  Lambda: mcp_proxy.py                                   │
└────────────────────────┬────────────────────────────────┘
                         │
                         │ Lambda.invoke()
                         ▼
┌─────────────────────────────────────────────────────────┐
│  Lambda: mcp_server (converted to Lambda handler)       │
│  Handler: lambda_handler.py                             │
│  Environment:                                           │
│    GITLAB_URL=https://gitlab.com                        │
│    GITLAB_TOKEN=<from Secrets Manager>                  │
└────────────────────────┬────────────────────────────────┘
                         │
                         │ HTTPS
                         ▼
                    GitLab API
```

## Authentication Flow

### POC (No Auth)

```
Lambda → HTTP POST → MCP Server
(No authentication)
```

### Production (With Auth)

```
Lambda → HTTP POST with API Key → MCP Server
         Header: X-API-Key: secret

MCP Server validates API key before processing
```

## Summary

### Lambda Purposes

| Lambda | Purpose | Triggered By | Calls |
|--------|---------|--------------|-------|
| chat_handler | Entry point | API Gateway | Orchestrator Agent |
| agent_invoker | Multi-agent coord | Orchestrator Agent | Specialized Agents |
| mcp_proxy | Pipeline execution | Specialized Agents | MCP Server |
| memory_manager | State queries | Orchestrator Agent | DynamoDB |

### MCP Server

- **Purpose**: Execute actual pipelines (GitLab, Jenkins, etc.)
- **Current**: Stubbed - logs parameters but doesn't call GitLab
- **Should**: Call GitLab API to trigger real pipelines
- **Deployment**: Separate from Lambda (ECS, EC2, or separate Lambda)
- **Communication**: HTTP (POC) or Lambda invoke (production)
- **Authentication**: None (POC), API key or VPC (production)

### Key Points

1. **Lambdas are bridges** - they connect Bedrock Agents to external systems
2. **MCP Server is separate** - it's not part of Lambda, it's a standalone service
3. **Currently stubbed** - MCP server logs what it would do but doesn't call GitLab
4. **Parameters flow from agent** - LLM identifies parameters, they flow through Lambda to MCP
5. **No auth in POC** - production should add authentication and VPC networking
