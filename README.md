# AWS Bedrock Agent CICD Orchestrator

A multi-agent system for orchestrating CICD pipelines using AWS Bedrock Agents with LLM-driven decision making.

## Architecture

This solution uses **LLM-driven orchestration** where agents dynamically decide what to do based on:
- Natural language instructions
- Knowledge base searches (RAG)
- Deployment history (memory)
- Available tools (MCP server)

### Agents

- **Orchestrator Agent**: LLM analyzes requests, queries memory, and delegates to specialized agents
- **Bootstrap Agent**: LLM uses knowledge base and MCP tools to create VPC/networking infrastructure
- **Compute Agent**: LLM provisions EC2 instances for tenants using MCP tools
- **App Agent**: LLM deploys applications to EC2 using MCP tools

### Components

- **AWS Bedrock Agents**: AWS Nova Pro as the brain for each agent
- **Knowledge Bases**: S3 vector store for RAG (one per agent) - simpler for POC
- **MCP Server**: Custom runtime that executes actual pipelines
- **DynamoDB**: Short-term memory for deployment history and state
- **Guardrails**: Prevents deprovisioning operations
- **API Gateway**: Chat interface for user interactions

## How It Works

1. **User sends natural language request** (e.g., "Deploy dev environment for tenant ABC")
2. **Orchestrator Agent LLM**:
   - Searches its knowledge base for orchestration patterns
   - Queries memory to check what's already deployed
   - Decides which agents to invoke and in what order
   - Invokes specialized agents with natural language instructions
3. **Specialized Agent LLM** (Bootstrap/Compute/App):
   - Searches its knowledge base for pipeline details
   - Decides which MCP tools to call
   - Executes MCP tools (actual pipeline execution)
   - Stores results in memory
   - Returns response to orchestrator
4. **Orchestrator coordinates** the entire workflow and reports back to user

**No static routing** - the LLM dynamically orchestrates based on context!

See [QUICK_START.md](QUICK_START.md) for step-by-step setup instructions.

See [POC_OPTIMIZATIONS.md](POC_OPTIMIZATIONS.md) for details on POC-specific optimizations (S3 vector store, Nova Pro).

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed flow diagrams.

## Project Structure

See [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) for detailed file organization and component explanations.

## Prerequisites

- Python 3.11+
- Terraform 1.5+
- AWS CLI configured
- AWS Bedrock model access (Nova Pro, Titan Embeddings v2)

## Setup

1. Deploy infrastructure: `cd terraform && terraform init && terraform apply`
2. Upload knowledge base documents to S3
3. Start MCP server: `cd src/mcp_server && python http_server.py`
4. Test via API Gateway endpoint

## Documentation

- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)**: Quick reference card for daily development
- **[DEVELOPMENT_GUIDE.md](DEVELOPMENT_GUIDE.md)**: Complete guide for deployment, testing, updates, and debugging
- **[QUICK_START.md](QUICK_START.md)**: Step-by-step setup guide (start here!)
- **[POC_OPTIMIZATIONS.md](POC_OPTIMIZATIONS.md)**: POC-specific optimizations (S3 vector, Nova Pro)
- **[CHANGES_FOR_POC.md](CHANGES_FOR_POC.md)**: What changed from the original design
- **[docs/answering-your-question.md](docs/answering-your-question.md)**: Direct answer to "where is the LLM orchestration happening?"
- **[docs/visual-summary.md](docs/visual-summary.md)**: Visual diagrams of the LLM-driven architecture
- **[ARCHITECTURE.md](ARCHITECTURE.md)**: High-level architecture and LLM workflow explanation
- **[docs/llm-workflow.md](docs/llm-workflow.md)**: Detailed flow diagrams showing LLM decision points
- **[docs/component-mapping.md](docs/component-mapping.md)**: Maps each file to its role in LLM orchestration
- **[docs/example-interaction.md](docs/example-interaction.md)**: Concrete example showing LLM reasoning step-by-step
- **[docs/mcp-architecture.md](docs/mcp-architecture.md)**: MCP server architecture and Lambda integration
- **[docs/lambda-mcp-flow.md](docs/lambda-mcp-flow.md)**: Visual flow of Lambda and MCP communication
- **[PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)**: Complete file organization reference

## Key Concepts

### LLM-Driven vs Static Routing

This solution uses **LLM-driven orchestration** where agents make dynamic decisions:

✅ **What happens**:
- Orchestrator LLM analyzes natural language requests
- Searches knowledge base for relevant patterns (RAG)
- Queries memory to check deployment history
- Dynamically decides which agents to invoke
- Specialized agents use their LLMs to decide which MCP tools to call
- No hardcoded if/else logic

❌ **What doesn't happen**:
- Static routing based on request types
- Hardcoded pipeline sequences
- Fixed API paths determining behavior

### Where LLM Decisions Occur

1. **Agent Instructions** (`terraform/bedrock_agents.tf`): Guide LLM reasoning
2. **Knowledge Bases** (`terraform/bedrock_knowledge_base.tf`): Provide RAG context
3. **Action Groups** (`terraform/bedrock_action_groups.tf`): Tools LLM can choose to call
4. **Agent Invoker** (`src/lambda/agent_invoker.py`): LLM-to-LLM communication
5. **MCP Proxy** (`src/lambda/mcp_proxy.py`): LLM calls actual pipeline tools
6. **Memory Manager** (`src/lambda/memory_manager.py`): LLM queries deployment state

## Environment Variables

See `.env.example` for required configuration.
