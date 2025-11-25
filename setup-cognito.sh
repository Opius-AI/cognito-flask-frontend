#!/bin/bash

# AWS Cognito Setup Script for Flask Authentication App
# This script creates a Cognito User Pool and App Client with all necessary configurations

set -e

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}AWS Cognito Setup for Flask Auth App${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    echo "Please install it from: https://aws.amazon.com/cli/"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    echo "Please run: aws configure"
    exit 1
fi

echo -e "${GREEN}✓ AWS CLI is installed and configured${NC}\n"

# Prompt for configuration
read -p "Enter AWS Region (default: us-east-1): " AWS_REGION
AWS_REGION=${AWS_REGION:-us-east-1}

read -p "Enter User Pool Name (default: flask-auth-pool): " POOL_NAME
POOL_NAME=${POOL_NAME:-flask-auth-pool}

read -p "Enter App Client Name (default: flask-auth-client): " CLIENT_NAME
CLIENT_NAME=${CLIENT_NAME:-flask-auth-client}

read -p "Generate Client Secret? (y/n, default: y): " GEN_SECRET
GEN_SECRET=${GEN_SECRET:-y}

echo -e "\n${BLUE}Creating Cognito User Pool...${NC}"

# Create User Pool
USER_POOL_ID=$(aws cognito-idp create-user-pool \
    --pool-name "$POOL_NAME" \
    --region "$AWS_REGION" \
    --policies "PasswordPolicy={MinimumLength=8,RequireUppercase=true,RequireLowercase=true,RequireNumbers=true,RequireSymbols=false}" \
    --auto-verified-attributes email \
    --username-attributes email \
    --username-configuration CaseSensitive=false \
    --mfa-configuration OFF \
    --account-recovery-setting "RecoveryMechanisms=[{Priority=1,Name=verified_email}]" \
    --schema \
        Name=email,AttributeDataType=String,Required=true,Mutable=true \
    --email-configuration EmailSendingAccount=COGNITO_DEFAULT \
    --user-pool-tags "Environment=Development,Application=FlaskAuthApp" \
    --query 'UserPool.Id' \
    --output text)

if [ -z "$USER_POOL_ID" ]; then
    echo -e "${RED}Failed to create User Pool${NC}"
    exit 1
fi

echo -e "${GREEN}✓ User Pool created: ${USER_POOL_ID}${NC}"

# Create App Client
echo -e "\n${BLUE}Creating App Client...${NC}"

if [ "$GEN_SECRET" = "y" ] || [ "$GEN_SECRET" = "Y" ]; then
    # Create with client secret
    APP_CLIENT_RESPONSE=$(aws cognito-idp create-user-pool-client \
        --user-pool-id "$USER_POOL_ID" \
        --client-name "$CLIENT_NAME" \
        --region "$AWS_REGION" \
        --generate-secret \
        --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
        --prevent-user-existence-errors ENABLED \
        --enable-token-revocation \
        --auth-session-validity 3 \
        --access-token-validity 60 \
        --id-token-validity 60 \
        --refresh-token-validity 30 \
        --token-validity-units "AccessToken=minutes,IdToken=minutes,RefreshToken=days" \
        --output json)

    CLIENT_ID=$(echo "$APP_CLIENT_RESPONSE" | jq -r '.UserPoolClient.ClientId')
    CLIENT_SECRET=$(echo "$APP_CLIENT_RESPONSE" | jq -r '.UserPoolClient.ClientSecret')
else
    # Create without client secret
    APP_CLIENT_RESPONSE=$(aws cognito-idp create-user-pool-client \
        --user-pool-id "$USER_POOL_ID" \
        --client-name "$CLIENT_NAME" \
        --region "$AWS_REGION" \
        --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
        --prevent-user-existence-errors ENABLED \
        --enable-token-revocation \
        --auth-session-validity 3 \
        --access-token-validity 60 \
        --id-token-validity 60 \
        --refresh-token-validity 30 \
        --token-validity-units "AccessToken=minutes,IdToken=minutes,RefreshToken=days" \
        --output json)

    CLIENT_ID=$(echo "$APP_CLIENT_RESPONSE" | jq -r '.UserPoolClient.ClientId')
    CLIENT_SECRET=""
fi

if [ -z "$CLIENT_ID" ]; then
    echo -e "${RED}Failed to create App Client${NC}"
    exit 1
fi

echo -e "${GREEN}✓ App Client created: ${CLIENT_ID}${NC}"

# Generate a random Flask secret key
FLASK_SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")

# Create .env file
echo -e "\n${BLUE}Creating .env file...${NC}"

cat > .env << EOF
# Flask Configuration
FLASK_SECRET_KEY=${FLASK_SECRET_KEY}
FLASK_DEBUG=False

# AWS Cognito Configuration
COGNITO_USER_POOL_ID=${USER_POOL_ID}
COGNITO_CLIENT_ID=${CLIENT_ID}
COGNITO_CLIENT_SECRET=${CLIENT_SECRET}
AWS_REGION=${AWS_REGION}

# AWS Credentials (if not using IAM role)
# AWS_ACCESS_KEY_ID=your-access-key
# AWS_SECRET_ACCESS_KEY=your-secret-key
EOF

echo -e "${GREEN}✓ .env file created${NC}"

# Create a test user (optional)
echo -e "\n${YELLOW}Would you like to create a test user? (y/n)${NC}"
read -p "Create test user: " CREATE_USER
CREATE_USER=${CREATE_USER:-n}

if [ "$CREATE_USER" = "y" ] || [ "$CREATE_USER" = "Y" ]; then
    read -p "Enter test user email: " TEST_EMAIL
    read -s -p "Enter test user password (min 8 chars): " TEST_PASSWORD
    echo

    echo -e "\n${BLUE}Creating test user...${NC}"

    aws cognito-idp admin-create-user \
        --user-pool-id "$USER_POOL_ID" \
        --username "$TEST_EMAIL" \
        --user-attributes Name=email,Value="$TEST_EMAIL" Name=email_verified,Value=true \
        --temporary-password "$TEST_PASSWORD" \
        --message-action SUPPRESS \
        --region "$AWS_REGION" > /dev/null

    # Set permanent password
    aws cognito-idp admin-set-user-password \
        --user-pool-id "$USER_POOL_ID" \
        --username "$TEST_EMAIL" \
        --password "$TEST_PASSWORD" \
        --permanent \
        --region "$AWS_REGION" > /dev/null

    echo -e "${GREEN}✓ Test user created: ${TEST_EMAIL}${NC}"
fi

# Summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${BLUE}Configuration Summary:${NC}"
echo -e "User Pool ID: ${YELLOW}${USER_POOL_ID}${NC}"
echo -e "App Client ID: ${YELLOW}${CLIENT_ID}${NC}"
if [ -n "$CLIENT_SECRET" ]; then
    echo -e "Client Secret: ${YELLOW}${CLIENT_SECRET}${NC}"
fi
echo -e "AWS Region: ${YELLOW}${AWS_REGION}${NC}"
echo -e "Flask Secret Key: ${YELLOW}${FLASK_SECRET_KEY}${NC}"

echo -e "\n${BLUE}Next Steps:${NC}"
echo -e "1. Review the generated .env file"
echo -e "2. Run the application with: ${YELLOW}docker-compose up --build${NC}"
echo -e "3. Access the app at: ${YELLOW}http://localhost:8000${NC}"

if [ "$CREATE_USER" = "y" ] || [ "$CREATE_USER" = "Y" ]; then
    echo -e "4. Login with email: ${YELLOW}${TEST_EMAIL}${NC}"
fi

echo -e "\n${BLUE}To delete these resources later:${NC}"
echo -e "${YELLOW}aws cognito-idp delete-user-pool --user-pool-id ${USER_POOL_ID} --region ${AWS_REGION}${NC}"

echo -e "\n${GREEN}Setup script saved credentials to .env file${NC}"
