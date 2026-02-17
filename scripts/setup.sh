#!/bin/bash
set -e

echo "Setting up CICD Agent Solution..."

# Check prerequisites
echo "Checking prerequisites..."
command -v python3 >/dev/null 2>&1 || { echo "Python 3 is required but not installed."; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "Terraform is required but not installed."; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "AWS CLI is required but not installed."; exit 1; }

# Create virtual environment
echo "Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
echo "Installing Python dependencies..."
pip install -r requirements.txt

# Initialize Terraform
echo "Initializing Terraform..."
cd terraform
terraform init

echo ""
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "1. Review and update terraform/terraform.tfvars if needed"
echo "2. Deploy infrastructure: cd terraform && terraform apply"
echo "3. Upload knowledge base documents to S3"
echo "4. Start MCP server: python src/mcp_server/http_server.py"
echo "5. Test via API Gateway endpoint"
