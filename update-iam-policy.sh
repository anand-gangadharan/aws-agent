#!/bin/bash
set -e

ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
CURRENT_USER=$(aws sts get-caller-identity --query 'Arn' --output text | cut -d'/' -f2)

echo "Updating IAM policy for account: $ACCOUNT_ID"

# Update account ID in policy
sed "s/992382398545/$ACCOUNT_ID/g" iam-policy-complete.json > /tmp/iam-policy-updated.json

POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/CICDAgentCompletePolicy"

# Delete oldest version if at limit
VERSION_COUNT=$(aws iam list-policy-versions --policy-arn $POLICY_ARN --query 'length(Versions)' --output text 2>/dev/null || echo "0")

if [ "$VERSION_COUNT" -ge 5 ]; then
    OLDEST=$(aws iam list-policy-versions --policy-arn $POLICY_ARN --query 'Versions[-1].VersionId' --output text)
    aws iam delete-policy-version --policy-arn $POLICY_ARN --version-id $OLDEST
fi

# Create new version
aws iam create-policy-version \
    --policy-arn $POLICY_ARN \
    --policy-document file:///tmp/iam-policy-updated.json \
    --set-as-default

rm /tmp/iam-policy-updated.json

echo "✓ Policy updated successfully"
echo "Run: cd terraform && terraform apply"
