#!/bin/bash

# Setup Verification Script
# Checks if AWS Cognito and application are properly configured

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Setup Verification Script${NC}"
echo -e "${BLUE}========================================${NC}\n"

ERRORS=0
WARNINGS=0

# Check if .env file exists
echo -e "${BLUE}Checking .env file...${NC}"
if [ -f .env ]; then
    echo -e "${GREEN}✓ .env file exists${NC}"
    source .env
else
    echo -e "${RED}✗ .env file not found${NC}"
    echo -e "${YELLOW}  Run ./setup-cognito.sh to create it${NC}"
    exit 1
fi

# Check required environment variables
echo -e "\n${BLUE}Checking environment variables...${NC}"

check_var() {
    local var_name=$1
    local var_value=${!var_name}

    if [ -z "$var_value" ]; then
        echo -e "${RED}✗ $var_name is not set${NC}"
        ((ERRORS++))
        return 1
    else
        echo -e "${GREEN}✓ $var_name is set${NC}"
        return 0
    fi
}

check_var "FLASK_SECRET_KEY"
check_var "COGNITO_USER_POOL_ID"
check_var "COGNITO_CLIENT_ID"
check_var "AWS_REGION"

if [ -z "$COGNITO_CLIENT_SECRET" ]; then
    echo -e "${YELLOW}⚠ COGNITO_CLIENT_SECRET is not set (optional)${NC}"
    ((WARNINGS++))
else
    echo -e "${GREEN}✓ COGNITO_CLIENT_SECRET is set${NC}"
fi

# Check AWS CLI
echo -e "\n${BLUE}Checking AWS CLI...${NC}"
if command -v aws &> /dev/null; then
    echo -e "${GREEN}✓ AWS CLI is installed${NC}"

    if aws sts get-caller-identity &> /dev/null; then
        echo -e "${GREEN}✓ AWS credentials are configured${NC}"
        AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
        echo -e "  Account: ${YELLOW}${AWS_ACCOUNT}${NC}"
    else
        echo -e "${RED}✗ AWS credentials not configured${NC}"
        ((ERRORS++))
    fi
else
    echo -e "${RED}✗ AWS CLI not installed${NC}"
    ((ERRORS++))
fi

# Check if User Pool exists
if [ -n "$COGNITO_USER_POOL_ID" ] && [ -n "$AWS_REGION" ]; then
    echo -e "\n${BLUE}Checking Cognito User Pool...${NC}"

    POOL_NAME=$(aws cognito-idp describe-user-pool \
        --user-pool-id "$COGNITO_USER_POOL_ID" \
        --region "$AWS_REGION" \
        --query 'UserPool.Name' \
        --output text 2>/dev/null || echo "")

    if [ -n "$POOL_NAME" ] && [ "$POOL_NAME" != "None" ]; then
        echo -e "${GREEN}✓ User Pool exists: ${POOL_NAME}${NC}"
        echo -e "  Pool ID: ${YELLOW}${COGNITO_USER_POOL_ID}${NC}"
    else
        echo -e "${RED}✗ User Pool not found or inaccessible${NC}"
        ((ERRORS++))
    fi
fi

# Check if App Client exists
if [ -n "$COGNITO_USER_POOL_ID" ] && [ -n "$COGNITO_CLIENT_ID" ] && [ -n "$AWS_REGION" ]; then
    echo -e "\n${BLUE}Checking App Client...${NC}"

    CLIENT_NAME=$(aws cognito-idp describe-user-pool-client \
        --user-pool-id "$COGNITO_USER_POOL_ID" \
        --client-id "$COGNITO_CLIENT_ID" \
        --region "$AWS_REGION" \
        --query 'UserPoolClient.ClientName' \
        --output text 2>/dev/null || echo "")

    if [ -n "$CLIENT_NAME" ] && [ "$CLIENT_NAME" != "None" ]; then
        echo -e "${GREEN}✓ App Client exists: ${CLIENT_NAME}${NC}"
        echo -e "  Client ID: ${YELLOW}${COGNITO_CLIENT_ID}${NC}"

        # Check if USER_PASSWORD_AUTH is enabled
        AUTH_FLOWS=$(aws cognito-idp describe-user-pool-client \
            --user-pool-id "$COGNITO_USER_POOL_ID" \
            --client-id "$COGNITO_CLIENT_ID" \
            --region "$AWS_REGION" \
            --query 'UserPoolClient.ExplicitAuthFlows' \
            --output json 2>/dev/null || echo "[]")

        if echo "$AUTH_FLOWS" | grep -q "ALLOW_USER_PASSWORD_AUTH"; then
            echo -e "${GREEN}✓ USER_PASSWORD_AUTH is enabled${NC}"
        else
            echo -e "${RED}✗ USER_PASSWORD_AUTH is not enabled${NC}"
            echo -e "${YELLOW}  This is required for the app to work${NC}"
            ((ERRORS++))
        fi
    else
        echo -e "${RED}✗ App Client not found or inaccessible${NC}"
        ((ERRORS++))
    fi
fi

# Check if users exist
if [ -n "$COGNITO_USER_POOL_ID" ] && [ -n "$AWS_REGION" ]; then
    echo -e "\n${BLUE}Checking users...${NC}"

    USER_COUNT=$(aws cognito-idp list-users \
        --user-pool-id "$COGNITO_USER_POOL_ID" \
        --region "$AWS_REGION" \
        --query 'Users | length(@)' \
        --output text 2>/dev/null || echo "0")

    if [ "$USER_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ Found ${USER_COUNT} user(s) in the pool${NC}"
    else
        echo -e "${YELLOW}⚠ No users found in the pool${NC}"
        echo -e "${YELLOW}  Create a test user with the setup script or AWS CLI${NC}"
        ((WARNINGS++))
    fi
fi

# Check Docker
echo -e "\n${BLUE}Checking Docker...${NC}"
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓ Docker is installed${NC}"

    if docker info &> /dev/null; then
        echo -e "${GREEN}✓ Docker daemon is running${NC}"
    else
        echo -e "${RED}✗ Docker daemon is not running${NC}"
        ((ERRORS++))
    fi
else
    echo -e "${YELLOW}⚠ Docker not installed${NC}"
    echo -e "  You can still run the app locally with: python app.py"
    ((WARNINGS++))
fi

# Check docker-compose
if command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}✓ docker-compose is installed${NC}"
else
    echo -e "${YELLOW}⚠ docker-compose not installed${NC}"
    echo -e "  You can still use: docker build and docker run"
    ((WARNINGS++))
fi

# Check Python
echo -e "\n${BLUE}Checking Python...${NC}"
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo -e "${GREEN}✓ Python is installed: ${PYTHON_VERSION}${NC}"
else
    echo -e "${YELLOW}⚠ Python3 not found${NC}"
    ((WARNINGS++))
fi

# Check required files
echo -e "\n${BLUE}Checking project files...${NC}"
FILES=("app.py" "requirements.txt" "Dockerfile" "docker-compose.yml" "templates/login.html" "templates/dashboard.html")

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ $file exists${NC}"
    else
        echo -e "${RED}✗ $file is missing${NC}"
        ((ERRORS++))
    fi
done

# Summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Verification Summary${NC}"
echo -e "${BLUE}========================================${NC}"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Your setup is ready.${NC}"
    echo -e "\n${BLUE}Next steps:${NC}"
    echo -e "1. Start the application: ${YELLOW}docker-compose up --build${NC}"
    echo -e "2. Open browser: ${YELLOW}http://localhost:8000${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Setup complete with ${WARNINGS} warning(s)${NC}"
    echo -e "\n${BLUE}You can proceed, but review the warnings above.${NC}"
    exit 0
else
    echo -e "${RED}✗ Found ${ERRORS} error(s) and ${WARNINGS} warning(s)${NC}"
    echo -e "\n${BLUE}Please fix the errors above before proceeding.${NC}"
    exit 1
fi
