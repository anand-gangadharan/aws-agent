# Knowledge Base Documentation

## Purpose

This folder contains documentation that powers the **RAG (Retrieval Augmented Generation)** system for your Bedrock Agents. When agents need information, they automatically search these documents to make informed decisions.

## How It Works

```
1. You write documentation (markdown files) → Store in knowledge_base/
2. Upload to S3 → terraform apply syncs them
3. Bedrock creates vector embeddings → Stored in S3 vector store
4. Agent LLM needs information → Automatically searches these docs
5. Retrieved content → Added to LLM's context
6. LLM makes decision → Based on your documentation
```

## Folder Structure

```
knowledge_base/
├── orchestrator/          # Docs for Orchestrator Agent
│   └── orchestration_guide.md
├── bootstrap/             # Docs for Bootstrap Agent
│   └── bootstrap_guide.md
├── compute/               # Docs for Compute Agent
│   └── compute_guide.md
└── app/                   # Docs for App Agent
    └── app_guide.md
```

Each agent only searches its own folder via RAG.

## Current Files: Templates or Real?

The current markdown files are **starter templates** with generic content. You should:

✅ **Keep the structure** (helpful for POC)
✅ **Customize with your actual pipeline details**
✅ **Add more files** as needed

## What to Document

### For Orchestrator (`orchestrator/`)

Document:
- **Pipeline dependencies**: What must run before what?
- **Decision rules**: When to run which pipelines?
- **Environment patterns**: How dev/prod differ?
- **Tenant management**: How to handle multiple tenants?
- **Error handling**: What to do when pipelines fail?

Example questions the LLM will ask:
- "What pipelines are needed for a new environment?"
- "Can I skip bootstrap if it already exists?"
- "What order should I invoke agents?"

### For Bootstrap (`bootstrap/`)

Document:
- **Infrastructure created**: VPC, subnets, ACLs, etc.
- **Configuration details**: CIDR blocks, AZ strategy
- **Prerequisites**: What's needed before running?
- **Best practices**: Networking standards
- **Troubleshooting**: Common issues

Example questions the LLM will ask:
- "What does the bootstrap pipeline create?"
- "What CIDR range should I use for dev?"
- "How many availability zones?"

### For Compute (`compute/`)

Document:
- **Instance types**: Sizing guidelines per environment
- **Tenant isolation**: How to separate tenant resources
- **Security groups**: What rules to apply
- **Scaling policies**: When to add more instances
- **Cost optimization**: Right-sizing recommendations

Example questions the LLM will ask:
- "What instance type for a dev tenant?"
- "How many instances should I provision?"
- "What security groups are needed?"

### For App (`app/`)

Document:
- **Deployment procedures**: Step-by-step process
- **Application types**: Different app categories
- **Configuration**: Environment variables, settings
- **Health checks**: How to verify deployment
- **Rollback procedures**: What to do on failure

Example questions the LLM will ask:
- "How do I deploy a web application?"
- "What health checks should I run?"
- "Where do I find the application artifacts?"

## Example: Customizing for Your Pipelines

### Your Bootstrap Pipeline

If your actual bootstrap pipeline creates:
- VPC with /16 CIDR
- 3 public subnets across 3 AZs
- 3 private subnets across 3 AZs
- NAT Gateway in each AZ
- Internet Gateway
- Route tables
- Network ACLs with specific rules

Then update `bootstrap/bootstrap_guide.md`:

```markdown
# Bootstrap Pipeline Documentation

## Overview
Creates foundational networking infrastructure for an environment.

## Infrastructure Created

### VPC
- CIDR: 10.0.0.0/16 (dev), 10.1.0.0/16 (prod)
- DNS hostnames: Enabled
- DNS resolution: Enabled

### Subnets
- 3 Public subnets: 10.x.0.0/24, 10.x.1.0/24, 10.x.2.0/24
- 3 Private subnets: 10.x.10.0/24, 10.x.11.0/24, 10.x.12.0/24
- Spread across us-east-1a, us-east-1b, us-east-1c

### NAT Gateways
- One per AZ for high availability
- Elastic IPs attached

### Route Tables
- Public route table: Routes to Internet Gateway
- Private route tables: Routes to NAT Gateways

## Prerequisites
- AWS account with VPC quota available
- Target region: us-east-1
- Environment name: dev or prod

## Execution Time
- Typical: 5-7 minutes
- With NAT Gateways: 8-10 minutes

## Outputs
- VPC ID
- Subnet IDs (public and private)
- NAT Gateway IDs
- Route table IDs

## Troubleshooting
- If VPC creation fails: Check VPC quota
- If NAT Gateway fails: Check EIP quota
- If subnets fail: Check CIDR conflicts
```

### Your Compute Pipeline

If your compute pipeline provisions:
- EC2 instances with specific AMIs
- Auto Scaling Groups
- Load Balancers
- CloudWatch monitoring

Then update `compute/compute_guide.md` with those details.

## File Format

### Supported Formats
- ✅ Markdown (.md) - Recommended
- ✅ Plain text (.txt)
- ✅ PDF (.pdf)
- ✅ Word (.docx)
- ✅ HTML (.html)

### Best Practices

1. **Use clear headings** - Helps LLM find relevant sections
2. **Be specific** - Include actual values, not just "configure networking"
3. **Include examples** - Show sample configurations
4. **Add troubleshooting** - Common errors and solutions
5. **Keep it updated** - Sync with actual pipeline changes

### Example Structure

```markdown
# Pipeline Name

## Overview
Brief description of what this pipeline does.

## Prerequisites
What must exist before running this pipeline.

## Parameters
- parameter1: Description and valid values
- parameter2: Description and valid values

## Steps
1. Step 1 description
2. Step 2 description
3. Step 3 description

## Outputs
What this pipeline produces.

## Examples
### Example 1: Dev Environment
```yaml
environment: dev
instance_type: t3.medium
instance_count: 2
```

### Example 2: Prod Environment
```yaml
environment: prod
instance_type: m5.large
instance_count: 5
```

## Troubleshooting
- Error X: Solution Y
- Error A: Solution B

## Best Practices
- Practice 1
- Practice 2
```

## Adding New Documents

### 1. Create the file
```bash
# Add a new document for the orchestrator
echo "# Advanced Orchestration Patterns" > knowledge_base/orchestrator/advanced_patterns.md
```

### 2. Write content
Add your documentation with clear structure.

### 3. Upload to S3
```bash
cd terraform
KB_BUCKET=$(terraform output -raw knowledge_base_bucket)
aws s3 sync ../knowledge_base/ s3://$KB_BUCKET/
```

### 4. Sync knowledge base
```bash
# Get knowledge base IDs
ORCH_KB=$(terraform output -raw orchestrator_kb_id)

# Trigger sync (or use AWS Console)
aws bedrock-agent start-ingestion-job \
  --knowledge-base-id $ORCH_KB \
  --data-source-id <data-source-id>
```

### 5. Test
The agent will now search the new document automatically!

## How Agents Use These Docs

### Automatic RAG Process

When an agent receives a request:

```
1. Agent LLM receives: "Deploy to new environment"
   
2. LLM thinks: "I need to know about new environment setup"
   
3. Bedrock automatically:
   - Generates search query: "new environment deployment"
   - Searches agent's knowledge base (vector similarity)
   - Retrieves top 3-5 relevant chunks
   
4. Retrieved content added to LLM prompt:
   "Based on the documentation:
    - New environment needs Bootstrap → Compute → App
    - Check if bootstrap exists first
    - ..."
   
5. LLM makes decision using this context
```

**You don't write code for this - it's automatic!**

## Real-World Example

### Before (Generic Template)
```markdown
# Bootstrap Pipeline Guide

## Purpose
Create foundational infrastructure for an environment.

## Components Created
- VPC with CIDR blocks
- Public and private subnets
- Internet Gateway
```

### After (Your Actual Pipeline)
```markdown
# Bootstrap Pipeline Guide

## Purpose
Creates networking infrastructure using our Terraform module v2.3.

## Execution
Runs: `terraform apply -var-file=envs/${ENV}.tfvars`
Module: `modules/networking/vpc-standard`

## Components Created

### VPC
- Dev: 10.100.0.0/16
- Prod: 10.200.0.0/16
- Tags: Environment, CostCenter, Owner

### Subnets (per AZ)
- Public: /24 (for ALBs, NAT)
- Private-App: /24 (for EC2 instances)
- Private-Data: /24 (for RDS, ElastiCache)

### Security
- Default NACL: Deny all
- Custom NACLs per subnet tier
- VPC Flow Logs → CloudWatch

## Prerequisites
- Terraform >= 1.5.0
- AWS credentials with VPC admin
- S3 backend configured
- DynamoDB table for state locking

## Execution Time
- Dev: ~5 minutes
- Prod: ~8 minutes (more subnets)

## Validation
After completion, verify:
```bash
aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=${ENV}"
aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}"
```

## Troubleshooting

### Error: "VPC limit exceeded"
- Check quota: `aws service-quotas get-service-quota --service-code vpc --quota-code L-F678F1CE`
- Request increase if needed

### Error: "CIDR conflict"
- Check existing VPCs: `aws ec2 describe-vpcs`
- Update CIDR in tfvars file

## Outputs Used by Compute Pipeline
- vpc_id
- private_subnet_ids
- security_group_id
```

## Testing Your Documentation

### 1. Upload to S3
```bash
aws s3 sync knowledge_base/ s3://your-kb-bucket/
```

### 2. Sync knowledge base
Use AWS Console → Bedrock → Knowledge bases → Sync

### 3. Test with a query
```bash
curl -X POST "$API_URL/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What CIDR range should I use for dev?"
  }'
```

### 4. Check if LLM uses your docs
The response should reference your specific CIDR ranges (10.100.0.0/16), not generic ones.

## Tips for Great Documentation

### ✅ Do
- Be specific with actual values
- Include examples from your environment
- Document error messages and solutions
- Keep it updated with pipeline changes
- Use clear section headings
- Add diagrams if helpful (as markdown)

### ❌ Don't
- Use vague descriptions like "configure as needed"
- Leave placeholder text like "TODO"
- Include sensitive data (passwords, keys)
- Make it too long (LLM has token limits)
- Forget to sync after updates

## Summary

The `knowledge_base/` folder is:
- ✅ Where you document your actual pipelines
- ✅ Automatically searched by agents via RAG
- ✅ The "brain" that guides LLM decisions
- ✅ Easy to update - just edit markdown and sync

Current files are templates - customize them with your real pipeline details for best results!
