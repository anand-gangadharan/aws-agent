# LLM-Driven Workflow Details

## Request Flow with LLM Decision Making

```
┌─────────────────────────────────────────────────────────────────────┐
│                         USER REQUEST                                 │
│  "Deploy a new dev environment for tenant ABC with MyApp"           │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      API GATEWAY + LAMBDA                            │
│  Receives request, invokes Orchestrator Agent                       │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    ORCHESTRATOR AGENT (LLM)                          │
│  Foundation Model: Claude 3 Sonnet                                   │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────┐        │
│  │ LLM REASONING PROCESS:                                  │        │
│  │                                                          │        │
│  │ 1. Parse request: "new dev environment + tenant + app"  │        │
│  │                                                          │        │
│  │ 2. Search Knowledge Base (RAG):                         │        │
│  │    Query: "What's needed for new environment?"          │        │
│  │    Retrieved: "Bootstrap → Compute → App sequence"      │        │
│  │                                                          │        │
│  │ 3. Query Memory (via action group):                     │        │
│  │    Check: "Does dev bootstrap exist?"                   │        │
│  │    Result: "No bootstrap found for dev"                 │        │
│  │                                                          │        │
│  │ 4. Decision: Need all three pipelines in order          │        │
│  │                                                          │        │
│  │ 5. Plan execution:                                       │        │
│  │    Step 1: Invoke Bootstrap Agent                       │        │
│  │    Step 2: Wait for completion                          │        │
│  │    Step 3: Invoke Compute Agent                         │        │
│  │    Step 4: Wait for completion                          │        │
│  │    Step 5: Invoke App Agent                             │        │
│  └─────────────────────────────────────────────────────────┘        │
│                                                                       │
│  Available Tools (Action Groups):                                    │
│  • invoke-specialized-agent (agent_invoker Lambda)                   │
│  • memory-operations (memory_manager Lambda)                         │
│                                                                       │
│  Knowledge Base: orchestrator/ (S3 + OpenSearch)                     │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             │ LLM decides to invoke Bootstrap Agent
                             │ Calls: invoke-specialized-agent action
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   AGENT INVOKER LAMBDA                               │
│  Receives: agent_type="bootstrap", instruction="Create dev infra"   │
│  Invokes: Bootstrap Agent via bedrock:InvokeAgent                   │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    BOOTSTRAP AGENT (LLM)                             │
│  Foundation Model: Claude 3 Sonnet                                   │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────┐        │
│  │ LLM REASONING PROCESS:                                  │        │
│  │                                                          │        │
│  │ 1. Understand instruction: "Create dev infrastructure"  │        │
│  │                                                          │        │
│  │ 2. Search Knowledge Base (RAG):                         │        │
│  │    Query: "What does bootstrap create?"                 │        │
│  │    Retrieved: "VPC, subnets, IGW, NAT, ACLs, SGs"      │        │
│  │                                                          │        │
│  │ 3. Decision: Use MCP tool to execute pipeline           │        │
│  │                                                          │        │
│  │ 4. Call action: execute-bootstrap-pipeline              │        │
│  │    Parameters: {environment: "dev", region: "us-east-1"}│        │
│  └─────────────────────────────────────────────────────────┘        │
│                                                                       │
│  Available Tools (Action Groups):                                    │
│  • execute-bootstrap-pipeline (mcp_proxy Lambda)                     │
│  • get-pipeline-status (mcp_proxy Lambda)                            │
│                                                                       │
│  Knowledge Base: bootstrap/ (S3 + OpenSearch)                        │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             │ LLM calls MCP tool
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      MCP PROXY LAMBDA                                │
│  Receives: execute-bootstrap-pipeline request                        │
│  Forwards to: MCP Server HTTP endpoint                               │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       MCP SERVER                                     │
│  Executes actual pipeline:                                           │
│  • Creates VPC                                                       │
│  • Creates subnets                                                   │
│  • Configures ACLs                                                   │
│  Returns: {execution_id: "abc-123", status: "completed"}            │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             │ Result flows back
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      MCP PROXY LAMBDA                                │
│  Stores result in DynamoDB (memory)                                  │
│  Returns result to Bootstrap Agent                                   │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    BOOTSTRAP AGENT (LLM)                             │
│  Receives execution result                                           │
│  Generates response: "Bootstrap completed. VPC vpc-123 created."     │
│  Returns to Orchestrator                                             │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    ORCHESTRATOR AGENT (LLM)                          │
│  Receives Bootstrap completion                                       │
│  LLM decides: "Now invoke Compute Agent"                             │
│  Calls: invoke-specialized-agent with agent_type="compute"           │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
                    [Similar flow for Compute Agent]
                             │
                             ▼
                    [Similar flow for App Agent]
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    ORCHESTRATOR AGENT (LLM)                          │
│  All agents completed                                                │
│  Generates final response:                                           │
│  "Successfully deployed dev environment for tenant ABC:              │
│   - Bootstrap: VPC vpc-123 created                                   │
│   - Compute: 2 EC2 instances (i-abc, i-def)                         │
│   - App: MyApp v1.0 deployed and healthy"                           │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         USER RESPONSE                                │
│  Receives comprehensive deployment summary                           │
└─────────────────────────────────────────────────────────────────────┘
```

## Key LLM Decision Points

### 1. Orchestrator Agent LLM Decisions
- **What pipelines are needed?** (based on request analysis + memory query)
- **What order to execute?** (based on knowledge base retrieval)
- **Should I skip any steps?** (based on memory - already deployed)
- **How to handle errors?** (based on agent responses)

### 2. Specialized Agent LLM Decisions
- **Which MCP tool to call?** (based on instruction + knowledge base)
- **What parameters to use?** (based on instruction parsing)
- **Should I wait for completion?** (based on pipeline type)
- **How to report results?** (based on execution outcome)

## Knowledge Base Usage (RAG)

Each agent's LLM automatically searches its knowledge base when needed:

```python
# This happens automatically inside Bedrock Agent
# The LLM decides when to search based on the query

Orchestrator KB Search:
  Query: "pipeline dependencies"
  Retrieved: "Bootstrap must run before Compute..."
  
Bootstrap KB Search:
  Query: "VPC configuration best practices"
  Retrieved: "Use /16 CIDR for VPC, /24 for subnets..."
  
Compute KB Search:
  Query: "EC2 instance sizing for tenant workloads"
  Retrieved: "t3.medium for dev, m5.large for prod..."
```

## Memory Query Examples

The orchestrator LLM queries memory to make informed decisions:

```python
# Memory query via action group
Query: {environment: "dev"}
Response: [
  {pipeline_type: "bootstrap", status: "completed", timestamp: ...},
  {pipeline_type: "compute", tenant_id: "ABC", status: "completed", ...}
]

# LLM reasoning:
# "Bootstrap exists for dev, so I can skip it"
# "Compute exists for tenant ABC, so I can skip it"
# "Only need to run App pipeline"
```

## No Static Routing!

The key difference from traditional systems:

❌ **Traditional (Static)**:
```python
if request.type == "new_environment":
    run_bootstrap()
    run_compute()
    run_app()
```

✅ **LLM-Driven (Dynamic)**:
```
LLM analyzes request → searches knowledge base → queries memory → 
decides what's needed → invokes appropriate agents → 
agents use their LLMs to decide which tools to call → 
orchestrator coordinates based on responses
```

The entire workflow is emergent from the LLM's reasoning, not hardcoded logic!
