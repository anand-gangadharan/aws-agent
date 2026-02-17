# Framework Comparison: Strands vs AWS Bedrock Agents

## The Confusion

You mentioned "Strands framework" - I believe you may be referring to one of these:

1. **AWS Bedrock Agents** (what this codebase uses)
2. **LangChain/LangGraph** (Python framework for LLM orchestration)
3. **Semantic Kernel** (Microsoft's framework)
4. **AutoGen** (Microsoft's multi-agent framework)

This codebase uses **AWS Bedrock Agents**, which is a managed service, not a framework.

## What This Codebase Uses

### AWS Bedrock Agents (Managed Service)

**Not a framework you install** - it's an AWS managed service.

**How it works**:
```
Your Code (Terraform) → Defines agents
AWS Bedrock → Runs orchestration
Your Lambdas → Execute tools when called
```

**Orchestration location**: Inside AWS Bedrock (managed by AWS)

**You configure it, AWS runs it.**

## Comparison with Frameworks

### If You Used LangGraph (Framework)

```python
# You would write orchestration code
from langgraph.graph import StateGraph
from langchain_aws import BedrockLLM

# Define LLM
llm = BedrockLLM(model_id="us.amazon.nova-pro-v1:0")

# Define orchestration graph
workflow = StateGraph()

# Add nodes (steps)
workflow.add_node("analyze", lambda state: analyze_request(state, llm))
workflow.add_node("check_memory", lambda state: check_memory(state))
workflow.add_node("invoke_bootstrap", lambda state: invoke_agent(state, "bootstrap"))
workflow.add_node("invoke_compute", lambda state: invoke_agent(state, "compute"))
workflow.add_node("invoke_app", lambda state: invoke_agent(state, "app"))

# Define edges (orchestration flow)
workflow.add_edge("analyze", "check_memory")
workflow.add_conditional_edges(
    "check_memory",
    lambda state: "bootstrap" if not state["bootstrap_exists"] else "compute",
    {
        "bootstrap": "invoke_bootstrap",
        "compute": "invoke_compute"
    }
)
workflow.add_edge("invoke_bootstrap", "invoke_compute")
workflow.add_edge("invoke_compute", "invoke_app")

# Compile and run
app = workflow.compile()
result = app.invoke({"request": "Deploy to dev"})
```

**Orchestration location**: Your Python code

**You write and run the orchestration logic.**

### What This Codebase Does (AWS Bedrock Agents)

```hcl
# Just define the agent
resource "aws_bedrockagent_agent" "orchestrator" {
  foundation_model = "us.amazon.nova-pro-v1:0"
  
  instruction = <<-EOT
    You are an orchestrator.
    Analyze requests, check memory, and invoke agents as needed.
  EOT
  
  # Define available tools
  # AWS Bedrock orchestrates which to call and when
}
```

**Orchestration location**: Inside AWS Bedrock (managed)

**AWS runs the orchestration based on your instructions.**

## Key Differences

| Aspect | Framework (LangGraph) | AWS Bedrock Agents |
|--------|----------------------|-------------------|
| **Orchestration Code** | You write it | AWS manages it |
| **Control Flow** | Explicit (graph/code) | Implicit (LLM decides) |
| **Deployment** | Your infrastructure | AWS managed service |
| **Flexibility** | High (code-level) | Medium (instruction-level) |
| **Determinism** | High (same input → same flow) | Low (LLM may vary) |
| **Debugging** | Standard debugging | Trace logs |
| **Cost** | Compute + LLM API calls | Bedrock Agents + LLM calls |
| **Maintenance** | You maintain code | AWS maintains service |

## Orchestration Capabilities Comparison

### LangGraph (Framework)

```python
# Explicit orchestration
def orchestrate_deployment(request):
    # Step 1: Analyze
    analysis = llm.invoke(f"Analyze: {request}")
    
    # Step 2: Check memory
    memory = check_deployment_history(analysis.environment)
    
    # Step 3: Decide
    if not memory.has_bootstrap:
        # Step 4a: Run bootstrap
        bootstrap_result = invoke_agent("bootstrap", analysis)
        
    # Step 5: Run compute
    compute_result = invoke_agent("compute", analysis)
    
    # Step 6: Run app
    app_result = invoke_agent("app", analysis)
    
    # Step 7: Synthesize
    return synthesize_results([bootstrap_result, compute_result, app_result])
```

**Pros**:
- ✅ Explicit control flow
- ✅ Easy to debug
- ✅ Deterministic
- ✅ Can add complex logic

**Cons**:
- ❌ You write orchestration code
- ❌ You maintain the code
- ❌ Less flexible (hardcoded flow)
- ❌ You deploy and scale it

### AWS Bedrock Agents (This Codebase)

```hcl
# Implicit orchestration via LLM
resource "aws_bedrockagent_agent" "orchestrator" {
  instruction = "Analyze requests, check memory, invoke agents as needed."
  
  # LLM figures out the orchestration flow
}
```

**Pros**:
- ✅ No orchestration code to write
- ✅ LLM adapts to context
- ✅ Handles edge cases automatically
- ✅ AWS manages scaling

**Cons**:
- ❌ Less explicit control
- ❌ Harder to debug (LLM black box)
- ❌ Non-deterministic
- ❌ Dependent on LLM quality

## Where Orchestration Happens in This Codebase

### 1. Agent Instructions (Orchestration Guidance)

**File**: `terraform/bedrock_agents.tf`

```hcl
instruction = <<-EOT
  You are an intelligent orchestrator. Your role is to:
  
  1. ANALYZE user requests to understand what infrastructure or applications they need
  2. QUERY the memory system to check deployment history
  3. DETERMINE which pipelines are needed based on:
     - What already exists (from memory)
     - What the user is requesting
     - Pipeline dependencies (Bootstrap → Compute → App)
  4. INVOKE specialized agents in the correct order
  5. COORDINATE the workflow by waiting for each agent to complete
  6. REPORT back to the user with status and results
EOT
```

**This is orchestration guidance, not code.**

The LLM reads this and orchestrates accordingly.

### 2. Action Groups (Orchestration Tools)

**File**: `terraform/bedrock_action_groups.tf`

```hcl
# Tool 1: Invoke other agents
resource "aws_bedrockagent_agent_action_group" "orchestrator_delegate" {
  action_group_name = "invoke-specialized-agent"
  # LLM calls this to orchestrate multi-agent workflow
}

# Tool 2: Query memory
resource "aws_bedrockagent_agent_action_group" "orchestrator_memory" {
  action_group_name = "memory-operations"
  # LLM calls this to inform orchestration decisions
}
```

**The LLM orchestrates which tools to call and when.**

### 3. Agent Invoker (Multi-Agent Orchestration)

**File**: `src/lambda/agent_invoker.py`

```python
def invoke_specialized_agent(params):
    """
    Called by orchestrator LLM to delegate to specialized agents.
    This enables multi-agent orchestration.
    """
    agent_type = params.get('agent_type')
    instruction = params.get('instruction')
    
    # Invoke the specialized agent
    # AWS Bedrock orchestrates the specialized agent's workflow
    response = bedrock_agent_runtime.invoke_agent(
        agentId=AGENT_IDS[agent_type],
        inputText=instruction
    )
    
    return response
```

**This is a tool, not orchestration logic.**

The orchestrator LLM decides when to call this.

## Real Orchestration Example

### User Request
"Deploy MyApp to tenant ABC in dev"

### LangGraph Approach (Explicit)
```python
def orchestrate(request):
    # Hardcoded orchestration flow
    env = extract_environment(request)  # "dev"
    tenant = extract_tenant(request)    # "ABC"
    
    # Check memory
    memory = query_memory(env, tenant)
    
    # Explicit decision tree
    if not memory.has_bootstrap(env):
        invoke_agent("bootstrap", env)
    
    if not memory.has_compute(env, tenant):
        invoke_agent("compute", env, tenant)
    
    # Always deploy app
    invoke_agent("app", env, tenant, "MyApp")
    
    return "Deployed successfully"
```

### AWS Bedrock Agents Approach (Implicit)
```
User: "Deploy MyApp to tenant ABC in dev"
    ↓
Orchestrator LLM thinks:
  "Let me analyze this request...
   User wants to deploy MyApp to tenant ABC in dev.
   
   Let me check my knowledge base...
   [RAG search: "deployment requirements"]
   Retrieved: 'Check memory before deploying'
   
   Let me query memory...
   [Calls memory-operations action group]
   Result: Bootstrap exists, Compute exists for ABC
   
   Based on my knowledge and memory:
   - Bootstrap: Already exists ✓
   - Compute: Already exists for ABC ✓
   - App: Need to deploy
   
   I should invoke only the App Agent.
   
   [Calls invoke-specialized-agent action group]
   agent_type: 'app'
   instruction: 'Deploy MyApp to tenant ABC in dev'
   
   [Waits for App Agent to complete]
   
   App Agent completed successfully.
   
   Let me generate a response for the user..."
    ↓
User: "Successfully deployed MyApp to tenant ABC in dev..."
```

**No orchestration code - the LLM orchestrates based on instructions and context!**

## Summary

### This Codebase Does NOT Use a Framework

It uses **AWS Bedrock Agents**, a managed service that provides:
- ✅ LLM-driven orchestration
- ✅ Built-in RAG (knowledge base)
- ✅ Action groups (tools)
- ✅ Multi-agent coordination
- ✅ Memory and state management

### Orchestration Happens In

1. **AWS Bedrock Agents** (managed by AWS)
   - LLM reasoning and planning
   - Tool selection and execution
   - Multi-turn conversations

2. **Your Configuration** (`terraform/bedrock_agents.tf`)
   - Agent instructions (guidance)
   - Action groups (available tools)
   - Knowledge bases (RAG context)

3. **Your Lambdas** (tool implementations)
   - `agent_invoker.py` - Multi-agent coordination
   - `memory_manager.py` - State queries
   - `mcp_proxy.py` - Pipeline execution

### If You Want Framework-Based Orchestration

Consider adding:
- **LangGraph** for explicit Python-based orchestration
- **AWS Step Functions** for state machine orchestration
- **Custom orchestration logic** in Lambda

But AWS Bedrock Agents' LLM-driven orchestration is often more flexible and requires less code!

## Recommendation

**For POC**: Stick with AWS Bedrock Agents
- Less code to write and maintain
- More flexible (LLM adapts to context)
- Sufficient for most use cases

**For Production**: Consider hybrid approach
- AWS Bedrock Agents for high-level orchestration
- Step Functions for critical deterministic workflows
- LangGraph for complex multi-step reasoning

The choice depends on your need for control vs flexibility!
