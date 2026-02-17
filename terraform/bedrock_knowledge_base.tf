# Knowledge base IAM role
resource "aws_iam_role" "knowledge_base" {
  name = "${var.project_name}-kb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "bedrock.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "knowledge_base" {
  name = "${var.project_name}-kb-policy"
  role = aws_iam_role.knowledge_base.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.knowledge_base.arn,
          "${aws_s3_bucket.knowledge_base.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/amazon.titan-embed-text-v2:0"
      },
      {
        Effect = "Allow"
        Action = [
          "rds-data:ExecuteStatement",
          "rds-data:BatchExecuteStatement"
        ]
        Resource = aws_rds_cluster.knowledge_base.arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.kb_credentials.arn
      }
    ]
  })
}

# RDS Aurora Serverless v2 with pgvector (MUCH cheaper than OpenSearch)
# Cost: ~$15-30/month vs $175/month for OpenSearch
resource "aws_rds_cluster" "knowledge_base" {
  cluster_identifier      = "${var.project_name}-kb-cluster"
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned"
  engine_version          = "15.4"
  database_name           = "knowledge_base"
  master_username         = "kbadmin"
  master_password         = random_password.kb_password.result
  skip_final_snapshot     = true
  enable_http_endpoint    = true
  
  serverlessv2_scaling_configuration {
    max_capacity = 1.0
    min_capacity = 0.5
  }
}

resource "aws_rds_cluster_instance" "knowledge_base" {
  identifier         = "${var.project_name}-kb-instance"
  cluster_identifier = aws_rds_cluster.knowledge_base.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.knowledge_base.engine
  engine_version     = aws_rds_cluster.knowledge_base.engine_version
}

resource "random_password" "kb_password" {
  length  = 16
  special = true
}

resource "aws_secretsmanager_secret" "kb_credentials" {
  name = "${var.project_name}-kb-credentials"
}

resource "aws_secretsmanager_secret_version" "kb_credentials" {
  secret_id = aws_secretsmanager_secret.kb_credentials.id
  secret_string = jsonencode({
    username = aws_rds_cluster.knowledge_base.master_username
    password = aws_rds_cluster.knowledge_base.master_password
  })
}

# Knowledge bases using RDS Aurora (cheaper than OpenSearch)
resource "aws_bedrockagent_knowledge_base" "orchestrator" {
  name     = "${var.project_name}-orchestrator-kb"
  role_arn = aws_iam_role.knowledge_base.arn
  
  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/amazon.titan-embed-text-v2:0"
    }
  }
  
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
}

resource "aws_bedrockagent_data_source" "orchestrator" {
  name              = "orchestrator-docs"
  knowledge_base_id = aws_bedrockagent_knowledge_base.orchestrator.id
  
  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn         = aws_s3_bucket.knowledge_base.arn
      inclusion_prefixes = ["orchestrator/"]
    }
  }
}

resource "aws_bedrockagent_knowledge_base" "bootstrap" {
  name     = "${var.project_name}-bootstrap-kb"
  role_arn = aws_iam_role.knowledge_base.arn
  
  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/amazon.titan-embed-text-v2:0"
    }
  }
  
  storage_configuration {
    type = "RDS"
    rds_configuration {
      credentials_secret_arn = aws_secretsmanager_secret.kb_credentials.arn
      database_name          = "knowledge_base"
      resource_arn           = aws_rds_cluster.knowledge_base.arn
      table_name             = "bootstrap_embeddings"
      field_mapping {
        vector_field      = "embedding"
        text_field        = "text"
        metadata_field    = "metadata"
        primary_key_field = "id"
      }
    }
  }
}

resource "aws_bedrockagent_data_source" "bootstrap" {
  name              = "bootstrap-docs"
  knowledge_base_id = aws_bedrockagent_knowledge_base.bootstrap.id
  
  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn         = aws_s3_bucket.knowledge_base.arn
      inclusion_prefixes = ["bootstrap/"]
    }
  }
}

resource "aws_bedrockagent_knowledge_base" "compute" {
  name     = "${var.project_name}-compute-kb"
  role_arn = aws_iam_role.knowledge_base.arn
  
  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/amazon.titan-embed-text-v2:0"
    }
  }
  
  storage_configuration {
    type = "RDS"
    rds_configuration {
      credentials_secret_arn = aws_secretsmanager_secret.kb_credentials.arn
      database_name          = "knowledge_base"
      resource_arn           = aws_rds_cluster.knowledge_base.arn
      table_name             = "compute_embeddings"
      field_mapping {
        vector_field      = "embedding"
        text_field        = "text"
        metadata_field    = "metadata"
        primary_key_field = "id"
      }
    }
  }
}

resource "aws_bedrockagent_data_source" "compute" {
  name              = "compute-docs"
  knowledge_base_id = aws_bedrockagent_knowledge_base.compute.id
  
  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn         = aws_s3_bucket.knowledge_base.arn
      inclusion_prefixes = ["compute/"]
    }
  }
}

resource "aws_bedrockagent_knowledge_base" "app" {
  name     = "${var.project_name}-app-kb"
  role_arn = aws_iam_role.knowledge_base.arn
  
  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/amazon.titan-embed-text-v2:0"
    }
  }
  
  storage_configuration {
    type = "RDS"
    rds_configuration {
      credentials_secret_arn = aws_secretsmanager_secret.kb_credentials.arn
      database_name          = "knowledge_base"
      resource_arn           = aws_rds_cluster.knowledge_base.arn
      table_name             = "app_embeddings"
      field_mapping {
        vector_field      = "embedding"
        text_field        = "text"
        metadata_field    = "metadata"
        primary_key_field = "id"
      }
    }
  }
}

resource "aws_bedrockagent_data_source" "app" {
  name              = "app-docs"
  knowledge_base_id = aws_bedrockagent_knowledge_base.app.id
  
  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn         = aws_s3_bucket.knowledge_base.arn
      inclusion_prefixes = ["app/"]
    }
  }
}

# Outputs
output "orchestrator_kb_id" {
  value = aws_bedrockagent_knowledge_base.orchestrator.id
}

output "bootstrap_kb_id" {
  value = aws_bedrockagent_knowledge_base.bootstrap.id
}

output "compute_kb_id" {
  value = aws_bedrockagent_knowledge_base.compute.id
}

output "app_kb_id" {
  value = aws_bedrockagent_knowledge_base.app.id
}
