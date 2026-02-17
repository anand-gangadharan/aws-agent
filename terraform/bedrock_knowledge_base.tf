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
      }
    ]
  })
}

# Knowledge bases for each agent using S3 vector store
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
    type = "S3"
    s3_configuration {
      bucket_arn = aws_s3_bucket.knowledge_base.arn
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
    type = "S3"
    s3_configuration {
      bucket_arn = aws_s3_bucket.knowledge_base.arn
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
    type = "S3"
    s3_configuration {
      bucket_arn = aws_s3_bucket.knowledge_base.arn
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
    type = "S3"
    s3_configuration {
      bucket_arn = aws_s3_bucket.knowledge_base.arn
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
