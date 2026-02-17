# S3 bucket for knowledge base
resource "aws_s3_bucket" "knowledge_base" {
  bucket = "${var.project_name}-kb-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "knowledge_base" {
  bucket = aws_s3_bucket.knowledge_base.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Separate prefixes for each agent's knowledge base
resource "aws_s3_object" "kb_folders" {
  for_each = toset(["orchestrator", "bootstrap", "compute", "app"])
  
  bucket = aws_s3_bucket.knowledge_base.id
  key    = "${each.key}/"
}
