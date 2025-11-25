#!/bin/bash

# AWS Cognito Cleanup Script
# This script removes the Cognito User Pool and all associated resources

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}AWS Cognito Cleanup Script${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please provide the User Pool ID manually:"
    read -p "Enter User Pool ID: " USER_POOL_ID
    read -p "Enter AWS Region: " AWS_REGION
else
    # Load from .env
    source .env
    USER_POOL_ID=$COGNITO_USER_POOL_ID
    AWS_REGION=${AWS_REGION:-us-east-1}
fi

if [ -z "$USER_POOL_ID" ]; then
    echo -e "${RED}Error: User Pool ID not provided${NC}"
    exit 1
fi

echo -e "${YELLOW}WARNING: This will delete the following:${NC}"
echo -e "  - User Pool: ${USER_POOL_ID}"
echo -e "  - All associated App Clients"
echo -e "  - All users in the pool"
echo -e "\n${RED}This action cannot be undone!${NC}\n"

read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${BLUE}Cleanup cancelled${NC}"
    exit 0
fi

echo -e "\n${BLUE}Deleting User Pool...${NC}"

aws cognito-idp delete-user-pool \
    --user-pool-id "$USER_POOL_ID" \
    --region "$AWS_REGION"

echo -e "${GREEN}✓ User Pool deleted successfully${NC}"

# Optionally remove .env file
read -p "Remove .env file? (y/n): " REMOVE_ENV
if [ "$REMOVE_ENV" = "y" ] || [ "$REMOVE_ENV" = "Y" ]; then
    rm -f .env
    echo -e "${GREEN}✓ .env file removed${NC}"
fi

echo -e "\n${GREEN}Cleanup complete!${NC}"
