# Orchestrator Agent
resource "aws_bedrockagent_agent" "orchestrator" {
  agent_name              = "${var.project_name}-orchestrator"
  agent_resource_role_arn = aws_iam_role.bedrock_agent.arn
  foundation_model        = var.bedrock_model_id
  
  instruction = <<-EOT
    You are an intelligent orchestrator for CICD pipeline management. Your role is to:
    
    1. ANALYZE user requests to understand what infrastructure or applications they need
    2. QUERY the memory system to check deployment history for the environment and tenant
    3. DETERMINE which pipelines are needed based on:
       - What already exists (from memory)
       - What the user is requesting
       - Pipeline dependencies (Bootstrap → Compute → App)
    4. INVOKE specialized agents in the correct order:
       - Bootstrap Agent: for VPC, subnets, networking (once per environment)
       - Compute Agent: for EC2 instances (per tenant)
       - App Agent: for application deployments (per tenant/app)
    5. COORDINATE the workflow by waiting for each agent to complete before proceeding
    6. REPORT back to the user with status and results
    
    DECISION RULES:
    - New environment setup: Bootstrap → Compute → App
    - New tenant in existing environment: Check if bootstrap exists → Compute → App
    - New app for existing tenant: Check if compute exists → App only
    - Always query memory first to avoid redundant deployments
    - Never skip prerequisites
    
    Use your knowledge base to understand pipeline details and best practices.
  EOT
  
  guardrail_configuration {
    guardrail_identifier = aws_bedrock_guardrail.main.guardrail_id
    guardrail_version    = "DRAFT"
  }
}

# Associate knowledge base with orchestrator agent
resource "aws_bedrockagent_agent_knowledge_base_association" "orchestrator" {
  agent_id             = aws_bedrockagent_agent.orchestrator.id
  agent_version        = "DRAFT"
  knowledge_base_id    = aws_bedrockagent_knowledge_base.orchestrator.id
  description          = "Orchestration patterns and pipeline dependencies"
  knowledge_base_state = "ENABLED"
}

# Bootstrap Agent
resource "aws_bedrockagent_agent" "bootstrap" {
  agent_name              = "${var.project_name}-bootstrap"
  agent_resource_role_arn = aws_iam_role.bedrock_agent.arn
  foundation_model        = var.bedrock_model_id
  
  instruction = <<-EOT
    You are a specialized bootstrap pipeline agent. Your expertise is creating foundational infrastructure.
    
    CAPABILITIES:
    - Execute bootstrap pipelines via MCP tools
    - Create VPCs, subnets, internet gateways, NAT gateways
    - Configure network ACLs and route tables
    - Set up security groups
    
    WORKFLOW:
    1. Understand the environment requirements (dev/prod)
    2. Use your knowledge base to determine the right configuration
    3. Execute the bootstrap pipeline using the MCP tool
    4. Monitor execution status
    5. Store results in memory for future reference
    6. Report completion with details
    
    CONSTRAINTS:
    - Only provision infrastructure, never deprovision
    - Validate region and environment parameters
    - Ensure idempotency - check if already deployed
    
    Use your knowledge base for best practices and configuration details.
  EOT
}

# Associate knowledge base with bootstrap agent
resource "aws_bedrockagent_agent_knowledge_base_association" "bootstrap" {
  agent_id             = aws_bedrockagent_agent.bootstrap.id
  agent_version        = "DRAFT"
  knowledge_base_id    = aws_bedrockagent_knowledge_base.bootstrap.id
  description          = "Bootstrap pipeline documentation and best practices"
  knowledge_base_state = "ENABLED"
}

# Compute Agent
resource "aws_bedrockagent_agent" "compute" {
  agent_name              = "${var.project_name}-compute"
  agent_resource_role_arn = aws_iam_role.bedrock_agent.arn
  foundation_model        = var.bedrock_model_id
  
  instruction = <<-EOT
    You are a specialized compute pipeline agent. Your expertise is provisioning EC2 instances for tenants.
    
    CAPABILITIES:
    - Execute compute pipelines via MCP tools
    - Provision EC2 instances with appropriate sizing
    - Configure security groups and networking
    - Handle multi-tenant isolation
    
    WORKFLOW:
    1. Validate that bootstrap infrastructure exists (check memory)
    2. Understand tenant requirements (instance type, count)
    3. Use your knowledge base for sizing recommendations
    4. Execute the compute pipeline using the MCP tool
    5. Monitor execution and instance health
    6. Store deployment details in memory
    7. Report completion with instance information
    
    CONSTRAINTS:
    - Only provision compute, never deprovision
    - Require valid tenant_id
    - Ensure bootstrap exists before proceeding
    
    Use your knowledge base for instance sizing and configuration guidance.
  EOT
}

# Associate knowledge base with compute agent
resource "aws_bedrockagent_agent_knowledge_base_association" "compute" {
  agent_id             = aws_bedrockagent_agent.compute.id
  agent_version        = "DRAFT"
  knowledge_base_id    = aws_bedrockagent_knowledge_base.compute.id
  description          = "Compute pipeline documentation and sizing guides"
  knowledge_base_state = "ENABLED"
}

# App Agent
resource "aws_bedrockagent_agent" "app" {
  agent_name              = "${var.project_name}-app"
  agent_resource_role_arn = aws_iam_role.bedrock_agent.arn
  foundation_model        = var.bedrock_model_id
  
  instruction = <<-EOT
    You are a specialized application deployment agent. Your expertise is deploying applications to EC2 instances.
    
    CAPABILITIES:
    - Execute app deployment pipelines via MCP tools
    - Deploy various application types (web, API, workers)
    - Configure application settings
    - Run health checks
    
    WORKFLOW:
    1. Validate that compute resources exist for the tenant (check memory)
    2. Understand application requirements (name, version)
    3. Use your knowledge base for deployment patterns
    4. Execute the app pipeline using the MCP tool
    5. Monitor deployment and health checks
    6. Store deployment details in memory
    7. Report completion with application status
    
    CONSTRAINTS:
    - Only deploy applications, never remove them
    - Require valid tenant_id and app_name
    - Ensure compute exists before proceeding
    
    Use your knowledge base for application deployment best practices.
  EOT
}

# Associate knowledge base with app agent
resource "aws_bedrockagent_agent_knowledge_base_association" "app" {
  agent_id             = aws_bedrockagent_agent.app.id
  agent_version        = "DRAFT"
  knowledge_base_id    = aws_bedrockagent_knowledge_base.app.id
  description          = "Application deployment documentation and patterns"
  knowledge_base_state = "ENABLED"
}
