# AWS Cognito Setup Guide

This guide will help you set up AWS Cognito authentication for your AWS Management Utilities application.

## Prerequisites

Before running the setup script, ensure you have:

1. **AWS CLI installed and configured**
   ```bash
   # Install AWS CLI (if not already installed)
   # macOS
   brew install awscli
   
   # Ubuntu/Debian
   sudo apt-get install awscli
   
   # Configure AWS credentials
   aws configure
   ```

2. **jq installed** (for JSON parsing)
   ```bash
   # macOS
   brew install jq
   
   # Ubuntu/Debian
   sudo apt-get install jq
   ```

3. **Valid AWS credentials** with permissions to create Cognito resources

## Quick Setup

### Step 1: Configure AWS Credentials

If you haven't configured AWS credentials yet:

```bash
aws configure
```

You'll be prompted for:
- **AWS Access Key ID**: Your AWS access key
- **AWS Secret Access Key**: Your AWS secret key
- **Default region name**: Your preferred AWS region (e.g., us-east-1)
- **Default output format**: json

### Step 2: Run the Setup Script

```bash
./setup-aws-cognito.sh
```

The script will:
1. **Validate your AWS credentials**
2. **Prompt for configuration** (with sensible defaults)
3. **Create AWS Cognito User Pool**
4. **Create Cognito Domain**
5. **Create App Client**
6. **Create a test user**
7. **Generate environment variables**
8. **Update NextAuth configuration**
9. **Create setup documentation**

### Step 3: Configuration Prompts

The script will ask for the following (all have sensible defaults):

- **Project name**: `aws-management-utilities`
- **User Pool name**: `aws-management-utilities-user-pool`
- **App Client name**: `aws-management-utilities-web-app`
- **Domain prefix**: `aws-management-utilities-auth`
- **Callback URL**: `http://localhost:3001/api/auth/callback/cognito`
- **Sign-out URL**: `http://localhost:3001/auth/signin`
- **Allowed origins**: `http://localhost:3001`

### Step 4: Start the Application

After the script completes:

```bash
npm run dev
```

Visit http://localhost:3001 and test the authentication!

## What the Script Creates

### AWS Resources

1. **Cognito User Pool**
   - Email-based authentication
   - Password policy (8+ chars, uppercase, lowercase, numbers)
   - Email verification required
   - Self-service sign-up enabled

2. **Cognito Domain**
   - Hosted UI for authentication
   - Custom domain prefix

3. **App Client**
   - OAuth 2.0 configuration
   - Authorization code flow
   - Secure client secret

4. **Test User**
   - Email: `test@example.com`
   - Password: `TestPassword123!`

### Local Files

1. **`.env.local`**
   - NextAuth configuration
   - AWS Cognito credentials
   - Generated secrets

2. **`AWS_COGNITO_SETUP.md`**
   - Complete setup summary
   - Resource details
   - Next steps

3. **Updated NextAuth config**
   - AWS Cognito provider enabled
   - Fallback demo provider for development

## Testing the Setup

### Option 1: Use the Test User
- **Email**: `test@example.com`
- **Password**: `TestPassword123!`

### Option 2: Create a New Account
1. Visit http://localhost:3001
2. Click "Sign in"
3. Choose "Sign up" option
4. Follow the email verification process

### Option 3: Use Demo Credentials
- **Email**: `demo@example.com`
- **Password**: `demo123`

## Production Considerations

### Environment Variables
Update `.env.local` for production:

```bash
NEXTAUTH_URL=https://yourdomain.com
NEXTAUTH_SECRET=your-production-secret
COGNITO_CLIENT_ID=your-client-id
COGNITO_CLIENT_SECRET=your-client-secret
COGNITO_ISSUER=https://cognito-idp.region.amazonaws.com/user-pool-id
```

### AWS Cognito Configuration
1. **Update callback URLs** in AWS Console
2. **Enable MFA** for enhanced security
3. **Review password policies**
4. **Configure custom domain** (optional)

### Security Best Practices
1. **Rotate secrets regularly**
2. **Use environment-specific configurations**
3. **Enable CloudTrail for audit logs**
4. **Implement proper IAM roles**
5. **Consider using AWS Secrets Manager**

## Troubleshooting

### Common Issues

1. **"AWS credentials not valid"**
   ```bash
   aws configure
   aws sts get-caller-identity
   ```

2. **"jq not found"**
   ```bash
   # macOS
   brew install jq
   
   # Ubuntu/Debian
   sudo apt-get install jq
   ```

3. **"Permission denied"**
   - Ensure your AWS user has Cognito permissions
   - Required permissions: `cognito-idp:*`

4. **"Domain already exists"**
   - Choose a different domain prefix
   - Or delete existing domain in AWS Console

### Manual Setup

If the script fails, you can manually create resources:

1. **AWS Console**: https://console.aws.amazon.com/cognito/
2. **Create User Pool**
3. **Create App Client**
4. **Configure Domain**
5. **Update environment variables**

## Support

If you encounter issues:

1. Check the `AWS_COGNITO_SETUP.md` file for details
2. Review AWS CloudTrail logs
3. Check NextAuth.js documentation
4. Verify environment variables

## Next Steps

After successful setup:

1. **Complete Task 2.5**: Add Multi-Factor Authentication (MFA) Support
2. **Move to Task 3**: Implement AWS Cost Explorer Integration
3. **Add more AWS services** as needed
4. **Deploy to production** with proper security measures 