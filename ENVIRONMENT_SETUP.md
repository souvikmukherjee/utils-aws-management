# Environment Setup Guide

This document explains how to configure environment variables for the AWS Management Utilities project.

## 🔐 **Credential Management**

### **Quick Setup (Recommended)**

1. **Run the setup script**:
   ```bash
   ./setup-credentials.sh
   ```

2. **Edit your credentials**:
   ```bash
   # Edit the generated credentials file
   nano credentials.env.local
   ```

3. **Restart the development server**:
   ```bash
   npm run dev
   ```

### **Manual Setup**

If you prefer to set up manually:

1. **Copy the template**:
   ```bash
   cp credentials.env credentials.env.local
   ```

2. **Edit credentials.env.local** with your actual values

3. **Restart the development server**

## 🔐 **Environment Variables**

### **Required for Production**

Your `credentials.env.local` file should contain:

```bash
# NextAuth.js Configuration
NEXTAUTH_URL=http://localhost:3001
NEXTAUTH_SECRET=your-nextauth-secret-key-here

# AWS Cognito Configuration
COGNITO_CLIENT_ID=your-cognito-client-id
COGNITO_CLIENT_SECRET=your-cognito-client-secret
COGNITO_ISSUER=https://cognito-idp.us-east-1.amazonaws.com/us-east-1_your-user-pool-id

# AWS Configuration
AWS_REGION=us-east-1

# Demo Authentication Credentials (for development only)
DEMO_USER_EMAIL=demo@example.com
DEMO_USER_PASSWORD=DemoPass123!
TEST_USER_EMAIL=test@example.com
TEST_USER_PASSWORD=TestPass123!
```

## 🔒 **Security Best Practices**

1. **Never commit `credentials.env.local` to version control** ✅ (Already in .gitignore)
2. **Use strong, unique secrets for NEXTAUTH_SECRET**
3. **Rotate AWS credentials regularly**
4. **Use IAM roles in production instead of access keys**
5. **Store production secrets in AWS Secrets Manager**
6. **Keep `credentials.env` as a template only**

## 🚀 **Getting Started**

1. **Run setup script**: `./setup-credentials.sh`
2. **Edit credentials**: Update `credentials.env.local` with your values
3. **Start development**: `npm run dev`

## 📝 **Environment Variable Reference**

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `NEXTAUTH_URL` | Your application URL | Yes | `http://localhost:3001` |
| `NEXTAUTH_SECRET` | Secret for JWT encryption | Yes | `your-secret-key-here` |
| `COGNITO_CLIENT_ID` | AWS Cognito App Client ID | Yes | `4dalr0pp7j5folc1g33khf6ai1` |
| `COGNITO_CLIENT_SECRET` | AWS Cognito App Client Secret | Yes | `your-client-secret` |
| `COGNITO_ISSUER` | AWS Cognito User Pool Issuer | Yes | `https://cognito-idp.us-east-1.amazonaws.com/us-east-1_your-user-pool-id` |
| `AWS_REGION` | AWS Region | Yes | `us-east-1` |
| `DEMO_USER_EMAIL` | Demo user email (dev only) | No | `demo@example.com` |
| `DEMO_USER_PASSWORD` | Demo user password (dev only) | No | `DemoPass123!` |
| `TEST_USER_EMAIL` | Test user email (dev only) | No | `test@example.com` |
| `TEST_USER_PASSWORD` | Test user password (dev only) | No | `TestPass123!` |

## 🔧 **AWS CLI Configuration**

For AWS services, configure your AWS CLI:

```bash
aws configure
```

This will store credentials in `~/.aws/credentials` and is the recommended approach for development.

## 📁 **File Structure**

```
project-root/
├── credentials.env          # Template file (committed to git)
├── credentials.env.local    # Your actual credentials (ignored by git)
├── setup-credentials.sh     # Setup script
└── .gitignore              # Protects sensitive files
```

## ⚠️ **Important Notes**

- `credentials.env` is a template and safe to commit
- `credentials.env.local` contains your actual credentials and is ignored
- Never edit `credentials.env` with real credentials
- Always use `credentials.env.local` for your actual values 