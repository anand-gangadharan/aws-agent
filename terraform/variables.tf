variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "cicd-agent"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "poc"
}

variable "bedrock_model_id" {
  description = "Bedrock model ID for agents"
  type        = string
  default     = "us.amazon.nova-pro-v1:0"
}
