# Knowledge Base Storage Options

## Important: S3-Only Vector Storage is NOT Supported

AWS Bedrock Knowledge Bases **does NOT support S3-only vector storage**. You must use a vector database.

## Why Not S3?

S3 stores the source documents (markdown files), but the vector embeddings must be stored in a vector database that supports similarity search.

## Architecture

```
S3 Bucket                    Vector Database
(Source docs)                (Embeddings)
     │                            │
     │                            │
     ├─ orchestrator/            ├─ orchestrator_embeddings table
     │  └─ guide.md              │  └─ vectors for similarity search
     │                            │
     ├─ bootstrap/               ├─ bootstrap_embeddings table
     │  └─ guide.md              │  └─ vectors
     │                            │
     └─ ...                      └─ ...
```

## Supported Vector Databases

### 1. OpenSearch Serverless (Default but Expensive)
- **Cost**: ~$175/month (24/7 OCU charges)
- **Pros**: Fully managed, fast, scalable
- **Cons**: Expensive for POC

### 2. RDS Aurora PostgreSQL with pgvector (Recommended for POC)
- **Cost**: ~$15-30/month (Serverless v2)
- **Pros**: Much cheaper, good performance, scales to zero
- **Cons**: Slightly more complex setup

### 3. Pinecone (External Service)
- **Cost**: Free tier available, then $70+/month
- **Pros**: Purpose-built for vectors
- **Cons**: External dependency

## Current Configuration: RDS Aurora

I've configured **RDS Aurora Serverless v2 with pgvector** because:

✅ **85% cheaper** than OpenSearch ($15-30/month vs $175/month)
✅ **Scales to zero** when not in use
✅ **Good performance** for POC workloads
✅ **AWS-native** - no external dependencies

## Cost Breakdown

### OpenSearch Serverless
```
Base OCU: 2 OCUs minimum
Cost: 2 OCUs × $0.24/hour × 730 hours = $350/month
With indexing: ~$175/month (optimized)
```

### RDS Aurora Serverless v2
```
Min capacity: 0.5 ACU
Max capacity: 1.0 ACU
Cost: 0.5 ACU × $0.12/hour × 730 hours = $44/month
With scale-to-zero: ~$15-30/month
```

**Savings: ~$145/month (83% reduction)**

## Configuration

### Current (RDS Aurora)

```hcl
storage_configuration {
  type = "RDS"
  rds_configuration {
    credentials_secret_arn = aws_secretsmanager_secret.kb_credentials.arn
    database_name          = "knowledge_base"
    resource_arn           = aws_rds_cluster.knowledge_base.arn
    table_name             = "orchestrator_embeddings"
    field_mapping {
      vector_field      = "embedding"
      text_field        = "text"
      metadata_field    = "metadata"
      primary_key_field = "id"
    }
  }
}
```

### If You Want OpenSearch (More Expensive)

```hcl
storage_configuration {
  type = "OPENSEARCH_SERVERLESS"
  opensearch_serverless_configuration {
    collection_arn    = aws_opensearchserverless_collection.kb.arn
    vector_index_name = "orchestrator-index"
    field_mapping {
      vector_field   = "vector"
      text_field     = "text"
      metadata_field = "metadata"
    }
  }
}
```

## How It Works

1. **Upload documents to S3**
   ```bash
   aws s3 sync knowledge_base/ s3://bucket/
   ```

2. **Bedrock syncs knowledge base**
   - Reads documents from S3
   - Generates embeddings using Titan
   - Stores embeddings in RDS Aurora

3. **Agent queries knowledge base**
   - Agent sends query
   - Bedrock generates query embedding
   - Searches RDS for similar vectors
   - Returns relevant documents

## Deployment

The current Terraform configuration deploys:
- ✅ RDS Aurora Serverless v2 cluster
- ✅ PostgreSQL with pgvector extension
- ✅ Secrets Manager for credentials
- ✅ IAM roles with RDS permissions
- ✅ 4 knowledge bases (one per agent)

## Switching to OpenSearch (If Needed)

If you need OpenSearch for production:

1. Update `terraform/bedrock_knowledge_base.tf`
2. Replace RDS configuration with OpenSearch
3. Run `terraform apply`

But for POC, RDS Aurora is recommended due to cost savings.

## Summary

- ❌ **S3-only vector storage**: Not supported by AWS Bedrock
- ✅ **RDS Aurora**: Cheapest option (~$15-30/month)
- ⚠️ **OpenSearch**: More expensive (~$175/month)
- 📁 **S3**: Still used for source documents

The current configuration uses RDS Aurora to minimize costs while maintaining full functionality.
