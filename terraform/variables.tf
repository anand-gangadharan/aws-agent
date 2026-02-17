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

variable "gitlab_url" {
  description = "GitLab URL"
  type        = string
  default     = "https://gitlab.com"
}

variable "gitlab_token" {
  description = "GitLab API token (use STUB_TOKEN for POC)"
  type        = string
  default     = "STUB_TOKEN"
  sensitive   = true
}

variable "gitlab_project_id" {
  description = "GitLab project ID"
  type        = string
  default     = "STUB_PROJECT_ID"
}
