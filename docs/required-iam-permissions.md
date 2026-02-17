# Required IAM Permissions

## Error: RDS Access Denied

If you see this error:
```
User: arn:aws:iam::ACCOUNT:user/USERNAME is not authorized to perform: rds:CreateDBCluster
```

You need to add RDS permissions to your IAM user.

## Solution Options

### Option 1: Quick Fix (Managed Policy)

Attach the AWS managed policy:

```bash
aws iam attach-user-policy \
  --user-name anand \
  --policy-arn arn:aws:iam::aws:policy/AmazonRDSFullAccess
```

**Pros**: Quick, works immediately
**Cons**: Grants more permissions than needed

### Option 2: Minimal Permissions (Recommended)

Create a custom policy with only required permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "RDSForBedrockKnowledgeBase",
      "Effect": "Allow",
      "Action": [
        "rds:CreateDBCluster",
        "rds:CreateDBInstance",
        "rds:DescribeDBClusters",
        "rds:DescribeDBInstances",
        "rds:ModifyDBCluster",
        "rds:ModifyDBInstance",
        "rds:DeleteDBCluster",
        "rds:DeleteDBInstance",
        "rds:AddTagsToResource",
        "rds:ListTagsForResource"
      ],
      "Resource": [
        "arn:aws:rds:*:*:cluster:cicd-agent-*",
        "arn:aws:rds:*:*:db:cicd-agent-*"
      ]
    },
    {
      "Sid": "SecretsManagerForRDS",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:CreateSecret",
        "secretsmanager:DeleteSecret",
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue",
        "secretsmanager:PutSecretValue",
        "secretsmanager:TagResource"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:cicd-agent-*"
    }
  ]
}
```

Save this as `iam-policy.json` and apply:

```bash
# Create the policy
aws iam create-policy \
  --policy-name CICDAgentRDSPolicy \
  --policy-document file://iam-policy.json

# Attach to your user
aws iam attach-user-policy \
  --user-name anand \
  --policy-arn arn:aws:iam::992382398545:policy/CICDAgentRDSPolicy
```

## Complete IAM Permissions Needed

For the entire project, you need permissions for:

### 1. Core Services (You likely already have these)
- ✅ Lambda
- ✅ IAM
- ✅ S3
- ✅ DynamoDB
- ✅ API Gateway
- ✅ CloudWatch Logs

### 2. Bedrock (Required)
- ✅ Bedrock Agents
- ✅ Bedrock Knowledge Bases
- ✅ Bedrock Model Access

### 3. RDS (Missing - causing the error)
- ❌ RDS Cluster creation
- ❌ RDS Instance creation
- ❌ Secrets Manager (for RDS credentials)

## Verify Your Permissions

Check what policies you currently have:

```bash
# List attached policies
aws iam list-attached-user-policies --user-name anand

# List inline policies
aws iam list-user-policies --user-name anand
```

## After Adding RDS Permissions

Run terraform again:

```bash
cd terraform
terraform apply
```

## Alternative: Use Administrator Access (Not Recommended for Production)

If this is just for POC/testing:

```bash
aws iam attach-user-policy \
  --user-name anand \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

**Warning**: This grants full access to everything. Only use for POC/testing.

## Troubleshooting

### Check if policy is attached

```bash
aws iam list-attached-user-policies --user-name anand | grep RDS
```

### Test RDS permissions

```bash
aws rds describe-db-clusters --region us-east-1
```

If this works without error, you have RDS read permissions.

## Summary

**Quick answer**: Yes, adding `AmazonRDSFullAccess` will resolve the issue.

**Recommended approach**:
1. Add `AmazonRDSFullAccess` for now (quick fix)
2. Run `terraform apply`
3. Later, replace with minimal custom policy (better security)

```bash
# Quick fix
aws iam attach-user-policy \
  --user-name anand \
  --policy-arn arn:aws:iam::aws:policy/AmazonRDSFullAccess

# Then retry
cd terraform && terraform apply
```
