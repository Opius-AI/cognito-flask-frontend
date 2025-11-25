# GitHub Actions Setup Guide

This guide explains how to configure GitHub Actions to automatically build and deploy your Flask application to AWS ECS.

## Prerequisites

- GitHub repository with the code
- AWS account with ECS infrastructure deployed
- AWS CLI installed and configured locally

## Setup Steps

### 1. Create IAM OIDC Identity Provider

First, set up GitHub as an OIDC identity provider in AWS:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 2. Create IAM Role for GitHub Actions

Create a trust policy file `github-trust-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::638596943304:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/YOUR_REPO_NAME:*"
        }
      }
    }
  ]
}
```

**IMPORTANT**: Replace `YOUR_GITHUB_USERNAME/YOUR_REPO_NAME` with your actual GitHub repository path (e.g., `octocat/flask-auth-app`).

Create the IAM role:

```bash
aws iam create-role \
  --role-name GitHubActionsDeployRole \
  --assume-role-policy-document file://github-trust-policy.json
```

### 3. Attach Permissions to the Role

Create a permissions policy file `github-permissions-policy.json`:

```json
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
        "arn:aws:iam::638596943304:role/InfrastructureStack-EcsStackFlaskAuthServiceTaskDef*",
        "arn:aws:iam::638596943304:role/InfrastructureStack-EcsStackFlaskAuthServiceTaskRole*"
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
```

Attach the policy to the role:

```bash
aws iam put-role-policy \
  --role-name GitHubActionsDeployRole \
  --policy-name GitHubActionsDeployPolicy \
  --policy-document file://github-permissions-policy.json
```

### 4. Configure GitHub Repository Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** > **Secrets and variables** > **Actions**
3. Click **New repository secret**
4. Add the following secret:

   - **Name**: `AWS_ROLE_TO_ASSUME`
   - **Value**: `arn:aws:iam::638596943304:role/GitHubActionsDeployRole`

### 5. Update Workflow Configuration (if needed)

The workflow file `.github/workflows/deploy.yml` is already configured. However, you may need to update:

- **ECS_SERVICE**: The exact ECS service name (currently set to `InfrastructureStack-EcsStackFlaskAuthServiceServiceF0712F02-CsEAm2A7Tm0G`)
- **AWS_REGION**: If you deployed to a different region (currently `us-east-2`)
- **ECR_REPOSITORY**: If you used a different repository name (currently `flask-auth-app`)

To get your exact ECS service name:

```bash
aws ecs list-services --cluster flask-auth-cluster --region us-east-2
```

## How the Workflow Works

### Trigger Events

The workflow runs automatically on:
- Push to `main` or `master` branch
- Manual trigger via GitHub Actions UI (workflow_dispatch)

### Workflow Steps

1. **Checkout code**: Downloads repository code
2. **Configure AWS credentials**: Assumes IAM role via OIDC
3. **Login to ECR**: Authenticates with Amazon ECR
4. **Build and push image**:
   - Builds Docker image for AMD64 architecture
   - Tags with commit SHA and `latest`
   - Pushes both tags to ECR
5. **Download task definition**: Gets current ECS task definition
6. **Update task definition**: Injects new image URI
7. **Deploy to ECS**: Updates ECS service with new task definition
8. **Wait for stability**: Monitors deployment until stable

### Deployment Summary

After each deployment, GitHub Actions generates a summary showing:
- AWS Region
- ECS Cluster and Service
- Deployed image URI
- Commit SHA

## Security Best Practices

1. **Use OIDC instead of long-lived credentials**: This workflow uses OpenID Connect for secure, temporary credentials
2. **Least privilege IAM permissions**: The role only has permissions needed for deployment
3. **Repository-specific trust policy**: The IAM role can only be assumed by your specific GitHub repository
4. **No secrets in code**: AWS credentials are never stored in the repository

## Testing the Workflow

### Manual Test

1. Go to your GitHub repository
2. Click **Actions** tab
3. Select **Deploy to AWS ECS** workflow
4. Click **Run workflow**
5. Select branch and click **Run workflow**

### Automatic Test

Simply push a commit to the `main` or `master` branch:

```bash
git add .
git commit -m "Test GitHub Actions deployment"
git push origin main
```

## Monitoring Deployments

### In GitHub

- Navigate to **Actions** tab
- Click on the running workflow
- View real-time logs for each step

### In AWS Console

- Go to **ECS** > **Clusters** > **flask-auth-cluster**
- Click on your service
- View **Deployments** tab to see rollout status
- Check **Tasks** tab to see running containers

### Via AWS CLI

```bash
# Check service status
aws ecs describe-services \
  --cluster flask-auth-cluster \
  --services InfrastructureStack-EcsStackFlaskAuthServiceServiceF0712F02-CsEAm2A7Tm0G \
  --region us-east-2

# View recent task events
aws ecs describe-services \
  --cluster flask-auth-cluster \
  --services InfrastructureStack-EcsStackFlaskAuthServiceServiceF0712F02-CsEAm2A7Tm0G \
  --region us-east-2 \
  --query 'services[0].events[0:5]'
```

## Troubleshooting

### Issue: "No basic auth credentials" during ECR login

**Solution**: Verify the IAM role has ECR permissions and the trust policy is correctly configured.

### Issue: "AccessDenied" when updating ECS service

**Solution**: Ensure the IAM role has `ecs:UpdateService` permission and `iam:PassRole` for task execution and task roles.

### Issue: Workflow can't assume role

**Solution**:
1. Verify OIDC provider is created in IAM
2. Check trust policy has correct GitHub repository path
3. Ensure `AWS_ROLE_TO_ASSUME` secret is set correctly

### Issue: Wrong architecture error

**Solution**: The workflow builds for `linux/amd64`. Don't modify this as ECS Fargate requires AMD64.

### Issue: Service deployment timeout

**Solution**: Check:
1. Task definition has correct image URI
2. Container can start successfully (check CloudWatch logs)
3. Health check endpoint `/health` is responding
4. Security groups allow ALB to reach tasks

## Rolling Back

If a deployment fails, ECS automatically rolls back. To manually rollback:

```bash
# List task definitions
aws ecs list-task-definitions --family-prefix flask-auth --region us-east-2

# Update service to previous task definition
aws ecs update-service \
  --cluster flask-auth-cluster \
  --service <service-name> \
  --task-definition <previous-task-definition-arn> \
  --region us-east-2
```

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Configuring OpenID Connect in AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS ECS Deployment Action](https://github.com/aws-actions/amazon-ecs-deploy-task-definition)
- [AWS ECR Login Action](https://github.com/aws-actions/amazon-ecr-login)
