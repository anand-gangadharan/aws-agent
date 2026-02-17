#!/bin/bash
set -e

echo "=========================================="
echo "Add RDS Permissions to IAM User"
echo "=========================================="
echo ""

# Get current user
CURRENT_USER=$(aws sts get-caller-identity --query 'Arn' --output text | cut -d'/' -f2)
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)

echo "Current IAM User: $CURRENT_USER"
echo "Account ID: $ACCOUNT_ID"
echo ""

# Ask user which option
echo "Choose an option:"
echo "1. Quick Fix - Add AmazonRDSFullAccess (recommended for POC)"
echo "2. Minimal Permissions - Add custom policy (more secure)"
echo ""
read -p "Enter choice (1 or 2): " choice

if [ "$choice" == "1" ]; then
    echo ""
    echo "Adding AmazonRDSFullAccess managed policy..."
    
    aws iam attach-user-policy \
        --user-name $CURRENT_USER \
        --policy-arn arn:aws:iam::aws:policy/AmazonRDSFullAccess
    
    echo "✓ AmazonRDSFullAccess attached successfully"
    
elif [ "$choice" == "2" ]; then
    echo ""
    echo "Creating minimal custom policy..."
    
    # Update account ID in policy file
    sed "s/992382398545/$ACCOUNT_ID/g" iam-policy-minimal.json > /tmp/iam-policy-temp.json
    
    # Create policy
    POLICY_ARN=$(aws iam create-policy \
        --policy-name CICDAgentRDSPolicy \
        --policy-document file:///tmp/iam-policy-temp.json \
        --query 'Policy.Arn' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$POLICY_ARN" ]; then
        echo "Policy might already exist, trying to get ARN..."
        POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/CICDAgentRDSPolicy"
    fi
    
    echo "Policy ARN: $POLICY_ARN"
    
    # Attach policy
    aws iam attach-user-policy \
        --user-name $CURRENT_USER \
        --policy-arn $POLICY_ARN
    
    echo "✓ Custom policy attached successfully"
    
    # Cleanup
    rm /tmp/iam-policy-temp.json
else
    echo "Invalid choice. Exiting."
    exit 1
fi

echo ""
echo "=========================================="
echo "Verifying permissions..."
echo "=========================================="

# List attached policies
echo ""
echo "Attached policies:"
aws iam list-attached-user-policies --user-name $CURRENT_USER \
    | grep -E "(PolicyName|PolicyArn)" || echo "Could not list policies"

echo ""
echo "=========================================="
echo "✓ Done!"
echo "=========================================="
echo ""
echo "You can now run: cd terraform && terraform apply"
echo ""
