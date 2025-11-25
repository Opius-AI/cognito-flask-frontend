# AWS Cognito Setup Guide

This guide will help you set up AWS Cognito for the Flask authentication application using AWS CLI commands.

## Prerequisites

1. **AWS CLI installed**: [Installation Guide](https://aws.amazon.com/cli/)
2. **AWS Account with appropriate permissions**:
   - `cognito-idp:*` permissions for Cognito operations
   - Or use `PowerUserAccess` or `AdministratorAccess` policies
3. **AWS CLI configured with credentials**:
   ```bash
   aws configure
   ```
4. **jq installed** (for JSON parsing):
   - macOS: `brew install jq`
   - Linux: `sudo apt-get install jq`
   - Windows: Download from [stedolan.github.io/jq](https://stedolan.github.io/jq/)

## Quick Setup (Automated)

The easiest way to set up Cognito is using the provided setup script:

```bash
./setup-cognito.sh
```

This script will:
1. ✅ Create a Cognito User Pool with secure password policies
2. ✅ Create an App Client with USER_PASSWORD_AUTH enabled
3. ✅ Generate a secure Flask secret key
4. ✅ Create and populate the `.env` file with all credentials
5. ✅ Optionally create a test user for immediate testing

**Follow the interactive prompts to configure your setup.**

## Manual Setup (Step-by-Step)

If you prefer to set up Cognito manually, follow these steps:

### Step 1: Create a User Pool

```bash
aws cognito-idp create-user-pool \
    --pool-name flask-auth-pool \
    --region us-east-1 \
    --policies "PasswordPolicy={MinimumLength=8,RequireUppercase=true,RequireLowercase=true,RequireNumbers=true,RequireSymbols=false}" \
    --auto-verified-attributes email \
    --username-attributes email \
    --username-configuration CaseSensitive=false \
    --mfa-configuration OFF \
    --account-recovery-setting "RecoveryMechanisms=[{Priority=1,Name=verified_email}]" \
    --schema Name=email,AttributeDataType=String,Required=true,Mutable=true \
    --email-configuration EmailSendingAccount=COGNITO_DEFAULT \
    --user-pool-tags "Environment=Development,Application=FlaskAuthApp"
```

**Save the `UserPool.Id` from the output.**

### Step 2: Create an App Client (with Client Secret)

```bash
aws cognito-idp create-user-pool-client \
    --user-pool-id <YOUR_USER_POOL_ID> \
    --client-name flask-auth-client \
    --region us-east-1 \
    --generate-secret \
    --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
    --prevent-user-existence-errors ENABLED \
    --enable-token-revocation \
    --auth-session-validity 3 \
    --access-token-validity 60 \
    --id-token-validity 60 \
    --refresh-token-validity 30 \
    --token-validity-units "AccessToken=minutes,IdToken=minutes,RefreshToken=days"
```

**Save the `ClientId` and `ClientSecret` from the output.**

### Step 3: Create an App Client (without Client Secret - Alternative)

If you don't want to use a client secret:

```bash
aws cognito-idp create-user-pool-client \
    --user-pool-id <YOUR_USER_POOL_ID> \
    --client-name flask-auth-client \
    --region us-east-1 \
    --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
    --prevent-user-existence-errors ENABLED \
    --enable-token-revocation \
    --auth-session-validity 3 \
    --access-token-validity 60 \
    --id-token-validity 60 \
    --refresh-token-validity 30 \
    --token-validity-units "AccessToken=minutes,IdToken=minutes,RefreshToken=days"
```

### Step 4: Create a Test User

```bash
# Create user
aws cognito-idp admin-create-user \
    --user-pool-id <YOUR_USER_POOL_ID> \
    --username user@example.com \
    --user-attributes Name=email,Value=user@example.com Name=email_verified,Value=true \
    --temporary-password TempPassword123! \
    --message-action SUPPRESS \
    --region us-east-1

# Set permanent password
aws cognito-idp admin-set-user-password \
    --user-pool-id <YOUR_USER_POOL_ID> \
    --username user@example.com \
    --password YourPassword123! \
    --permanent \
    --region us-east-1
```

### Step 5: Configure Environment Variables

Create a `.env` file in the project root:

```bash
# Flask Configuration
FLASK_SECRET_KEY=<generate-a-random-32-byte-hex-string>
FLASK_DEBUG=False

# AWS Cognito Configuration
COGNITO_USER_POOL_ID=<your-user-pool-id>
COGNITO_CLIENT_ID=<your-client-id>
COGNITO_CLIENT_SECRET=<your-client-secret-if-generated>
AWS_REGION=us-east-1

# AWS Credentials (if not using IAM role)
# AWS_ACCESS_KEY_ID=your-access-key
# AWS_SECRET_ACCESS_KEY=your-secret-key
```

**Generate a secure Flask secret key:**
```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
```

## Running the Application

Once Cognito is configured and the `.env` file is created:

### Using Docker Compose (Recommended)

```bash
docker-compose up --build
```

### Using Docker

```bash
docker build -t cognito-auth-app .
docker run -p 8000:8000 --env-file .env cognito-auth-app
```

### Running Locally

```bash
# Install dependencies
pip install -r requirements.txt

# Run the app
python app.py
```

Access the application at: **http://localhost:8000**

## User Management Commands

### List Users

```bash
aws cognito-idp list-users \
    --user-pool-id <YOUR_USER_POOL_ID> \
    --region us-east-1
```

### Get User Details

```bash
aws cognito-idp admin-get-user \
    --user-pool-id <YOUR_USER_POOL_ID> \
    --username user@example.com \
    --region us-east-1
```

### Delete User

```bash
aws cognito-idp admin-delete-user \
    --user-pool-id <YOUR_USER_POOL_ID> \
    --username user@example.com \
    --region us-east-1
```

### Enable User

```bash
aws cognito-idp admin-enable-user \
    --user-pool-id <YOUR_USER_POOL_ID> \
    --username user@example.com \
    --region us-east-1
```

### Disable User

```bash
aws cognito-idp admin-disable-user \
    --user-pool-id <YOUR_USER_POOL_ID> \
    --username user@example.com \
    --region us-east-1
```

### Reset User Password

```bash
aws cognito-idp admin-set-user-password \
    --user-pool-id <YOUR_USER_POOL_ID> \
    --username user@example.com \
    --password NewPassword123! \
    --permanent \
    --region us-east-1
```

## Cleanup

To delete all Cognito resources when you're done:

### Using the Cleanup Script

```bash
./cleanup-cognito.sh
```

### Manual Cleanup

```bash
# Delete User Pool (this also deletes all app clients and users)
aws cognito-idp delete-user-pool \
    --user-pool-id <YOUR_USER_POOL_ID> \
    --region us-east-1

# Remove .env file
rm .env
```

## Troubleshooting

### "InvalidParameterException: Cannot enable both USERNAME and EMAIL or PHONE_NUMBER as aliases"

This means email as username is already configured. This is the desired configuration for our app.

### "NotAuthorizedException: USER_PASSWORD_AUTH flow not enabled for this client"

Make sure you included `ALLOW_USER_PASSWORD_AUTH` in the `--explicit-auth-flows` parameter when creating the app client.

### "InvalidPasswordException: Password did not conform with policy"

The default password policy requires:
- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number

### "User does not exist"

Make sure the user has been created and confirmed. Check user status:
```bash
aws cognito-idp admin-get-user \
    --user-pool-id <YOUR_USER_POOL_ID> \
    --username user@example.com \
    --region us-east-1
```

### "ResourceNotFoundException: User pool does not exist"

Double-check your `COGNITO_USER_POOL_ID` in the `.env` file matches the actual pool ID.

## Security Best Practices

1. **Never commit `.env` file to version control** - It's already in `.gitignore`
2. **Use strong, unique passwords** for production
3. **Enable MFA** in production environments
4. **Use HTTPS** in production (not HTTP)
5. **Rotate secrets regularly**
6. **Monitor Cognito CloudWatch logs** for suspicious activity
7. **Use IAM roles** instead of access keys when running on AWS (EC2, ECS, Lambda)
8. **Implement rate limiting** to prevent brute force attacks

## Additional Resources

- [AWS Cognito Documentation](https://docs.aws.amazon.com/cognito/)
- [AWS CLI Cognito Reference](https://docs.aws.amazon.com/cli/latest/reference/cognito-idp/)
- [Flask Documentation](https://flask.palletsprojects.com/)
- [Boto3 Cognito Documentation](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/cognito-idp.html)
