# Project Structure

```
.
├── README.md                           # Project overview
├── ARCHITECTURE.md                     # Architecture explanation
├── PROJECT_STRUCTURE.md               # This file
├── .env.example                       # Environment variables template
├── .gitignore                         # Git ignore rules
├── requirements.txt                   # Python dependencies
│
├── docs/                              # Detailed documentation
│   ├── answering-your-question.md     # Where LLM orchestration happens
│   ├── llm-workflow.md                # LLM decision flow diagrams
│   ├── component-mapping.md           # File-to-function mapping
│   └── example-interaction.md         # Step-by-step example
│
├── terraform/                         # Infrastructure as Code
│   ├── main.tf                        # Provider configuration
│   ├── variables.tf                   # Input variables
│   ├── outputs.tf                     # Output values
│   │
│   ├── bedrock_agents.tf              # ⭐ LLM BRAINS - Agent definitions
│   ├── bedrock_action_groups.tf       # ⭐ TOOLS - What LLMs can call
│   ├── bedrock_knowledge_base.tf      # ⭐ RAG - Knowledge bases for context
│   ├── bedrock_guardrails.tf          # Safety constraints on LLMs
│   │
│   ├── lambda.tf                      # Lambda function definitions
│   ├── iam.tf                         # IAM roles and policies
│   ├── s3.tf                          # S3 buckets for knowledge bases
│   ├── dynamodb.tf                    # DynamoDB for memory/state
│   └── api_gateway.tf                 # HTTP API for chat interface
│
├── src/                               # Python source code
│   ├── lambda/                        # Lambda functions
│   │   ├── agent_invoker.py           # ⭐ Agent-to-agent LLM invocation
│   │   ├── mcp_proxy.py               # ⭐ MCP tool execution proxy
│   │   ├── memory_manager.py          # Memory operations for LLMs
│   │   ├── chat_handler.py            # User chat interface
│   │   ├── pipeline_executor.py       # (Legacy - can be removed)
│   │   └── __init__.py
│   │
│   ├── mcp_server/                    # MCP Server (pipeline runtime)
│   │   ├── server.py                  # MCP protocol server
│   │   └── http_server.py             # ⭐ HTTP wrapper for MCP tools
│   │
│   └── utils/                         # Utility modules
│       ├── bedrock_client.py          # Bedrock API helpers
│       └── memory_client.py           # DynamoDB helpers
│
├── knowledge_base/                    # ⭐ RAG CONTENT - Documents for LLMs
│   ├── orchestrator/                  # Orchestrator agent knowledge
│   │   └── orchestration_guide.md     # Pipeline dependencies, patterns
│   ├── bootstrap/                     # Bootstrap agent knowledge
│   │   └── bootstrap_guide.md         # VPC, networking best practices
│   ├── compute/                       # Compute agent knowledge
│   │   └── compute_guide.md           # EC2 sizing, provisioning
│   └── app/                           # App agent knowledge
│       └── app_guide.md               # Deployment patterns, procedures
│
└── scripts/                           # Setup and utility scripts
    └── setup.sh                       # Initial setup script
```

## Key Components Explained

### ⭐ LLM Orchestration Components

These are the core files that enable LLM-driven orchestration:

1. **`terraform/bedrock_agents.tf`**
   - Defines 4 agents with Claude 3 Sonnet as their brains
   - Contains natural language instructions that guide LLM behavior
   - Links agents to their knowledge bases

2. **`terraform/bedrock_action_groups.tf`**
   - Defines tools (action groups) that LLMs can call
   - OpenAPI schemas describe each tool's purpose
   - LLMs read these descriptions to decide which tools to use

3. **`terraform/bedrock_knowledge_base.tf`**
   - Sets up vector databases (OpenSearch Serverless)
   - Configures RAG for automatic context retrieval
   - Links S3 buckets containing documentation

4. **`knowledge_base/` directories**
   - Markdown documents that LLMs search via RAG
   - Provides context for decision-making
   - Automatically embedded and indexed

5. **`src/lambda/agent_invoker.py`**
   - Enables orchestrator LLM to invoke other agents
   - Passes natural language instructions between LLMs
   - Pure agent-to-agent communication

6. **`src/lambda/mcp_proxy.py`**
   - Bridges agent LLMs to MCP tools
   - Called when LLM decides to execute a pipeline
   - Stores results in memory for future LLM queries

7. **`src/mcp_server/http_server.py`**
   - Actual pipeline execution runtime
   - Provides tools that agents can call
   - Returns structured results to LLMs

### Infrastructure Components

- **`terraform/iam.tf`**: Permissions for agents to invoke models, call Lambdas, access knowledge bases
- **`terraform/dynamodb.tf`**: Short-term memory for deployment history (queried by LLMs)
- **`terraform/s3.tf`**: Storage for knowledge base documents
- **`terraform/api_gateway.tf`**: HTTP endpoint for user chat interface

### Support Components

- **`src/lambda/memory_manager.py`**: Query/store deployment history (called by orchestrator LLM)
- **`src/lambda/chat_handler.py`**: Entry point for user messages
- **`src/utils/`**: Helper functions for Bedrock and DynamoDB

## Data Flow

```
User Message
    ↓
API Gateway → chat_handler.py
    ↓
Orchestrator Agent (LLM)
    ├─→ Searches knowledge_base/orchestrator/ (RAG)
    ├─→ Calls memory_manager.py (query history)
    └─→ Calls agent_invoker.py (invoke specialized agent)
        ↓
    Bootstrap/Compute/App Agent (LLM)
        ├─→ Searches knowledge_base/{agent}/ (RAG)
        └─→ Calls mcp_proxy.py (execute MCP tool)
            ↓
        MCP Server (http_server.py)
            ↓
        Actual Pipeline Execution
            ↓
        Results stored in DynamoDB
            ↓
        Response flows back through LLMs
            ↓
User receives natural language summary
```

## What to Read First

1. **Start here**: `docs/answering-your-question.md` - Understand where LLM orchestration happens
2. **Then read**: `ARCHITECTURE.md` - High-level overview
3. **Deep dive**: `docs/example-interaction.md` - See LLM reasoning in action
4. **Reference**: `docs/component-mapping.md` - Detailed file-by-file explanation

## What to Modify

### To change agent behavior:
- Edit instructions in `terraform/bedrock_agents.tf`
- Update knowledge base docs in `knowledge_base/`

### To add new tools:
- Add action group in `terraform/bedrock_action_groups.tf`
- Implement handler in `src/lambda/mcp_proxy.py`
- Add tool to MCP server in `src/mcp_server/http_server.py`

### To change the LLM model:
- Update `foundation_model` in `terraform/bedrock_agents.tf`
- Options: Claude 3 Sonnet, Claude 3 Haiku, Claude 3 Opus

### To add more agents:
- Define new agent in `terraform/bedrock_agents.tf`
- Create knowledge base in `terraform/bedrock_knowledge_base.tf`
- Add knowledge base docs in `knowledge_base/{new_agent}/`
- Update orchestrator to know about new agent

## Files You Can Ignore

- `src/lambda/pipeline_executor.py` - Legacy file from initial implementation, can be removed
- `src/mcp_server/server.py` - MCP protocol version (use `http_server.py` instead)

## Testing

1. Deploy infrastructure: `cd terraform && terraform apply`
2. Upload knowledge base docs to S3 (output from terraform)
3. Start MCP server: `python src/mcp_server/http_server.py`
4. Send test request to API Gateway endpoint
5. Watch the LLM orchestrate the workflow!

## Key Insight

Most of the "magic" happens inside AWS Bedrock Agents:
- RAG searches are automatic
- LLM reasoning is built-in
- Tool selection is dynamic
- Natural language generation is handled

Your code just:
- Defines the agents and their instructions
- Provides knowledge base content
- Implements the tools (action groups)
- Handles tool execution

The LLM does the orchestration!
