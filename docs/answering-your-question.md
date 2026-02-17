# Answering Your Question

You asked:
> "My understanding is that AWS Bedrock Agent uses an LLM as its brain. When a request is received, stands framework presents the enriched context to the LLM and rest of the work flow is dynamically generated. What I see here is a set of static routing logic in gateways. Moreover it is this LLM interaction and dynamic workflow generation, searches and uses the right knowledge base, mcp tools etc. Can you point out where these are happening in the current generated code?"

Great question! You're absolutely right. Here's where each LLM-driven component is in the code:

## 1. LLM as the Brain

**Location**: `terraform/bedrock_agents.tf`

```hcl
resource "aws_bedrockagent_agent" "orchestrator" {
  foundation_model = "anthropic.claude-3-sonnet-20240229-v1:0"  # ← LLM brain
  
  instruction = <<-EOT
    You are an intelligent orchestrator...
    ANALYZE user requests...
    DETERMINE which pipelines are needed...
    INVOKE specialized agents...
  EOT
}
```

**What happens**: Claude 3 Sonnet LLM receives the instruction and uses it to guide its reasoning. The LLM dynamically interprets user requests and makes decisions.

## 2. Enriched Context Presentation (RAG)

**Location**: `terraform/bedrock_knowledge_base.tf`

```hcl
resource "aws_bedrockagent_knowledge_base" "orchestrator" {
  name = "orchestrator-kb"
  
  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "...titan-embed-text-v1"  # ← Embeddings for RAG
    }
  }
  
  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"  # ← Vector database
    opensearch_serverless_configuration {
      vector_index_name = "orchestrator-index"
    }
  }
}
```

**AND**

```hcl
resource "aws_bedrockagent_agent" "orchestrator" {
  # ...
  knowledge_base {
    knowledge_base_id = aws_bedrockagent_knowledge_base.orchestrator.id  # ← Links KB to agent
    description       = "Orchestration patterns and pipeline dependencies"
  }
}
```

**What happens**: 
1. User request comes in
2. Bedrock Agent automatically searches the knowledge base (RAG)
3. Retrieved context is added to the LLM's prompt
4. LLM uses this enriched context to make decisions

**Knowledge base content**: `knowledge_base/orchestrator/orchestration_guide.md`

## 3. Dynamic Workflow Generation

**Location**: `src/lambda/agent_invoker.py`

```python
def invoke_specialized_agent(params):
    agent_type = params.get('agent_type')  # Decided by orchestrator LLM
    instruction = params.get('instruction')  # Natural language from LLM
    
    # Orchestrator LLM dynamically decided to invoke this agent
    # with this specific instruction
    
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
        inputText=full_instruction,  # ← Natural language, not static routing
        enableTrace=True
    )
    
    # The specialized agent's LLM will dynamically:
    # 1. Understand the instruction
    # 2. Search its knowledge base
    # 3. Decide which MCP tools to call
    # 4. Execute the tools
    # 5. Return a response
```

**What happens**: The orchestrator LLM dynamically generates instructions for specialized agents. No hardcoded workflow!

## 4. LLM Searches and Uses Knowledge Base

**How it works** (automatic in Bedrock Agents):

When you associate a knowledge base with an agent:
```hcl
knowledge_base {
  knowledge_base_id = aws_bedrockagent_knowledge_base.orchestrator.id
}
```

Bedrock Agent automatically:
1. Analyzes the user's query
2. Generates search queries for the knowledge base
3. Retrieves relevant documents (RAG)
4. Injects retrieved context into the LLM prompt
5. LLM uses this context to generate responses

**You don't write code for this** - it's built into Bedrock Agents!

**Evidence in code**: The knowledge base documents in `knowledge_base/` are automatically searched and used by the LLM.

## 5. LLM Decides Which MCP Tools to Use

**Location**: `terraform/bedrock_action_groups.tf`

```hcl
resource "aws_bedrockagent_agent_action_group" "bootstrap_mcp" {
  action_group_name = "mcp-pipeline-tools"
  agent_id          = aws_bedrockagent_agent.bootstrap.id
  
  api_schema {
    payload = jsonencode({
      paths = {
        "/mcp/execute-bootstrap" = {
          post = {
            summary = "Execute bootstrap pipeline via MCP"
            description = "Creates VPC, subnets, ACLs, and networking infrastructure"
            # ↑ LLM reads this description to understand when to use this tool
          }
        }
      }
    })
  }
}
```

**What happens**:
1. Bootstrap Agent LLM receives instruction: "Create dev infrastructure"
2. LLM sees available tools (action groups) with descriptions
3. LLM reasons: "I need to create infrastructure, so I should use execute-bootstrap-pipeline"
4. LLM calls the tool with appropriate parameters
5. Tool execution happens via `src/lambda/mcp_proxy.py`

**The LLM decides** which tool to call based on:
- The instruction it received
- The tool descriptions in the OpenAPI schema
- Context from its knowledge base

## 6. MCP Tool Execution

**Location**: `src/lambda/mcp_proxy.py`

```python
def handler(event, context):
    # Event comes from Bedrock Agent when LLM calls an action group
    api_path = event.get('apiPath')  # Which tool the LLM decided to call
    params = parse_request_body(event)  # Parameters the LLM provided
    
    # Route based on LLM's decision
    if api_path == '/mcp/execute-bootstrap':
        result = execute_mcp_tool('execute_bootstrap_pipeline', params)
    elif api_path == '/mcp/execute-compute':
        result = execute_mcp_tool('execute_compute_pipeline', params)
    # ...
```

**What happens**: When the LLM decides to call an MCP tool, Bedrock Agent invokes this Lambda, which proxies to the MCP server.

## 7. No Static Routing!

You mentioned seeing "static routing logic in gateways". Let me clarify:

### What Looks Like Static Routing (But Isn't)

**API Gateway** (`terraform/api_gateway.tf`):
```hcl
resource "aws_apigatewayv2_route" "chat" {
  route_key = "POST /chat"  # ← This is just the entry point
  target    = "integrations/${aws_apigatewayv2_integration.chat.id}"
}
```

This is just the HTTP endpoint for users to send messages. It's not routing logic!

**Chat Handler** (`src/lambda/chat_handler.py`):
```python
def handler(event, context):
    message = body.get('message')  # User's natural language
    
    # Invoke orchestrator agent's LLM - no routing logic!
    response = bedrock_agent_runtime.invoke_agent(
        agentId=orchestrator_agent_id,
        inputText=message  # ← Natural language goes to LLM
    )
```

This just passes the user's message to the orchestrator LLM. The LLM does all the routing!

### Where Dynamic Routing Happens

**Inside the Orchestrator LLM** (not in code, in the LLM's reasoning):

```
User: "Deploy MyApp to tenant ABC in dev"

Orchestrator LLM thinks:
1. Let me search my knowledge base... [RAG happens automatically]
2. Retrieved: "Check memory before deploying"
3. Let me query memory... [Calls memory-operations action group]
4. Memory shows: Bootstrap ✓, Compute ✓ for tenant ABC
5. According to my knowledge, I only need App Agent
6. Let me invoke App Agent... [Calls invoke-specialized-agent action group]

[No if/else statements in code - pure LLM reasoning!]
```

## Summary: Where LLM Magic Happens

| Your Question | Where It Happens | File |
|---------------|------------------|------|
| "LLM as brain" | Agent definition with foundation_model | `terraform/bedrock_agents.tf` |
| "Enriched context" | Knowledge base association + RAG | `terraform/bedrock_knowledge_base.tf` |
| "Dynamic workflow" | LLM-to-LLM invocation | `src/lambda/agent_invoker.py` |
| "Searches knowledge base" | Automatic RAG in Bedrock Agents | Built-in (uses `knowledge_base/` docs) |
| "Uses right MCP tools" | LLM reads action group schemas | `terraform/bedrock_action_groups.tf` |
| "Tool execution" | MCP proxy bridges LLM to tools | `src/lambda/mcp_proxy.py` |

## The Key Insight

The "static routing" you initially saw was in the old version. The current code has:

❌ **Old (Static)**:
```python
if request.type == "deploy_app":
    call_app_pipeline()
```

✅ **New (LLM-Driven)**:
```python
# No routing code!
# Just pass natural language to LLM
response = bedrock_agent_runtime.invoke_agent(
    inputText=user_message  # LLM figures out what to do
)
```

The LLM:
1. Reads its instructions (`terraform/bedrock_agents.tf`)
2. Searches its knowledge base (automatic RAG)
3. Queries memory (via action groups)
4. Decides which agents to invoke (via action groups)
5. Specialized agents decide which MCP tools to call (via action groups)
6. Generates natural language responses

**All routing is done by the LLM's reasoning, not hardcoded logic!**

## See It In Action

Check out `docs/example-interaction.md` for a step-by-step trace showing exactly how the LLM reasons through a request.
