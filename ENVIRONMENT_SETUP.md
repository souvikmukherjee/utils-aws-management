# Environment Setup Guide

This document explains how to configure environment variables for the AWS Management Utilities project.

## 🔐 **Environment Variables**

### **Required for Production**

Create a `.env.local` file in the project root with the following variables:

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
```

### **Development Only (Optional)**

For development and testing, you can add demo credentials:

```bash
# Demo Authentication Credentials (for development only)
DEMO_USER_EMAIL=demo@example.com
DEMO_USER_PASSWORD=DemoPass123!
TEST_USER_EMAIL=test@example.com
TEST_USER_PASSWORD=TestPass123!
```

## 🔒 **Security Best Practices**

1. **Never commit `.env.local` to version control**
2. **Use strong, unique secrets for NEXTAUTH_SECRET**
3. **Rotate AWS credentials regularly**
4. **Use IAM roles in production instead of access keys**
5. **Store production secrets in AWS Secrets Manager**

## 🚀 **Getting Started**

1. Copy `env.example` to `.env.local`
2. Update the values with your actual credentials
3. Restart the development server: `npm run dev`

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