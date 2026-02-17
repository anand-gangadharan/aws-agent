# Upload knowledge base markdown files to S3
# This ensures the files are automatically synced when you run terraform apply

# Upload orchestrator knowledge base files
resource "aws_s3_object" "orchestrator_docs" {
  for_each = fileset("${path.module}/../knowledge_base/orchestrator", "**/*.md")
  
  bucket = aws_s3_bucket.knowledge_base.id
  key    = "orchestrator/${each.value}"
  source = "${path.module}/../knowledge_base/orchestrator/${each.value}"
  etag   = filemd5("${path.module}/../knowledge_base/orchestrator/${each.value}")
  
  content_type = "text/markdown"
}

# Upload bootstrap knowledge base files
resource "aws_s3_object" "bootstrap_docs" {
  for_each = fileset("${path.module}/../knowledge_base/bootstrap", "**/*.md")
  
  bucket = aws_s3_bucket.knowledge_base.id
  key    = "bootstrap/${each.value}"
  source = "${path.module}/../knowledge_base/bootstrap/${each.value}"
  etag   = filemd5("${path.module}/../knowledge_base/bootstrap/${each.value}")
  
  content_type = "text/markdown"
}

# Upload compute knowledge base files
resource "aws_s3_object" "compute_docs" {
  for_each = fileset("${path.module}/../knowledge_base/compute", "**/*.md")
  
  bucket = aws_s3_bucket.knowledge_base.id
  key    = "compute/${each.value}"
  source = "${path.module}/../knowledge_base/compute/${each.value}"
  etag   = filemd5("${path.module}/../knowledge_base/compute/${each.value}")
  
  content_type = "text/markdown"
}

# Upload app knowledge base files
resource "aws_s3_object" "app_docs" {
  for_each = fileset("${path.module}/../knowledge_base/app", "**/*.md")
  
  bucket = aws_s3_bucket.knowledge_base.id
  key    = "app/${each.value}"
  source = "${path.module}/../knowledge_base/app/${each.value}"
  etag   = filemd5("${path.module}/../knowledge_base/app/${each.value}")
  
  content_type = "text/markdown"
}

# Output to help with manual sync if needed
output "knowledge_base_sync_command" {
  value = "aws s3 sync ../knowledge_base/ s3://${aws_s3_bucket.knowledge_base.id}/"
  description = "Command to manually sync knowledge base files to S3"
}
