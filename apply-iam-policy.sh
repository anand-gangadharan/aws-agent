#!/bin/bash
set -e

echo "=========================================="
echo "Apply IAM Policy for CICD Agent Project"
echo "=========================================="
echo ""

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
echo "Account ID: $ACCOUNT_ID"

# Get current user
CURRENT_USER=$(aws sts get-caller-identity --query 'Arn' --output text | cut -d'/' -f2)
echo "IAM User: $CURRENT_USER"
echo ""

# Update account ID in policy file
echo "Updating policy with your account ID..."
sed "s/992382398545/$ACCOUNT_ID/g" iam-policy-complete.json > /tmp/iam-policy-updated.json

# Create policy
echo "Creating IAM policy..."
POLICY_ARN=$(aws iam create-policy \
    --policy-name CICDAgentCompletePolicy \
    --policy-document file:///tmp/iam-policy-updated.json \
    --description "Complete permissions for CICD Agent Bedrock project" \
    --query 'Policy.Arn' \
    --output text 2>&1)

if echo "$POLICY_ARN" | grep -q "EntityAlreadyExists"; then
    echo "Policy already exists, using existing policy..."
    POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/CICDAgentCompletePolicy"
    
    # Update existing policy
    echo "Updating existing policy..."
    VERSIONS=$(aws iam list-policy-versions --policy-arn $POLICY_ARN --query 'Versions[?IsDefaultVersion==`false`].VersionId' --output text)
    
    # Delete old versions if at limit (max 5 versions)
    VERSION_COUNT=$(aws iam list-policy-versions --policy-arn $POLICY_ARN --query 'length(Versions)' --output text)
    if [ "$VERSION_COUNT" -ge 5 ]; then
        OLDEST_VERSION=$(aws iam list-policy-versions --policy-arn $POLICY_ARN --query 'Versions[-1].VersionId' --output text)
        echo "Deleting oldest policy version: $OLDEST_VERSION"
        aws iam delete-policy-version --policy-arn $POLICY_ARN --version-id $OLDEST_VERSION
    fi
    
    aws iam create-policy-version \
        --policy-arn $POLICY_ARN \
        --policy-document file:///tmp/iam-policy-updated.json \
        --set-as-default
    
    echo "✓ Policy updated"
else
    echo "✓ Policy created: $POLICY_ARN"
fi

# Attach policy to user
echo ""
echo "Attaching policy to user: $CURRENT_USER"
aws iam attach-user-policy \
    --user-name $CURRENT_USER \
    --policy-arn $POLICY_ARN 2>&1 || echo "Policy might already be attached"

echo "✓ Policy attached"

# Cleanup
rm /tmp/iam-policy-updated.json

echo ""
echo "=========================================="
echo "✓ Done!"
echo "=========================================="
echo ""
echo "Policy ARN: $POLICY_ARN"
echo ""
echo "Verify attached policies:"
aws iam list-attached-user-policies --user-name $CURRENT_USER --query 'AttachedPolicies[*].[PolicyName,PolicyArn]' --output table

echo ""
echo "You can now run: cd terraform && terraform apply"
echo ""
