# Component Mapping: Where LLM Magic Happens

This document maps each file to its role in the LLM-driven architecture.

## 1. Agent Definitions (LLM Brains)

### `terraform/bedrock_agents.tf`
**What it does**: Defines the 4 Bedrock Agents with their LLM configurations

**Key LLM elements**:
- `foundation_model`: Specifies Claude 3 Sonnet as the brain
- `instruction`: Natural language guidance that shapes LLM behavior
- `knowledge_base`: Links to RAG knowledge base for context retrieval
- `guardrail_configuration`: Safety constraints on LLM outputs

**Example**:
```hcl
resource "aws_bedrockagent_agent" "orchestrator" {
  foundation_model = "anthropic.claude-3-sonnet-20240229-v1:0"
  
  instruction = <<-EOT
    You are an intelligent orchestrator...
    ANALYZE user requests...
    QUERY memory to check history...
    DETERMINE which pipelines are needed...
    INVOKE specialized agents...
  EOT
  
  knowledge_base {
    knowledge_base_id = aws_bedrockagent_knowledge_base.orchestrator.id
  }
}
```

**LLM behavior**: The instruction guides how the LLM reasons about requests and makes decisions.

---

## 2. Action Groups (Tools Available to LLM)

### `terraform/bedrock_action_groups.tf`
**What it does**: Defines tools that agents' LLMs can call

**Key LLM elements**:
- OpenAPI schemas that describe available functions
- The LLM reads these schemas and decides when to call each tool
- Each tool maps to a Lambda function

**Example - Orchestrator's tool**:
```hcl
resource "aws_bedrockagent_agent_action_group" "orchestrator_delegate" {
  action_group_name = "invoke-specialized-agent"
  
  api_schema {
    payload = jsonencode({
      paths = {
        "/invoke-agent" = {
          post = {
            description = "Delegate work to Bootstrap, Compute, or App agent"
            # LLM reads this description to understand when to use this tool
          }
        }
      }
    })
  }
}
```

**LLM behavior**: When the orchestrator LLM decides it needs to delegate work, it calls this action group.

**Example - Bootstrap Agent's MCP tools**:
```hcl
resource "aws_bedrockagent_agent_action_group" "bootstrap_mcp" {
  action_group_name = "mcp-pipeline-tools"
  
  api_schema {
    paths = {
      "/mcp/execute-bootstrap" = {
        post = {
          description = "Creates VPC, subnets, ACLs, and networking infrastructure"
          # LLM reads this to know what the tool does
        }
      }
    }
  }
}
```

**LLM behavior**: When the bootstrap agent LLM decides to execute the pipeline, it calls this MCP tool.

---

## 3. Knowledge Bases (RAG Context)

### `terraform/bedrock_knowledge_base.tf`
**What it does**: Sets up vector databases for RAG

**Key LLM elements**:
- S3 buckets store markdown documentation
- OpenSearch Serverless indexes the content as vectors
- LLM automatically searches these when it needs information

**Example**:
```hcl
resource "aws_bedrockagent_knowledge_base" "orchestrator" {
  name = "orchestrator-kb"
  
  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "...titan-embed-text-v1"
    }
  }
  
  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn = aws_opensearchserverless_collection.knowledge_base.arn
      vector_index_name = "orchestrator-index"
    }
  }
}
```

**LLM behavior**: When the orchestrator LLM encounters a question like "What's the pipeline dependency order?", it automatically searches this knowledge base.

### `knowledge_base/orchestrator/orchestration_guide.md`
**What it does**: Provides context to the orchestrator LLM via RAG

**Example content**:
```markdown
## Pipeline Dependencies

1. **Bootstrap Pipeline** - Must run first
2. **Compute Pipeline** - Runs after Bootstrap
3. **App Pipeline** - Runs after Compute
```

**LLM behavior**: This content is retrieved and injected into the LLM's context when relevant.

---

## 4. Agent Invocation (Agent-to-Agent Communication)

### `src/lambda/agent_invoker.py`
**What it does**: Enables the orchestrator LLM to invoke other agents

**Key LLM elements**:
- Called when orchestrator's LLM uses the "invoke-specialized-agent" action
- Uses `bedrock_agent_runtime.invoke_agent()` to call another agent's LLM
- Passes natural language instructions between agents

**Example**:
```python
def invoke_specialized_agent(params):
    agent_type = params.get('agent_type')  # "bootstrap", "compute", or "app"
    instruction = params.get('instruction')  # Natural language from orchestrator
    
    # Build instruction with context
    full_instruction = f"""
{instruction}

Environment: {environment}
Tenant ID: {tenant_id}

Please use your MCP tools to execute the pipeline and your knowledge base for guidance.
"""
    
    # Invoke the specialized agent's LLM
    response = bedrock_agent_runtime.invoke_agent(
        agentId=agent_id,
        sessionId=session_id,
        inputText=full_instruction,  # Natural language instruction
        enableTrace=True
    )
    
    # The specialized agent's LLM will:
    # 1. Understand the instruction
    # 2. Search its knowledge base
    # 3. Decide which MCP tools to call
    # 4. Execute the tools
    # 5. Return a response
```

**LLM behavior**: This is pure agent-to-agent LLM communication. No hardcoded logic!

---

## 5. MCP Tool Execution (Pipeline Runtime)

### `src/lambda/mcp_proxy.py`
**What it does**: Bridges agent LLMs to the MCP server

**Key LLM elements**:
- Called when a specialized agent's LLM decides to use an MCP tool
- Translates the LLM's tool call into an HTTP request to MCP server
- Returns results back to the LLM

**Example**:
```python
def handler(event, context):
    # Event comes from Bedrock Agent when LLM calls an action group
    api_path = event.get('apiPath')  # e.g., "/mcp/execute-bootstrap"
    params = parse_request_body(event)
    
    # The LLM decided to call this tool with these parameters
    if api_path == '/mcp/execute-bootstrap':
        result = execute_mcp_tool('execute_bootstrap_pipeline', params)
    
    # Store in memory for future LLM queries
    store_in_memory(result)
    
    # Return to the LLM
    return format_response(result)
```

**LLM behavior**: The agent's LLM called this tool based on its reasoning. The result is returned to the LLM for further processing.

### `src/mcp_server/http_server.py`
**What it does**: Actual pipeline execution runtime

**Key LLM elements**:
- This is NOT LLM-driven - it's the actual pipeline execution
- Called by mcp_proxy when an agent's LLM decides to execute a pipeline
- Returns structured results that the LLM can understand

**Example**:
```python
@app.post("/execute")
async def execute_pipeline(request: PipelineRequest):
    # Execute the actual pipeline (VPC creation, EC2 provisioning, etc.)
    execution_id = str(uuid.uuid4())
    
    # Simulate pipeline execution
    execution = {
        "execution_id": execution_id,
        "pipeline_type": request.pipeline_type,
        "status": "completed",
        "steps": [...]
    }
    
    return execution  # This goes back to the agent's LLM
```

**LLM behavior**: The LLM receives this structured response and uses it to generate a natural language response.

---

## 6. Memory Operations (State for LLM)

### `src/lambda/memory_manager.py`
**What it does**: Provides deployment history to LLMs

**Key LLM elements**:
- Called when orchestrator's LLM uses the "memory-operations" action
- Queries DynamoDB for deployment history
- Returns structured data that the LLM uses for decision-making

**Example**:
```python
def query_memory(params):
    environment = params.get('environment')
    
    # Query DynamoDB
    response = memory_table.query(
        IndexName='environment-index',
        KeyConditionExpression=Key('environment').eq(environment)
    )
    
    # Return deployment history
    return {
        'count': len(items),
        'deployments': items  # LLM will analyze this
    }
```

**LLM behavior**: The orchestrator LLM calls this to check "Does bootstrap exist for dev?" and uses the response to decide what to do next.

---

## 7. Guardrails (LLM Safety)

### `terraform/bedrock_guardrails.tf`
**What it does**: Constrains LLM behavior for safety

**Key LLM elements**:
- Blocks certain words/topics in LLM inputs and outputs
- Applied to the orchestrator agent
- Prevents the LLM from helping with deprovisioning

**Example**:
```hcl
resource "aws_bedrock_guardrail" "main" {
  blocked_input_messaging = "I cannot help with deprovisioning..."
  
  word_policy_config {
    words_config {
      text = "delete"
    }
    words_config {
      text = "destroy"
    }
  }
}
```

**LLM behavior**: If a user asks "Delete the dev environment", the guardrail blocks it before the LLM processes it.

---

## 8. Chat Interface (User → LLM)

### `src/lambda/chat_handler.py`
**What it does**: Entry point for user requests

**Key LLM elements**:
- Receives natural language from users
- Invokes orchestrator agent's LLM
- Streams LLM response back to user

**Example**:
```python
def handler(event, context):
    message = body.get('message')  # Natural language from user
    
    # Invoke orchestrator agent's LLM
    response = bedrock_agent_runtime.invoke_agent(
        agentId=orchestrator_agent_id,
        inputText=message  # User's natural language request
    )
    
    # Stream LLM's response
    completion = ""
    for event in response.get('completion', []):
        completion += decode_chunk(event)
    
    return {'response': completion}  # LLM's natural language response
```

**LLM behavior**: User's natural language → Orchestrator LLM → Natural language response

---

## Summary: Where LLM Decisions Happen

| Component | LLM Role | Decision Type |
|-----------|----------|---------------|
| `bedrock_agents.tf` | **LLM Brain** | Defines reasoning capabilities |
| `bedrock_action_groups.tf` | **Available Tools** | LLM decides which to call |
| `bedrock_knowledge_base.tf` | **RAG Context** | LLM searches for information |
| `agent_invoker.py` | **Agent Communication** | LLM invokes other LLMs |
| `mcp_proxy.py` | **Tool Execution** | LLM calls MCP tools |
| `memory_manager.py` | **State Queries** | LLM checks deployment history |
| `bedrock_guardrails.tf` | **Safety** | Constrains LLM behavior |
| `chat_handler.py` | **User Interface** | User ↔ LLM communication |

## The LLM Decision Flow

1. **User request** → `chat_handler.py` → **Orchestrator LLM**
2. **Orchestrator LLM** searches **Knowledge Base** (RAG)
3. **Orchestrator LLM** queries **Memory** via `memory_manager.py`
4. **Orchestrator LLM** decides to invoke **Bootstrap Agent LLM** via `agent_invoker.py`
5. **Bootstrap Agent LLM** searches its **Knowledge Base** (RAG)
6. **Bootstrap Agent LLM** decides to call **MCP tool** via `mcp_proxy.py`
7. **MCP Server** executes actual pipeline
8. Results flow back through the chain
9. **Orchestrator LLM** generates final response
10. User receives natural language summary

**Every decision is made by an LLM, not hardcoded logic!**
