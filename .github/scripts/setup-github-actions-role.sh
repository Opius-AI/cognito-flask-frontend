#!/bin/bash

# Setup IAM Role for GitHub Actions with OIDC
set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}GitHub Actions IAM Role Setup${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=${AWS_REGION:-us-east-2}

echo -e "${GREEN}✓ AWS Account: ${ACCOUNT_ID}${NC}"
echo -e "${GREEN}✓ AWS Region: ${REGION}${NC}\n"

# Prompt for GitHub repository
read -p "Enter your GitHub repository (format: username/repo-name): " GITHUB_REPO

if [ -z "$GITHUB_REPO" ]; then
    echo -e "${RED}Error: GitHub repository is required${NC}"
    exit 1
fi

echo -e "\n${BLUE}Creating OIDC Identity Provider...${NC}"

# Check if OIDC provider already exists
OIDC_PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN" &> /dev/null; then
    echo -e "${YELLOW}OIDC provider already exists${NC}"
else
    aws iam create-open-id-connect-provider \
      --url https://token.actions.githubusercontent.com \
      --client-id-list sts.amazonaws.com \
      --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
      > /dev/null
    echo -e "${GREEN}✓ OIDC provider created${NC}"
fi

# Create trust policy
echo -e "\n${BLUE}Creating IAM trust policy...${NC}"
cat > /tmp/github-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF

# Create IAM role
echo -e "${BLUE}Creating IAM role...${NC}"
ROLE_NAME="GitHubActionsDeployRole"

if aws iam get-role --role-name "$ROLE_NAME" &> /dev/null; then
    echo -e "${YELLOW}Role already exists, updating trust policy...${NC}"
    aws iam update-assume-role-policy \
      --role-name "$ROLE_NAME" \
      --policy-document file:///tmp/github-trust-policy.json
else
    aws iam create-role \
      --role-name "$ROLE_NAME" \
      --assume-role-policy-document file:///tmp/github-trust-policy.json \
      > /dev/null
    echo -e "${GREEN}✓ IAM role created${NC}"
fi

# Get task execution role ARNs
echo -e "\n${BLUE}Retrieving ECS task role ARNs...${NC}"
TASK_EXECUTION_ROLE=$(aws iam list-roles --query "Roles[?contains(RoleName, 'EcsStackFlaskAuthServiceTaskDef')].Arn" --output text)
TASK_ROLE=$(aws iam list-roles --query "Roles[?contains(RoleName, 'EcsStackFlaskAuthServiceTaskRole')].Arn" --output text)

if [ -z "$TASK_EXECUTION_ROLE" ] || [ -z "$TASK_ROLE" ]; then
    echo -e "${YELLOW}Warning: Could not find ECS task roles. Using wildcard pattern.${NC}"
    TASK_EXECUTION_ROLE="arn:aws:iam::${ACCOUNT_ID}:role/InfrastructureStack-EcsStackFlaskAuthServiceTaskDef*"
    TASK_ROLE="arn:aws:iam::${ACCOUNT_ID}:role/InfrastructureStack-EcsStackFlaskAuthServiceTaskRole*"
fi

# Create permissions policy
echo -e "\n${BLUE}Creating permissions policy...${NC}"
cat > /tmp/github-permissions-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "ecs:DescribeTasks",
        "ecs:ListTasks",
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": [
        "${TASK_EXECUTION_ROLE}",
        "${TASK_ROLE}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Attach policy to role
aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name GitHubActionsDeployPolicy \
  --policy-document file:///tmp/github-permissions-policy.json

echo -e "${GREEN}✓ Permissions policy attached${NC}"

# Clean up temp files
rm /tmp/github-trust-policy.json
rm /tmp/github-permissions-policy.json

# Get role ARN
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${BLUE}Next Steps:${NC}\n"
echo -e "1. Add the following secret to your GitHub repository:"
echo -e "   ${YELLOW}Settings > Secrets and variables > Actions > New repository secret${NC}\n"
echo -e "   Name: ${GREEN}AWS_ROLE_TO_ASSUME${NC}"
echo -e "   Value: ${GREEN}${ROLE_ARN}${NC}\n"
echo -e "2. Update the ECS service name in .github/workflows/deploy.yml if needed\n"
echo -e "3. Push code to main/master branch or manually trigger the workflow\n"

echo -e "${BLUE}To get your ECS service name:${NC}"
echo -e "${YELLOW}aws ecs list-services --cluster flask-auth-cluster --region ${REGION}${NC}\n"
