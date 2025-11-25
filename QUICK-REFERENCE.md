# Quick Reference - Common Commands

## Setup & Deployment

```bash
# Set up AWS Cognito (interactive)
./setup-cognito.sh

# Start the application
docker-compose up --build

# Access the app
open http://localhost:8000
```

## User Management

```bash
# List all users
aws cognito-idp list-users \
    --user-pool-id $COGNITO_USER_POOL_ID \
    --region $AWS_REGION

# Create a new user
aws cognito-idp admin-create-user \
    --user-pool-id $COGNITO_USER_POOL_ID \
    --username user@example.com \
    --user-attributes Name=email,Value=user@example.com Name=email_verified,Value=true \
    --temporary-password TempPass123! \
    --message-action SUPPRESS \
    --region $AWS_REGION

# Set permanent password
aws cognito-idp admin-set-user-password \
    --user-pool-id $COGNITO_USER_POOL_ID \
    --username user@example.com \
    --password Password123! \
    --permanent \
    --region $AWS_REGION

# Delete a user
aws cognito-idp admin-delete-user \
    --user-pool-id $COGNITO_USER_POOL_ID \
    --username user@example.com \
    --region $AWS_REGION

# Get user details
aws cognito-idp admin-get-user \
    --user-pool-id $COGNITO_USER_POOL_ID \
    --username user@example.com \
    --region $AWS_REGION
```

## Docker Commands

```bash
# Build and start
docker-compose up --build

# Start in background
docker-compose up -d

# Stop containers
docker-compose down

# View logs
docker-compose logs -f

# Rebuild from scratch
docker-compose down
docker-compose build --no-cache
docker-compose up
```

## Development

```bash
# Run locally without Docker
python app.py

# Install dependencies
pip install -r requirements.txt

# Check for syntax errors
python -m py_compile app.py
```

## Cleanup

```bash
# Delete Cognito resources (interactive)
./cleanup-cognito.sh

# Or manually delete user pool
aws cognito-idp delete-user-pool \
    --user-pool-id $COGNITO_USER_POOL_ID \
    --region $AWS_REGION
```

## Environment Variables Quick Check

```bash
# Source .env file
source .env

# Verify configuration
echo "User Pool: $COGNITO_USER_POOL_ID"
echo "Client ID: $COGNITO_CLIENT_ID"
echo "Region: $AWS_REGION"
```

## Testing Authentication

```bash
# Test login via AWS CLI
aws cognito-idp initiate-auth \
    --auth-flow USER_PASSWORD_AUTH \
    --client-id $COGNITO_CLIENT_ID \
    --auth-parameters USERNAME=user@example.com,PASSWORD=Password123! \
    --region $AWS_REGION
```

## Useful One-Liners

```bash
# Count users in pool
aws cognito-idp list-users \
    --user-pool-id $COGNITO_USER_POOL_ID \
    --region $AWS_REGION \
    --query 'Users | length(@)'

# Get all user emails
aws cognito-idp list-users \
    --user-pool-id $COGNITO_USER_POOL_ID \
    --region $AWS_REGION \
    --query 'Users[*].Attributes[?Name==`email`].Value' \
    --output text

# Check if user pool exists
aws cognito-idp describe-user-pool \
    --user-pool-id $COGNITO_USER_POOL_ID \
    --region $AWS_REGION \
    --query 'UserPool.Name' \
    --output text
```
