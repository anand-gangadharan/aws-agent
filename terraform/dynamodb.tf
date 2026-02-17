# DynamoDB table for short-term memory
resource "aws_dynamodb_table" "memory" {
  name           = "${var.project_name}-memory"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "session_id"
  range_key      = "timestamp"

  attribute {
    name = "session_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  attribute {
    name = "environment"
    type = "S"
  }

  attribute {
    name = "tenant_id"
    type = "S"
  }

  global_secondary_index {
    name            = "environment-index"
    hash_key        = "environment"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "tenant-index"
    hash_key        = "tenant_id"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name        = "${var.project_name}-memory"
    Environment = var.environment
  }
}
