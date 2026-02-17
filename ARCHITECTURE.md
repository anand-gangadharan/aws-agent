# Architecture Overview

## How the LLM-Driven Workflow Works

This solution leverages AWS Bedrock Agents' LLM capabilities for dynamic, intelligent orchestration. Here's how it works:

### 1. User Request Flow

```
User → API Gateway → Chat Handler Lambda → Orchestrator Agent (LLM)
```

The orchestrator agent receives natural language requests like:
- "Deploy a new dev environment for tenant ABC"
- "Add compute resources for tenant XYZ in prod"
- "Deploy app MyApp version 2.0 to tenant ABC"

### 2. Orchestrator Agent (LLM Brain)

The orchestrator agent has:
- **Foundation Model**: AWS Nova Pro (optimized for agent tasks)
- **Instructions**: High-level guidance on pipeline dependencies and decision-making
- **Knowledge Base**: RAG-enabled access to orchestration patterns (S3 vector store)
- **Action Groups**: 
  - `invoke-specialized-agent`: Delegate to Bootstrap/Compute/App agents
  - `memory-operations`: Query/store deployment history

**The LLM dynamically**:
1. Analyzes the user's natural language request
2. Queries the knowledge base for relevant orchestration patterns
3. Checks memory (DynamoDB) for deployment history
4. Determines which agents to invoke and in what order
5. Invokes specialized agents with natural language instructions
6. Waits for responses and coordinates the workflow
7. Returns results to the user

### 3. Specialized Agents (Bootstrap/Compute/App)

Each specialized agent has:
- **Foundation Model**: AWS Nova Pro
- **Instructions**: Domain-specific guidance for their pipeline type
- **Knowledge Base**: RAG-enabled access to pipeline-specific documentation (S3 vector store)
- **Action Groups (MCP Tools)**:
  - `execute-bootstrap-pipeline` / `execute-compute-pipeline` / `execute-app-pipeline`
  - `get-pipeline-status`

**When invoked by the orchestrator, the LLM**:
1. Understands the natural language instruction from orchestrator
2. Searches its knowledge base for pipeline details and best practices
3. Decides which MCP tools to call and with what parameters
4. Executes the MCP tools (actual pipeline execution)
5. Monitors execution status
6. Stores results in memory
7. Returns a natural language response to the orchestrator

### 4. MCP Server (Pipeline Execution Runtime)

The MCP server runs independently and provides tools that agents can call:
- `execute_bootstrap_pipeline`: Creates VPC, subnets, networking
- `execute_compute_pipeline`: Provisions EC2 instances
- `execute_app_pipeline`: Deploys applications
- `get_pipeline_status`: Checks execution status

**Key Point**: The MCP server is called by agents when their LLM decides it's appropriate, not through static routing.

### 5. Knowledge Bases (RAG)

Each agent has its own knowledge base stored in S3 with vector embeddings:

- **Orchestrator KB**: Orchestration patterns, pipeline dependencies, decision trees
- **Bootstrap KB**: VPC design, networking best practices, bootstrap procedures
- **Compute KB**: EC2 sizing, multi-tenant isolation, compute provisioning
- **App KB**: Deployment patterns, application types, health checks

**Vector Store**: S3 (simpler for POC, no OpenSearch Serverless needed)
**Embeddings**: Amazon Titan Embeddings v2

**The LLM automatically**:
- Searches the knowledge base when it needs information
- Uses retrieved context to make better decisions
- Generates responses grounded in the documentation

### 6. Memory (Short-term State)

DynamoDB stores deployment history with GSIs for querying by:
- Environment (dev/prod)
- Tenant ID
- Timestamp

**The orchestrator LLM**:
- Queries memory before making decisions
- Checks if bootstrap exists before running compute
- Verifies compute exists before deploying apps
- Avoids redundant deployments

### 7. Guardrails

The guardrail prevents deprovisioning by:
- Blocking words like "delete", "destroy", "deprovision", "remove"
- Applied to the orchestrator agent
- Ensures safety without hardcoded logic

## Example Flow: "Deploy dev environment for tenant ABC"

1. **User sends request** via API Gateway
2. **Chat Handler** invokes Orchestrator Agent
3. **Orchestrator LLM**:
   - Searches its knowledge base: "What's needed for new environment?"
   - Queries memory: "Does dev bootstrap exist?"
   - Decides: "Need Bootstrap → Compute → App"
   - Invokes Bootstrap Agent with instruction: "Create bootstrap infrastructure for dev environment"
4. **Bootstrap Agent LLM**:
   - Searches its knowledge base: "What does bootstrap create?"
   - Decides to call MCP tool: `execute_bootstrap_pipeline`
   - Calls `mcp_proxy` Lambda → MCP Server
   - MCP Server executes actual pipeline
   - Stores result in memory
   - Returns: "Bootstrap completed, VPC vpc-123 created"
5. **Orchestrator receives response**, then invokes Compute Agent
6. **Compute Agent LLM**:
   - Searches its knowledge base: "How to provision EC2 for tenant?"
   - Calls MCP tool: `execute_compute_pipeline` with tenant_id=ABC
   - Returns: "Compute provisioned, 2 instances created"
7. **Orchestrator receives response**, then invokes App Agent
8. **App Agent LLM**:
   - Searches its knowledge base: "How to deploy applications?"
   - Calls MCP tool: `execute_app_pipeline`
   - Returns: "App deployed successfully"
9. **Orchestrator** returns final summary to user

## Key Differences from Static Routing

❌ **Static Routing** (what was initially generated):
- Hardcoded if/else logic
- Fixed API paths
- No LLM decision-making
- No knowledge base usage

✅ **LLM-Driven** (current architecture):
- Natural language understanding
- Dynamic decision-making by LLM
- RAG-enabled knowledge retrieval
- Agents invoke other agents via Bedrock
- MCP tools called when LLM decides
- Memory queried dynamically
- Flexible, adaptable workflows

## Where the Magic Happens

1. **Agent Instructions** (`terraform/bedrock_agents.tf`): Guide the LLM's behavior
2. **Knowledge Bases** (`terraform/bedrock_knowledge_base.tf`): Provide RAG context
3. **Action Groups** (`terraform/bedrock_action_groups.tf`): Define available tools
4. **Agent Invoker** (`src/lambda/agent_invoker.py`): Enables agent-to-agent calls
5. **MCP Proxy** (`src/lambda/mcp_proxy.py`): Bridges agents to MCP tools
6. **Memory Operations** (`src/lambda/memory_manager.py`): Provides state to LLM

The LLM orchestrates everything dynamically based on context, instructions, and available tools!
