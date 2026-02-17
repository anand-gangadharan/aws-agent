# How to Customize Knowledge Base for Your Pipelines

## Current Status: Templates

The existing markdown files are **starter templates** with generic content. They work for POC but should be customized with your actual pipeline details.

## Quick Customization Checklist

### 1. Bootstrap Pipeline (`bootstrap/bootstrap_guide.md`)

Replace generic content with:
- [ ] Your actual Terraform module/script path
- [ ] Specific CIDR ranges you use (e.g., 10.100.0.0/16 for dev)
- [ ] Number of AZs you deploy to
- [ ] Actual subnet layout (public/private/data tiers)
- [ ] Security group rules you create
- [ ] Tags you apply
- [ ] Execution time (how long it takes)
- [ ] Common errors from your pipeline logs

**Example additions**:
```markdown
## Actual Implementation
- Script: `scripts/bootstrap/create-vpc.sh`
- Terraform module: `modules/networking/v2.1`
- Execution: `./bootstrap.sh --env dev --region us-east-1`

## CIDR Allocation
- Dev: 10.100.0.0/16
- Staging: 10.150.0.0/16  
- Prod: 10.200.0.0/16

## Subnet Layout (per AZ)
- Public: 10.x.0.0/24, 10.x.1.0/24, 10.x.2.0/24
- Private-App: 10.x.10.0/24, 10.x.11.0/24, 10.x.12.0/24
- Private-Data: 10.x.20.0/24, 10.x.21.0/24, 10.x.22.0/24

## Execution Time
- Dev: 5-7 minutes
- Prod: 8-10 minutes (more resources)
```

### 2. Compute Pipeline (`compute/compute_guide.md`)

Add your specifics:
- [ ] Instance types per environment (t3.medium for dev, m5.large for prod)
- [ ] AMI IDs or selection criteria
- [ ] User data scripts
- [ ] IAM roles attached
- [ ] EBS volume configuration
- [ ] Monitoring/logging setup
- [ ] Cost per tenant estimate

**Example additions**:
```markdown
## Instance Sizing by Environment

### Dev
- Type: t3.medium (2 vCPU, 4GB RAM)
- Count: 1-2 per tenant
- Cost: ~$30/month per tenant

### Prod
- Type: m5.large (2 vCPU, 8GB RAM)
- Count: 2-4 per tenant (HA)
- Cost: ~$140/month per tenant

## AMI Selection
- Base: Amazon Linux 2023
- Custom AMI: ami-0abc123def456 (includes our base config)
- Updated: Monthly via pipeline

## Attached Resources
- IAM Role: tenant-ec2-role
- Security Groups: tenant-app-sg, tenant-db-client-sg
- EBS: 50GB GP3 root, 100GB GP3 data
```

### 3. App Pipeline (`app/app_guide.md`)

Document your deployment process:
- [ ] Where application artifacts are stored (S3 bucket, ECR, etc.)
- [ ] Deployment method (CodeDeploy, custom scripts, Ansible)
- [ ] Configuration management (SSM parameters, Secrets Manager)
- [ ] Health check endpoints
- [ ] Rollback procedure
- [ ] Supported application types

**Example additions**:
```markdown
## Artifact Storage
- Location: s3://mycompany-artifacts/apps/
- Format: tar.gz with appspec.yml
- Versioning: Semantic versioning (1.2.3)

## Deployment Method
- Tool: AWS CodeDeploy
- Agent: Pre-installed on EC2 instances
- Hooks: ApplicationStop, BeforeInstall, AfterInstall, ApplicationStart

## Configuration
- Environment vars: SSM Parameter Store /app/{tenant}/{env}/
- Secrets: AWS Secrets Manager /app/{tenant}/db-password
- Config files: Rendered from templates

## Health Checks
- Endpoint: GET /health
- Expected: 200 OK with {"status": "healthy"}
- Timeout: 30 seconds
- Retries: 3

## Rollback
If health checks fail:
1. CodeDeploy automatically rolls back
2. Previous version restored
3. Alert sent to Slack #deployments
```

### 4. Orchestrator (`orchestrator/orchestration_guide.md`)

Add your business logic:
- [ ] Specific environment names (dev, staging, prod)
- [ ] Tenant naming conventions
- [ ] Approval requirements
- [ ] Maintenance windows
- [ ] Cost limits per tenant

**Example additions**:
```markdown
## Environment Strategy
- dev: Shared resources, auto-deploy
- staging: Production-like, manual approval
- prod: HA setup, change control required

## Tenant Naming
- Format: {company}-{env} (e.g., acme-prod)
- Max length: 20 characters
- Allowed: lowercase, numbers, hyphens

## Deployment Windows
- Dev: Anytime
- Staging: Business hours (9am-5pm ET)
- Prod: Maintenance window (Sat 2am-6am ET)

## Cost Controls
- Dev tenant limit: $100/month
- Prod tenant limit: $500/month
- Alert at 80% of limit
```

## Adding Pipeline-Specific Details

### If you use Jenkins/GitLab CI

```markdown
## Pipeline Execution

### Jenkins Job
- Job: `bootstrap-pipeline`
- Parameters: ENVIRONMENT, REGION
- Trigger: Manual or via API
- Logs: Jenkins console + CloudWatch

### GitLab CI
- Pipeline: `.gitlab-ci.yml`
- Stage: infrastructure
- Variables: ENV, AWS_REGION
- Artifacts: terraform.tfstate
```

### If you use specific tools

```markdown
## Tools Used
- Terraform: v1.5.0
- Ansible: v2.15
- Packer: v1.9.0 (for AMI builds)
- Terragrunt: v0.48.0 (for environment management)

## Repository Structure
- Code: github.com/mycompany/infrastructure
- Branch: main (prod), develop (dev)
- Modules: modules/ directory
```

### If you have compliance requirements

```markdown
## Compliance
- All resources tagged with: Owner, CostCenter, Environment
- Encryption: All EBS volumes encrypted with KMS
- Logging: VPC Flow Logs, CloudTrail enabled
- Backup: Daily snapshots, 30-day retention
```

## Real Example: Before and After

### Before (Generic Template)
```markdown
# Bootstrap Pipeline Guide

## Purpose
Create foundational infrastructure for an environment.

## Components Created
- VPC with CIDR blocks
- Public and private subnets
```

### After (Customized for Your Pipeline)
```markdown
# Bootstrap Pipeline Guide

## Purpose
Creates networking infrastructure using our standard VPC module.

## Execution
```bash
cd terraform/environments/${ENV}
terraform init -backend-config=backend.tfvars
terraform apply -var-file=${ENV}.tfvars
```

## Components Created

### VPC
- Dev: 10.100.0.0/16 (vpc-dev-main)
- Prod: 10.200.0.0/16 (vpc-prod-main)
- DNS: Enabled (for internal service discovery)
- Flow Logs: Enabled → CloudWatch Logs

### Subnets (3 AZs: us-east-1a, 1b, 1c)

#### Public Subnets (for ALB, NAT)
- 10.x.0.0/24, 10.x.1.0/24, 10.x.2.0/24
- Auto-assign public IP: Yes
- Route: 0.0.0.0/0 → Internet Gateway

#### Private App Subnets (for EC2)
- 10.x.10.0/24, 10.x.11.0/24, 10.x.12.0/24
- Auto-assign public IP: No
- Route: 0.0.0.0/0 → NAT Gateway

#### Private Data Subnets (for RDS)
- 10.x.20.0/24, 10.x.21.0/24, 10.x.22.0/24
- Auto-assign public IP: No
- Route: Local only

### NAT Gateways
- One per AZ (high availability)
- Elastic IPs: Allocated automatically
- Cost: ~$100/month (3 NAT Gateways)

### Security Groups

#### Default SG
- Inbound: Deny all
- Outbound: Allow all

#### ALB SG (sg-alb)
- Inbound: 443 from 0.0.0.0/0
- Outbound: 8080 to App SG

#### App SG (sg-app)
- Inbound: 8080 from ALB SG
- Outbound: 5432 to Data SG, 443 to 0.0.0.0/0

## Prerequisites
- AWS credentials with VPC admin permissions
- Terraform >= 1.5.0
- S3 bucket for state: s3://mycompany-terraform-state
- DynamoDB table for locking: terraform-state-lock

## Execution Time
- Dev: 5-7 minutes
- Prod: 8-10 minutes

## Outputs
```hcl
vpc_id = "vpc-0abc123def456"
public_subnet_ids = ["subnet-111", "subnet-222", "subnet-333"]
private_app_subnet_ids = ["subnet-444", "subnet-555", "subnet-666"]
private_data_subnet_ids = ["subnet-777", "subnet-888", "subnet-999"]
nat_gateway_ids = ["nat-aaa", "nat-bbb", "nat-ccc"]
```

## Validation
```bash
# Verify VPC
aws ec2 describe-vpcs --vpc-ids $(terraform output -raw vpc_id)

# Verify subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)"

# Test connectivity
aws ec2 run-instances --subnet-id $(terraform output -raw public_subnet_ids[0]) --image-id ami-test
```

## Troubleshooting

### Error: "VPC limit exceeded"
```
Error: Error creating VPC: VpcLimitExceeded: The maximum number of VPCs has been reached.
```
**Solution**: 
1. Check current VPCs: `aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==\`Name\`].Value|[0]]'`
2. Delete unused VPCs or request limit increase
3. Current limit: 5 VPCs per region

### Error: "CIDR conflict"
```
Error: Error creating VPC: InvalidVpcRange: The CIDR '10.100.0.0/16' conflicts with another VPC
```
**Solution**:
1. Check existing CIDRs: `aws ec2 describe-vpcs --query 'Vpcs[*].CidrBlock'`
2. Update CIDR in `${ENV}.tfvars`
3. Available ranges: 10.100.0.0/16, 10.150.0.0/16, 10.250.0.0/16

### Error: "NAT Gateway creation timeout"
**Solution**: NAT Gateways take 3-5 minutes. If timeout:
1. Check AWS Service Health Dashboard
2. Retry: `terraform apply`
3. If persistent, try different AZ

## Cost Estimate
- VPC: Free
- Subnets: Free
- Internet Gateway: Free
- NAT Gateways: ~$100/month (3 x $32/month + data transfer)
- VPC Flow Logs: ~$5/month

**Total: ~$105/month per environment**

## Tags Applied
All resources tagged with:
- Environment: dev/prod
- ManagedBy: terraform
- Owner: platform-team
- CostCenter: infrastructure
- Project: cicd-platform
```

## How to Update

### 1. Edit the markdown files
```bash
cd knowledge_base/bootstrap/
vim bootstrap_guide.md
# Add your actual pipeline details
```

### 2. Upload to S3
```bash
cd terraform
KB_BUCKET=$(terraform output -raw knowledge_base_bucket)
aws s3 sync ../knowledge_base/ s3://$KB_BUCKET/
```

### 3. Sync knowledge base
```bash
# Via AWS Console
# Bedrock → Knowledge bases → Select KB → Sync

# Or via CLI
aws bedrock-agent start-ingestion-job \
  --knowledge-base-id $(terraform output -raw bootstrap_kb_id) \
  --data-source-id $(terraform output -raw bootstrap_data_source_id)
```

### 4. Test
```bash
curl -X POST "$API_URL/chat" \
  -H "Content-Type: application/json" \
  -d '{"message": "What CIDR range is used for dev?"}'
```

The agent should now reference your specific CIDR (10.100.0.0/16) instead of generic ranges!

## Tips

1. **Start simple**: Update one file at a time
2. **Test frequently**: Upload and test after each change
3. **Be specific**: Use actual values from your pipelines
4. **Include examples**: Show real commands and outputs
5. **Document errors**: Add troubleshooting from your experience
6. **Keep it current**: Update when pipelines change

## Summary

- ✅ Current files are templates - they work but are generic
- ✅ Customize with your actual pipeline details
- ✅ The more specific, the better the LLM decisions
- ✅ Easy to update - just edit markdown and sync
- ✅ Agents automatically use updated docs via RAG

The knowledge base is the "brain" that guides your agents - make it smart with your real pipeline documentation!
