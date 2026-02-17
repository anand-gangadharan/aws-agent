# Orchestration in This Solution

## Important Clarification

**This codebase does NOT use the Strands framework.** 

The orchestration capabilities come from **AWS Bedrock Agents** native features.

## Where Orchestration Happens

### 1. AWS Bedrock Agents (Built-in Orchestration)

**Location**: Managed by AWS, configured in `terraform/bedrock_agents.tf`

AWS Bedrock Agents provides orchestration out-of-the-box:

```hcl
resource "aws_bedrockagent_agent" "orchestrator" {
  agent_name       = "cicd-orchestrator"
  foundation_model = "us.amazon.nova-pro-v1:0"
  
  instruction = <<-EOT
    You are an intelligent orchestrator...
    ANALYZE user requests...
    QUERY memory...
    INVOKE specialized agents...
  EOT
  
  # Knowledge base for RAG
  knowledge_base {
    knowledge_base_id = aws_bedrockagent_knowledge_base.orchestrator.id
  }
  
  # Guardrails for safety
  guardrail_configuration {
    guardrail_identifier = aws_bedrock_guardrail.main.guardrail_id
  }
}
```

**What AWS Bedrock Agents orchestrates automatically**:
- ✅ LLM reasoning and planning
- ✅ Knowledge base searches (RAG)
- ✅ Action group (tool) selection and execution
- ✅ Multi-turn conversations with memory
- ✅ Response generation
- ✅ Trace and observability

**You don't write orchestration code - AWS does it for you!**

### 2. Action Groups (Tool Orchestration)

**Location**: `terraform/bedrock_action_groups.tf`

Action groups define tools the LLM can orchestrate:

```hcl
resource "aws_bedrockagent_agent_action_group" "orchestrator_delegate" {
  action_group_name = "invoke-specialized-agent"
  agent_id          = aws_bedrockagent_agent.orchestrator.id
  
  # Lambda that executes when LLM calls this tool
  action_group_executor {
    lambda = aws_lambda_function.agent_invoker.arn
  }
  
  # OpenAPI schema describing the tool
  api_schema {
    payload = jsonencode({
      paths = {
        "/invoke-agent" = {
          post = {
            description = "Delegate work to Bootstrap, Compute, or App agent"
            # LLM reads this to decide when to use this tool
          }
        }
      }
    })
  }
}
```

**Orchestration flow**:
1. LLM receives user request
2. LLM decides which action group to call (orchestration decision)
3. AWS invokes the Lambda function
4. Lambda executes the tool
5. Result returns to LLM
6. LLM continues orchestrating based on result

### 3. Agent-to-Agent Orchestration

**Location**: `src/lambda/agent_invoker.py`

This enables the orchestrator to invoke other agents:

```python
def invoke_specialized_agent(params):
    """
    Orchestrator LLM calls this to delegate to specialized agents.
    This is agent-to-agent orchestration.
    """
    agent_type = params.get('agent_type')  # bootstrap, compute, or app
    instruction = params.get('instruction')  # Natural language task
    
    # Get the target agent ID
    agent_id = AGENT_IDS.get(agent_type)
    
    # Invoke the specialized agent's LLM
    # AWS Bedrock orchestrates the specialized agent's workflow
    response = bedrock_agent_runtime.invoke_agent(
        agentId=agent_id,
        sessionId=session_id,
        inputText=instruction,  # Natural language instruction
        enableTrace=True
    )
    
    # AWS Bedrock orchestrates:
    # - LLM reasoning
    # - Knowledge base searches
    # - Tool selection and execution
    # - Response generation
    
    return collect_response(response)
```

**This is multi-agent orchestration without a framework!**

### 4. Memory-Based Orchestration

**Location**: `src/lambda/memory_manager.py`

The orchestrator queries memory to make informed decisions:

```python
def query_memory(params):
    """
    Orchestrator LLM calls this to check deployment history.
    Memory informs orchestration decisions.
    """
    environment = params.get('environment')
    
    # Query DynamoDB for deployment history
    response = memory_table.query(
        IndexName='environment-index',
        KeyConditionExpression=Key('environment').eq(environment)
    )
    
    # Return history to LLM
    # LLM uses this to orchestrate workflow
    # e.g., "Bootstrap exists, skip to Compute"
    return {'deployments': response.get('Items', [])}
```

**Orchestration decision example**:
```
LLM queries memory → Sees bootstrap exists → Decides to skip bootstrap → 
Invokes only compute and app agents
```

## Orchestration Capabilities Breakdown

### What AWS Bedrock Agents Orchestrates

| Capability | How It Works | Where Configured |
|------------|--------------|------------------|
| **LLM Reasoning** | Nova Pro analyzes requests and plans | `bedrock_agents.tf` (instructions) |
| **RAG Search** | Automatic knowledge base queries | `bedrock_knowledge_base.tf` |
| **Tool Selection** | LLM chooses which action groups to call | `bedrock_action_groups.tf` |
| **Multi-Agent** | Orchestrator invokes specialized agents | `agent_invoker.py` |
| **Memory Queries** | LLM checks deployment history | `memory_manager.py` |
| **Sequential Execution** | LLM waits for results before next step | Built into Bedrock Agents |
| **Error Handling** | LLM adapts based on tool responses | Built into Bedrock Agents |
| **Response Generation** | LLM synthesizes final answer | Built into Bedrock Agents |

### Orchestration Flow Example

```
User: "Deploy to new dev environment for tenant ABC"
    ↓
┌─────────────────────────────────────────────────────────┐
│ AWS Bedrock Agents Orchestration (Automatic)            │
│                                                          │
│ 1. LLM analyzes request                                 │
│    → Understands: new environment + tenant + deploy     │
│                                                          │
│ 2. LLM searches knowledge base (RAG)                    │
│    → Retrieves: "New env needs Bootstrap→Compute→App"   │
│                                                          │
│ 3. LLM calls memory-operations action group             │
│    → Checks: Does dev bootstrap exist?                  │
│    → Result: No bootstrap found                         │
│                                                          │
│ 4. LLM decides: Need all three pipelines                │
│                                                          │
│ 5. LLM calls invoke-specialized-agent action group      │
│    → Invokes: Bootstrap Agent                           │
│    → Waits for completion                               │
│                                                          │
│ 6. Bootstrap Agent completes                            │
│    → LLM receives: "Bootstrap done, VPC created"        │
│                                                          │
│ 7. LLM calls invoke-specialized-agent again             │
│    → Invokes: Compute Agent for tenant ABC              │
│    → Waits for completion                               │
│                                                          │
│ 8. Compute Agent completes                              │
│    → LLM receives: "Compute done, 2 instances"          │
│                                                          │
│ 9. LLM calls invoke-specialized-agent again             │
│    → Invokes: App Agent for tenant ABC                  │
│    → Waits for completion                               │
│                                                          │
│ 10. App Agent completes                                 │
│     → LLM receives: "App deployed successfully"         │
│                                                          │
│ 11. LLM generates final response                        │
│     → Synthesizes all results into user-friendly answer │
└─────────────────────────────────────────────────────────┘
    ↓
User receives: "Successfully deployed dev environment..."
```

**All orchestration happens inside AWS Bedrock Agents - no framework needed!**

## Why No Framework?

AWS Bedrock Agents provides orchestration capabilities that would typically require a framework:

### Traditional Approach (With Framework)
```python
# You would write orchestration code like:
from strands import Agent, Orchestrator

orchestrator = Orchestrator()

@orchestrator.task
def deploy_environment(env, tenant):
    # Manual orchestration logic
    if not check_bootstrap(env):
        bootstrap_result = run_bootstrap(env)
    
    compute_result = run_compute(env, tenant)
    app_result = run_app(env, tenant)
    
    return synthesize_results(bootstrap_result, compute_result, app_result)
```

### AWS Bedrock Agents Approach (No Framework)
```hcl
# Just define the agent with instructions
resource "aws_bedrockagent_agent" "orchestrator" {
  instruction = "You are an orchestrator. Analyze requests and invoke agents as needed."
  
  # AWS handles all orchestration automatically
}
```

**The LLM IS the orchestrator!**

## If You Want Strands-Like Capabilities

If you're looking for explicit framework-based orchestration similar to Strands, you have options:

### Option 1: Use LangGraph (Python Framework)

```python
from langgraph.graph import StateGraph, END

# Define orchestration graph
workflow = StateGraph()

workflow.add_node("analyze", analyze_request)
workflow.add_node("check_memory", check_deployment_history)
workflow.add_node("bootstrap", run_bootstrap_agent)
workflow.add_node("compute", run_compute_agent)
workflow.add_node("app", run_app_agent)

# Define edges (orchestration flow)
workflow.add_conditional_edges(
    "check_memory",
    should_run_bootstrap,
    {
        "yes": "bootstrap",
        "no": "compute"
    }
)

workflow.set_entry_point("analyze")
```

### Option 2: Use AWS Step Functions

```json
{
  "Comment": "CICD Pipeline Orchestration",
  "StartAt": "CheckMemory",
  "States": {
    "CheckMemory": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:memory-manager",
      "Next": "DecideBootstrap"
    },
    "DecideBootstrap": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.bootstrapExists",
          "BooleanEquals": false,
          "Next": "RunBootstrap"
        }
      ],
      "Default": "RunCompute"
    },
    "RunBootstrap": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:...:bootstrap-agent",
      "Next": "RunCompute"
    }
  }
}
```

### Option 3: Keep AWS Bedrock Agents (Recommended)

**Why?**
- ✅ LLM-driven orchestration (more flexible)
- ✅ Natural language understanding
- ✅ Adapts to context dynamically
- ✅ No orchestration code to maintain
- ✅ Built-in RAG, memory, tools
- ✅ Handles edge cases automatically

**Trade-offs**:
- ❌ Less explicit control flow
- ❌ Harder to debug (LLM is a black box)
- ❌ Non-deterministic (LLM may vary)

## Summary

### Where Orchestration Happens in This Codebase

1. **AWS Bedrock Agents** (managed service)
   - LLM reasoning and planning
   - Tool selection and execution
   - Multi-turn conversations
   - Response generation

2. **Action Groups** (`terraform/bedrock_action_groups.tf`)
   - Define available tools
   - LLM orchestrates which to call

3. **Agent Invoker** (`src/lambda/agent_invoker.py`)
   - Enables multi-agent orchestration
   - Orchestrator → Specialized agents

4. **Memory Manager** (`src/lambda/memory_manager.py`)
   - Provides state for orchestration decisions
   - LLM queries to inform workflow

### Key Insight

**You don't use a framework because AWS Bedrock Agents IS the orchestration engine.**

The LLM orchestrates:
- What to do (based on instructions and knowledge base)
- When to do it (based on memory and context)
- How to do it (by calling action groups)
- What to say (by generating responses)

This is **LLM-native orchestration** - more flexible than traditional frameworks but less explicit in control flow.

## If You Need More Control

If you need explicit orchestration logic (like Strands would provide), consider:

1. **Add Step Functions** for deterministic workflows
2. **Use LangGraph** for graph-based orchestration
3. **Implement custom orchestration** in Lambda with explicit logic

But for most use cases, AWS Bedrock Agents' built-in orchestration is sufficient and more flexible!
