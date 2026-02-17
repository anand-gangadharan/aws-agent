#!/bin/bash
set -e

echo "==================================="
echo "Knowledge Base Sync Script"
echo "==================================="
echo ""

# Check if we're in the right directory
if [ ! -d "knowledge_base" ]; then
    echo "Error: knowledge_base directory not found"
    echo "Please run this script from the project root"
    exit 1
fi

# Check if terraform directory exists
if [ ! -d "terraform" ]; then
    echo "Error: terraform directory not found"
    exit 1
fi

# Get S3 bucket name from terraform output
echo "Getting S3 bucket name from Terraform..."
cd terraform

if [ ! -f "terraform.tfstate" ]; then
    echo "Error: Terraform state not found. Please run 'terraform apply' first"
    exit 1
fi

KB_BUCKET=$(terraform output -raw knowledge_base_bucket 2>/dev/null)

if [ -z "$KB_BUCKET" ]; then
    echo "Error: Could not get knowledge base bucket name from Terraform"
    echo "Make sure you've run 'terraform apply' successfully"
    exit 1
fi

cd ..

echo "S3 Bucket: $KB_BUCKET"
echo ""

# Upload files to S3
echo "Uploading knowledge base files to S3..."
aws s3 sync knowledge_base/ s3://$KB_BUCKET/ \
    --exclude "*.md~" \
    --exclude ".DS_Store" \
    --exclude "README.md" \
    --exclude "CUSTOMIZATION_GUIDE.md" \
    --content-type "text/markdown"

echo ""
echo "✓ Files uploaded successfully"
echo ""

# Get knowledge base IDs
echo "Getting knowledge base IDs..."
ORCH_KB_ID=$(cd terraform && terraform output -raw orchestrator_kb_id 2>/dev/null)
BOOT_KB_ID=$(cd terraform && terraform output -raw bootstrap_kb_id 2>/dev/null)
COMP_KB_ID=$(cd terraform && terraform output -raw compute_kb_id 2>/dev/null)
APP_KB_ID=$(cd terraform && terraform output -raw app_kb_id 2>/dev/null)

echo ""
echo "==================================="
echo "Next Steps"
echo "==================================="
echo ""
echo "Files have been uploaded to S3. Now you need to sync the knowledge bases:"
echo ""
echo "Option 1: Via AWS Console (Recommended for POC)"
echo "  1. Go to AWS Console → Bedrock → Knowledge bases"
echo "  2. Select each knowledge base and click 'Sync'"
echo "  3. Wait for sync to complete (usually 1-2 minutes)"
echo ""
echo "Option 2: Via AWS CLI"
echo ""

if [ -n "$ORCH_KB_ID" ]; then
    echo "# Sync Orchestrator KB"
    echo "aws bedrock-agent start-ingestion-job \\"
    echo "  --knowledge-base-id $ORCH_KB_ID \\"
    echo "  --data-source-id \$(aws bedrock-agent list-data-sources --knowledge-base-id $ORCH_KB_ID --query 'dataSourceSummaries[0].dataSourceId' --output text)"
    echo ""
fi

if [ -n "$BOOT_KB_ID" ]; then
    echo "# Sync Bootstrap KB"
    echo "aws bedrock-agent start-ingestion-job \\"
    echo "  --knowledge-base-id $BOOT_KB_ID \\"
    echo "  --data-source-id \$(aws bedrock-agent list-data-sources --knowledge-base-id $BOOT_KB_ID --query 'dataSourceSummaries[0].dataSourceId' --output text)"
    echo ""
fi

if [ -n "$COMP_KB_ID" ]; then
    echo "# Sync Compute KB"
    echo "aws bedrock-agent start-ingestion-job \\"
    echo "  --knowledge-base-id $COMP_KB_ID \\"
    echo "  --data-source-id \$(aws bedrock-agent list-data-sources --knowledge-base-id $COMP_KB_ID --query 'dataSourceSummaries[0].dataSourceId' --output text)"
    echo ""
fi

if [ -n "$APP_KB_ID" ]; then
    echo "# Sync App KB"
    echo "aws bedrock-agent start-ingestion-job \\"
    echo "  --knowledge-base-id $APP_KB_ID \\"
    echo "  --data-source-id \$(aws bedrock-agent list-data-sources --knowledge-base-id $APP_KB_ID --query 'dataSourceSummaries[0].dataSourceId' --output text)"
    echo ""
fi

echo "==================================="
echo ""
