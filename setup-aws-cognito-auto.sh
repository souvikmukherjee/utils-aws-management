#!/bin/bash

# AWS Management Utilities - Automated Cognito Setup Script
# This script automatically sets up AWS Cognito with recommended values

set -e

echo "AWS Management Utilities - Automated Cognito Setup Script"
echo "========================================================"
echo ""

# Configuration values (predefined to avoid issues)
PROJECT_NAME="aws-management-utilities"
USER_POOL_NAME="aws-management-utilities-users"
APP_CLIENT_NAME="aws-management-utilities-client"
DOMAIN_PREFIX="utils-management-$(date +%s)"
CALLBACK_URLS="http://localhost:3001/api/auth/callback/cognito,http://localhost:3002/api/auth/callback/cognito"
ALLOWED_ORIGINS="http://localhost:3001,http://localhost:3002"

echo "[INFO] Using predefined configuration:"
echo "  Project Name: $PROJECT_NAME"
echo "  User Pool Name: $USER_POOL_NAME"
echo "  App Client Name: $APP_CLIENT_NAME"
echo "  Domain Prefix: $DOMAIN_PREFIX"
echo "  Callback URLs: $CALLBACK_URLS"
echo "  Allowed Origins: $ALLOWED_ORIGINS"
echo ""

# Validate AWS CLI and jq
echo "[INFO] Validating prerequisites..."
if ! command -v aws &> /dev/null; then
    echo "[ERROR] AWS CLI is not installed. Please install it first."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "[ERROR] jq is not installed. Please install it first."
    exit 1
fi

# Validate AWS credentials
echo "[INFO] Validating AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "[ERROR] AWS credentials are not configured or invalid."
    echo "Please run 'aws configure' first."
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)
echo "[SUCCESS] AWS credentials validated"
echo "[INFO] Account ID: $ACCOUNT_ID"
echo "[INFO] Region: $REGION"
echo ""

# Create User Pool
echo "[INFO] Creating Cognito User Pool..."
USER_POOL_ID=$(aws cognito-idp create-user-pool \
    --pool-name "$USER_POOL_NAME" \
    --policies '{
        "PasswordPolicy": {
            "MinimumLength": 8,
            "RequireUppercase": true,
            "RequireLowercase": true,
            "RequireNumbers": true,
            "RequireSymbols": false
        }
    }' \
    --auto-verified-attributes email \
    --username-attributes email \
    --query 'UserPool.Id' \
    --output text)

echo "[SUCCESS] User Pool created with ID: $USER_POOL_ID"

# Create Cognito Domain
echo "[INFO] Creating Cognito Domain..."
aws cognito-idp create-user-pool-domain \
    --domain "$DOMAIN_PREFIX" \
    --user-pool-id "$USER_POOL_ID" > /dev/null

echo "[SUCCESS] Cognito Domain created: $DOMAIN_PREFIX.auth.$REGION.amazoncognito.com"

# Create App Client
echo "[INFO] Creating App Client..."
APP_CLIENT_ID=$(aws cognito-idp create-user-pool-client \
    --user-pool-id "$USER_POOL_ID" \
    --client-name "$APP_CLIENT_NAME" \
    --no-generate-secret \
    --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
    --supported-identity-providers COGNITO \
    --callback-urls "$CALLBACK_URLS" \
    --logout-urls "http://localhost:3001" "http://localhost:3002" \
    --allowed-o-auth-flows code \
    --allowed-o-auth-scopes email openid profile \
    --allowed-o-auth-flows-user-pool-client \
    --query 'UserPoolClient.ClientId' \
    --output text)

echo "[SUCCESS] App Client created with ID: $APP_CLIENT_ID"

# Create test user
echo "[INFO] Creating test user..."
aws cognito-idp admin-create-user \
    --user-pool-id "$USER_POOL_ID" \
    --username "test@example.com" \
    --user-attributes Name=email,Value="test@example.com" Name=email_verified,Value=true \
    --temporary-password "TempPass123!" \
    --message-action SUPPRESS > /dev/null

echo "[SUCCESS] Test user created: test@example.com (temporary password: TempPass123!)"

# Generate NextAuth secret
NEXTAUTH_SECRET=$(openssl rand -base64 32)

# Create .env.local file
echo "[INFO] Creating .env.local file..."
cat > .env.local << EOF
# NextAuth.js Configuration
NEXTAUTH_URL=http://localhost:3001
NEXTAUTH_SECRET=$NEXTAUTH_SECRET

# AWS Cognito Configuration
COGNITO_CLIENT_ID=$APP_CLIENT_ID
COGNITO_CLIENT_SECRET=
COGNITO_ISSUER=https://cognito-idp.$REGION.amazonaws.com/$USER_POOL_ID

# AWS Configuration
AWS_REGION=$REGION
EOF

echo "[SUCCESS] .env.local file created"

# Update NextAuth configuration
echo "[INFO] Updating NextAuth configuration..."
cat > src/app/api/auth/[...nextauth]/route.ts << 'EOF'
import NextAuth from "next-auth";
import CognitoProvider from "next-auth/providers/cognito";
import CredentialsProvider from "next-auth/providers/credentials";

const handler = NextAuth({
  providers: [
    CognitoProvider({
      clientId: process.env.COGNITO_CLIENT_ID!,
      clientSecret: process.env.COGNITO_CLIENT_SECRET!,
      issuer: process.env.COGNITO_ISSUER,
    }),
    CredentialsProvider({
      name: "Demo",
      credentials: {
        email: { label: "Email", type: "email" },
        password: { label: "Password", type: "password" }
      },
      async authorize(credentials) {
        if (credentials?.email === "demo@example.com" && credentials?.password === "demo123") {
          return {
            id: "1",
            name: "Demo User",
            email: "demo@example.com",
          };
        }
        return null;
      }
    })
  ],
  session: {
    strategy: "jwt",
  },
  pages: {
    signIn: "/auth/signin",
  },
  debug: process.env.NODE_ENV === "development",
});

export { handler as GET, handler as POST };
EOF

echo "[SUCCESS] NextAuth configuration updated"

# Create setup summary
echo "[INFO] Creating setup summary..."
cat > AWS_COGNITO_SETUP.md << EOF
# AWS Cognito Setup Summary

## Configuration Details

- **Project Name**: $PROJECT_NAME
- **User Pool Name**: $USER_POOL_NAME
- **User Pool ID**: $USER_POOL_ID
- **App Client Name**: $APP_CLIENT_NAME
- **App Client ID**: $APP_CLIENT_ID
- **Domain Prefix**: $DOMAIN_PREFIX
- **Cognito Domain**: $DOMAIN_PREFIX.auth.$REGION.amazoncognito.com
- **Region**: $REGION
- **Account ID**: $ACCOUNT_ID

## Test User

- **Email**: test@example.com
- **Temporary Password**: TempPass123!
- **Note**: User will be prompted to change password on first login

## Environment Variables

The following environment variables have been configured in \`.env.local\`:

\`\`\`
NEXTAUTH_URL=http://localhost:3001
NEXTAUTH_SECRET=$NEXTAUTH_SECRET
COGNITO_CLIENT_ID=$APP_CLIENT_ID
COGNITO_CLIENT_SECRET=
COGNITO_ISSUER=https://cognito-idp.$REGION.amazonaws.com/$USER_POOL_ID
AWS_REGION=$REGION
\`\`\`

## Next Steps

1. Restart your development server: \`npm run dev\`
2. Test authentication at: http://localhost:3001
3. Use the demo credentials or create a new user in AWS Cognito Console

## AWS Console Links

- **Cognito User Pool**: https://$REGION.console.aws.amazon.com/cognito/v2/home?region=$REGION#/pool/$USER_POOL_ID
- **IAM Console**: https://console.aws.amazon.com/iam/

## Security Notes

- The test user has a temporary password that must be changed on first login
- Consider enabling MFA for production use
- Review and adjust password policies as needed
- Monitor CloudTrail logs for security events
EOF

echo "[SUCCESS] Setup summary created: AWS_COGNITO_SETUP.md"

echo ""
echo "🎉 AWS Cognito Setup Complete!"
echo "=============================="
echo ""
echo "✅ User Pool created: $USER_POOL_ID"
echo "✅ App Client created: $APP_CLIENT_ID"
echo "✅ Domain created: $DOMAIN_PREFIX.auth.$REGION.amazoncognito.com"
echo "✅ Test user created: test@example.com"
echo "✅ Environment file created: .env.local"
echo "✅ NextAuth configuration updated"
echo "✅ Setup summary created: AWS_COGNITO_SETUP.md"
echo ""
echo "🚀 Next Steps:"
echo "1. Restart your development server: npm run dev"
echo "2. Test authentication at: http://localhost:3001"
echo "3. Use demo credentials or create new users in AWS Console"
echo ""
echo "📋 Test Credentials:"
echo "   Email: test@example.com"
echo "   Password: TempPass123! (temporary - change on first login)"
echo ""
echo "📖 Setup Details: See AWS_COGNITO_SETUP.md for complete information" 