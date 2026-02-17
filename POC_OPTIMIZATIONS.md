# POC Optimizations

This document explains the optimizations made for POC deployment.

## Changes for POC

### 1. Vector Store: S3 Instead of OpenSearch Serverless

**Why S3?**
- ✅ Simpler setup - no need to manage OpenSearch collections
- ✅ Much cheaper - no hourly OCU charges (~$0.24/hour saved)
- ✅ Sufficient for POC - handles vector storage and retrieval
- ✅ Faster deployment - no collection provisioning wait time

**Cost Comparison**:
- OpenSearch Serverless: ~$175/month (24/7 running)
- S3 Vector Store: ~$1/month for POC usage

**Trade-offs**:
- S3 vector search is slightly slower than OpenSearch
- Fine for POC with limited documents
- For production with large knowledge bases, consider OpenSearch

### 2. LLM: AWS Nova Pro

**Why Nova Pro?**
- ✅ AWS-native model - optimized for AWS services
- ✅ Cost-effective - ~75% cheaper than Claude 3 Sonnet
- ✅ Fast inference - lower latency
- ✅ Good for agent tasks - designed for tool use and reasoning
- ✅ Supports function calling natively

**Cost Comparison** (per 1M tokens):
- Claude 3 Sonnet: $3 input / $15 output
- Nova Pro: $0.80 input / $3.20 output

**Capabilities**:
- 300K token context window
- Strong reasoning and planning
- Native tool/function calling
- Multilingual support
- Good instruction following

**When to use Claude instead**:
- Need highest quality reasoning
- Complex multi-step planning
- Production workloads requiring best performance

### 3. Embeddings: Titan Embeddings v2

**Why Titan v2?**
- ✅ AWS-native - seamless integration
- ✅ Cost-effective - $0.0001 per 1K tokens
- ✅ Good quality - 1024 dimensions
- ✅ Optimized for RAG use cases

## POC Cost Breakdown

### Daily Costs (Moderate Testing)

```
Component                    Cost/Day
─────────────────────────────────────
Nova Pro (agents)            $0.50
Titan Embeddings v2          $0.10
S3 (storage + vectors)       $0.05
DynamoDB (on-demand)         $0.20
Lambda (invocations)         $0.15
API Gateway                  $0.10
─────────────────────────────────────
TOTAL                        ~$1.10/day
```

### Monthly Estimate: ~$33/month

Compare to OpenSearch version: ~$200/month

**Savings: ~$167/month (83% reduction)**

## Configuration

### Current Settings

**File**: `terraform/variables.tf`
```hcl
variable "bedrock_model_id" {
  default = "us.amazon.nova-pro-v1:0"
}
```

**File**: `terraform/bedrock_knowledge_base.tf`
```hcl
storage_configuration {
  type = "S3"
  s3_configuration {
    bucket_arn = aws_s3_bucket.knowledge_base.arn
  }
}

embedding_model_arn = "...amazon.titan-embed-text-v2:0"
```

## Upgrading to Production

When moving from POC to production, consider:

### 1. Switch to OpenSearch Serverless (Optional)

If you have:
- Large knowledge bases (>10K documents)
- High query volume
- Need sub-second search latency

Update `terraform/bedrock_knowledge_base.tf`:
```hcl
storage_configuration {
  type = "OPENSEARCH_SERVERLESS"
  opensearch_serverless_configuration {
    collection_arn = aws_opensearchserverless_collection.kb.arn
    vector_index_name = "agent-index"
    field_mapping {
      vector_field   = "vector"
      text_field     = "text"
      metadata_field = "metadata"
    }
  }
}
```

### 2. Consider Claude 3 Sonnet (Optional)

If you need:
- Highest quality reasoning
- Complex decision-making
- Best-in-class performance

Update `terraform/variables.tf`:
```hcl
variable "bedrock_model_id" {
  default = "anthropic.claude-3-sonnet-20240229-v1:0"
}
```

### 3. Add Production Features

- Authentication (Cognito)
- Rate limiting
- Monitoring and alerting
- Multi-region deployment
- Backup and disaster recovery
- Enhanced guardrails

## Model Access Requirements

Before deploying, enable model access in AWS Console:

1. Go to AWS Console → Bedrock → Model access
2. Request access to:
   - ✅ Amazon Nova Pro (`us.amazon.nova-pro-v1:0`)
   - ✅ Amazon Titan Embeddings v2 (`amazon.titan-embed-text-v2:0`)
3. Wait for approval (usually instant)

## Testing the Configuration

After deployment, verify:

```bash
# Check agents are using Nova Pro
aws bedrock-agent get-agent --agent-id <orchestrator-id> \
  | jq '.agent.foundationModel'
# Should show: "us.amazon.nova-pro-v1:0"

# Check knowledge bases are using S3
aws bedrock-agent get-knowledge-base --knowledge-base-id <kb-id> \
  | jq '.knowledgeBase.storageConfiguration.type'
# Should show: "S3"

# Check embeddings model
aws bedrock-agent get-knowledge-base --knowledge-base-id <kb-id> \
  | jq '.knowledgeBase.knowledgeBaseConfiguration.vectorKnowledgeBaseConfiguration.embeddingModelArn'
# Should show: "...titan-embed-text-v2:0"
```

## Performance Expectations

### S3 Vector Store
- Search latency: 100-500ms
- Sufficient for: <10K documents
- Concurrent queries: Moderate

### Nova Pro
- Response time: 1-3 seconds
- Quality: Good for most agent tasks
- Token throughput: High

### Overall System
- End-to-end request: 3-10 seconds
- Depends on: Pipeline complexity, agent chain length
- Acceptable for: POC and demo purposes

## Limitations

### POC Configuration Limitations

1. **S3 Vector Store**
   - Not optimized for very large knowledge bases
   - Slower than OpenSearch for complex queries
   - Limited filtering capabilities

2. **Nova Pro**
   - Slightly lower reasoning quality than Claude 3 Sonnet
   - May struggle with very complex multi-step planning
   - Less tested in production than Claude

3. **No Authentication**
   - Open API Gateway endpoint
   - Suitable for POC only
   - Add auth before production

### When to Upgrade

Upgrade from POC configuration when:
- Knowledge base grows beyond 10K documents
- Need sub-100ms search latency
- Require highest quality reasoning
- Moving to production
- Need compliance/security features

## Summary

The POC configuration provides:
- ✅ 83% cost reduction vs OpenSearch version
- ✅ Simpler deployment and management
- ✅ Sufficient performance for POC
- ✅ Easy upgrade path to production
- ✅ Full LLM-driven orchestration capabilities

Perfect for:
- Proof of concept
- Demos and presentations
- Development and testing
- Learning Bedrock Agents

Not suitable for:
- Production workloads (without upgrades)
- High-scale deployments
- Mission-critical systems
- Compliance-heavy environments
