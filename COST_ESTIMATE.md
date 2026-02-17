# Infrastructure Cost Estimate

Complete cost breakdown for all resources provisioned by Terraform.

## Monthly Cost Summary

| Category | Service | Monthly Cost | Notes |
|----------|---------|--------------|-------|
| **Compute** | Lambda Functions (5) | $0.20 - $2 | Pay per invocation |
| **AI/ML** | Bedrock Agents (4) | $5 - $20 | Pay per token |
| **AI/ML** | Titan Embeddings v2 | $0.10 - $1 | Pay per token |
| **Database** | RDS Aurora Serverless v2 | $15 - $30 | Scales with usage |
| **Database** | DynamoDB | $1 - $5 | Pay per request |
| **Storage** | S3 (Knowledge Base) | $0.10 - $0.50 | Minimal storage |
| **Networking** | API Gateway | $0.50 - $2 | Pay per request |
| **Security** | Secrets Manager | $0.40 | $0.40/secret/month |
| **Total** | | **$22 - $61/month** | Typical: ~$35/month |

## Detailed Breakdown

### 1. AWS Bedrock Agents (4 agents)

**Service**: AWS Bedrock with Nova Pro model

**Resources**:
- Orchestrator Agent
- Bootstrap Agent
- Compute Agent
- App Agent

**Pricing**:
- Input tokens: $0.0008 per 1K tokens
- Output tokens: $0.0032 per 1K tokens

**Estimated Usage** (POC with moderate testing):
- ~1M input tokens/month: $0.80
- ~2M output tokens/month: $6.40
- **Total: $7.20/month**

**Heavy usage**: $15-20/month

### 2. Titan Embeddings v2

**Service**: Amazon Titan Embeddings for knowledge base

**Pricing**: $0.0001 per 1K tokens

**Estimated Usage**:
- Initial embedding (one-time): ~50K tokens = $0.005
- Monthly queries: ~500K tokens = $0.05
- **Total: $0.10/month**

### 3. RDS Aurora Serverless v2

**Service**: PostgreSQL with pgvector for vector storage

**Configuration**:
- Min capacity: 0.5 ACU
- Max capacity: 1.0 ACU
- Engine: aurora-postgresql 15.4

**Pricing**: $0.12 per ACU-hour

**Estimated Usage**:
- Average capacity: 0.5 ACU (scales to zero when idle)
- Active hours: ~200 hours/month (POC usage)
- Cost: 0.5 ACU × $0.12 × 200 hours = $12/month
- **Total: $12 - $30/month**

**Note**: Can scale to zero, so actual cost depends on usage

### 4. Lambda Functions (5 functions)

**Functions**:
1. chat_handler (entry point)
2. agent_invoker (multi-agent coordination)
3. mcp_proxy (pipeline execution bridge)
4. memory_manager (state queries)
5. mcp_server (pipeline executor)

**Pricing**:
- Requests: $0.20 per 1M requests
- Duration: $0.0000166667 per GB-second

**Estimated Usage** (POC):
- ~10K invocations/month
- Average duration: 2 seconds
- Memory: 512 MB
- **Total: $0.20 - $2/month**

### 5. DynamoDB (Memory Table)

**Service**: DynamoDB on-demand

**Configuration**:
- Table: cicd-agent-memory
- Mode: Pay per request
- GSIs: 2 (environment-index, tenant-index)

**Pricing**:
- Write requests: $1.25 per 1M requests
- Read requests: $0.25 per 1M requests
- Storage: $0.25 per GB-month

**Estimated Usage**:
- Writes: ~5K/month = $0.006
- Reads: ~20K/month = $0.005
- Storage: ~1 GB = $0.25
- **Total: $1 - $5/month**

### 6. S3 (Knowledge Base Storage)

**Service**: S3 Standard

**Usage**:
- Source documents: ~10 MB
- Metadata: ~1 MB
- Total: ~11 MB

**Pricing**:
- Storage: $0.023 per GB-month
- PUT requests: $0.005 per 1K requests
- GET requests: $0.0004 per 1K requests

**Estimated Cost**:
- Storage: 0.011 GB × $0.023 = $0.0003
- Requests: ~1K/month = $0.005
- **Total: $0.10 - $0.50/month**

### 7. API Gateway

**Service**: HTTP API Gateway

**Configuration**:
- Type: HTTP API (cheaper than REST)
- Endpoints: /chat

**Pricing**: $1.00 per million requests

**Estimated Usage**:
- ~1K requests/month
- **Total: $0.50 - $2/month**

### 8. Secrets Manager

**Service**: AWS Secrets Manager

**Usage**:
- 1 secret (RDS credentials)

**Pricing**: $0.40 per secret per month

**Total: $0.40/month**

### 9. CloudWatch Logs

**Service**: CloudWatch Logs

**Usage**:
- Lambda logs: ~500 MB/month
- Retention: 7 days

**Pricing**:
- Ingestion: $0.50 per GB
- Storage: $0.03 per GB-month

**Estimated Cost**:
- Ingestion: 0.5 GB × $0.50 = $0.25
- Storage: 0.5 GB × $0.03 = $0.015
- **Total: $0.30 - $1/month**

### 10. IAM Roles & Policies

**Service**: AWS IAM

**Cost**: **FREE**

## Cost by Usage Level

### Light Usage (Testing/Development)
```
Bedrock Agents:        $5
Titan Embeddings:      $0.10
RDS Aurora:            $12
Lambda:                $0.20
DynamoDB:              $1
S3:                    $0.10
API Gateway:           $0.50
Secrets Manager:       $0.40
CloudWatch:            $0.30
─────────────────────────
TOTAL:                 ~$20/month
```

### Moderate Usage (POC/Demo)
```
Bedrock Agents:        $10
Titan Embeddings:      $0.50
RDS Aurora:            $20
Lambda:                $1
DynamoDB:              $2
S3:                    $0.25
API Gateway:           $1
Secrets Manager:       $0.40
CloudWatch:            $0.50
─────────────────────────
TOTAL:                 ~$35/month
```

### Heavy Usage (Active Development)
```
Bedrock Agents:        $20
Titan Embeddings:      $1
RDS Aurora:            $30
Lambda:                $2
DynamoDB:              $5
S3:                    $0.50
API Gateway:           $2
Secrets Manager:       $0.40
CloudWatch:            $1
─────────────────────────
TOTAL:                 ~$62/month
```

## Cost Optimization Tips

### 1. RDS Aurora (Biggest Cost)
- ✅ Already using Serverless v2 (scales to zero)
- ✅ Min capacity set to 0.5 ACU
- 💡 Stop cluster when not in use: `aws rds stop-db-cluster --db-cluster-identifier cicd-agent-kb-cluster`

### 2. Bedrock Agents
- ✅ Using Nova Pro (cheaper than Claude)
- 💡 Use shorter prompts
- 💡 Cache knowledge base results

### 3. Lambda
- ✅ Already optimized (512 MB memory)
- 💡 Reduce timeout if possible

### 4. DynamoDB
- ✅ Using on-demand (no provisioned capacity)
- ✅ TTL enabled (auto-delete old items)

### 5. S3
- ✅ Minimal storage
- 💡 Enable lifecycle policies if needed

## Comparison with Alternatives

### If Using OpenSearch Serverless Instead of RDS

```
Current (RDS):         $35/month
With OpenSearch:       $210/month
Difference:            +$175/month (500% more expensive!)
```

### If Using Claude 3 Sonnet Instead of Nova Pro

```
Current (Nova Pro):    $35/month
With Claude Sonnet:    $55/month
Difference:            +$20/month (57% more expensive)
```

## Free Tier Benefits

Some services have free tiers (first 12 months):
- Lambda: 1M requests/month free
- DynamoDB: 25 GB storage free
- S3: 5 GB storage free
- API Gateway: 1M requests/month free

**With free tier**: ~$20-25/month
**Without free tier**: ~$35/month

## Cost Monitoring

### Set Up Billing Alerts

```bash
# Create SNS topic for alerts
aws sns create-topic --name billing-alerts

# Subscribe to alerts
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT_ID:billing-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com

# Create billing alarm (alert at $50)
aws cloudwatch put-metric-alarm \
  --alarm-name billing-alert-50 \
  --alarm-description "Alert when bill exceeds $50" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 21600 \
  --evaluation-periods 1 \
  --threshold 50 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions arn:aws:sns:us-east-1:ACCOUNT_ID:billing-alerts
```

### View Current Costs

```bash
# Get current month costs
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d "$(date +%Y-%m-01)" +%Y-%m-%d),End=$(date -u +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

## Cleanup to Reduce Costs

### Temporary Shutdown (Keep Infrastructure)

```bash
# Stop RDS cluster
aws rds stop-db-cluster --db-cluster-identifier cicd-agent-kb-cluster

# Savings: ~$20/month
```

### Complete Teardown

```bash
cd terraform
terraform destroy

# Savings: $35/month (everything)
```

## Summary

### Expected Monthly Cost: **$22 - $61**

**Typical POC usage: ~$35/month**

### Cost Breakdown:
- 🔴 **Highest**: RDS Aurora ($12-30) - 40% of total
- 🟡 **Medium**: Bedrock Agents ($5-20) - 30% of total
- 🟢 **Low**: Everything else ($5-11) - 30% of total

### Already Optimized:
- ✅ Using Nova Pro instead of Claude (-57% on LLM costs)
- ✅ Using RDS instead of OpenSearch (-83% on vector DB)
- ✅ Using Serverless v2 (scales to zero)
- ✅ Using on-demand DynamoDB
- ✅ Using HTTP API Gateway (cheaper than REST)

This is a **cost-optimized POC configuration** suitable for development and testing!
