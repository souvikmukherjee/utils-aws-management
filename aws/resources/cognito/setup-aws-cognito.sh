#!/bin/bash

# AWS Management Utilities - Cognito Setup Script
# This script sets up AWS Cognito User Pool and related resources

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to generate random string
generate_random_string() {
    openssl rand -hex 8
}

# Function to validate AWS credentials
validate_aws_credentials() {
    print_status "Validating AWS credentials..."
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS credentials are not valid or not configured"
        print_status "Please run 'aws configure' first or set up your credentials"
        exit 1
    fi
    
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
    AWS_REGION=$(aws configure get region)
    
    if [ -z "$AWS_REGION" ]; then
        print_warning "AWS region not configured, defaulting to us-east-1"
        AWS_REGION="us-east-1"
        aws configure set region us-east-1
    fi
    
    print_success "AWS credentials validated"
    print_status "Account ID: $AWS_ACCOUNT_ID"
    print_status "Region: $AWS_REGION"
}

# Function to get user input
get_user_input() {
    echo
    print_status "AWS Cognito Setup Configuration"
    echo "====================================="
    
    # Check if running in test mode
    if [ "$INFRASTRUCTURE_TEST_MODE" = "true" ]; then
        RESOURCE_SUFFIX="${TEST_SUFFIX:-_test}"
        print_status "Running Cognito setup in TEST MODE with suffix: $RESOURCE_SUFFIX"
        # Use default values for test mode
        PROJECT_NAME="aws-management-utilities"
        USER_POOL_NAME="${PROJECT_NAME}-user-pool${RESOURCE_SUFFIX}"
        APP_CLIENT_NAME="${PROJECT_NAME}-web-app${RESOURCE_SUFFIX}"
        DOMAIN_PREFIX="${PROJECT_NAME}-auth${RESOURCE_SUFFIX}"
        CALLBACK_URL="http://localhost:3001/api/auth/callback/cognito"
        SIGNOUT_URL="http://localhost:3001/auth/signin"
        ALLOWED_ORIGINS="http://localhost:3001"
        print_success "Using test configuration"
    else
        RESOURCE_SUFFIX=""
        # Get project name
        read -p "Enter project name (default: aws-management-utilities): " PROJECT_NAME
        PROJECT_NAME=${PROJECT_NAME:-aws-management-utilities}
    
        # Get user pool name
        read -p "Enter Cognito User Pool name (default: ${PROJECT_NAME}-user-pool): " USER_POOL_NAME
        USER_POOL_NAME=${USER_POOL_NAME:-${PROJECT_NAME}-user-pool}
        
        # Get app client name
        read -p "Enter App Client name (default: ${PROJECT_NAME}-web-app): " APP_CLIENT_NAME
        APP_CLIENT_NAME=${APP_CLIENT_NAME:-${PROJECT_NAME}-web-app}
        
        # Get domain name
        read -p "Enter Cognito domain prefix (default: ${PROJECT_NAME}-auth): " DOMAIN_PREFIX
        DOMAIN_PREFIX=${DOMAIN_PREFIX:-${PROJECT_NAME}-auth}
        
        # Get callback URL
        read -p "Enter callback URL (default: http://localhost:3001/api/auth/callback/cognito): " CALLBACK_URL
        CALLBACK_URL=${CALLBACK_URL:-http://localhost:3001/api/auth/callback/cognito}
        
        # Get sign-out URL
        read -p "Enter sign-out URL (default: http://localhost:3001/auth/signin): " SIGNOUT_URL
        SIGNOUT_URL=${SIGNOUT_URL:-http://localhost:3001/auth/signin}
        
        # Get allowed origins
        read -p "Enter allowed origins (default: http://localhost:3001): " ALLOWED_ORIGINS
        ALLOWED_ORIGINS=${ALLOWED_ORIGINS:-http://localhost:3001}
    fi
    
    echo
    print_status "Configuration Summary:"
    echo "Project Name: $PROJECT_NAME"
    echo "User Pool Name: $USER_POOL_NAME"
    echo "App Client Name: $APP_CLIENT_NAME"
    echo "Domain Prefix: $DOMAIN_PREFIX"
    echo "Callback URL: $CALLBACK_URL"
    echo "Sign-out URL: $SIGNOUT_URL"
    echo "Allowed Origins: $ALLOWED_ORIGINS"
    echo
    
    # Skip confirmation in test mode
    if [ "$INFRASTRUCTURE_TEST_MODE" != "true" ]; then
        read -p "Proceed with this configuration? (y/N): " CONFIRM
        if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
            print_status "Setup cancelled"
            exit 0
        fi
    fi
}

# Function to create Cognito User Pool
create_user_pool() {
    print_status "Creating Cognito User Pool..."
    
    # Create user pool
    USER_POOL_RESPONSE=$(aws cognito-idp create-user-pool \
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
        --schema '[
            {
                "Name": "email",
                "AttributeDataType": "String",
                "Required": true,
                "Mutable": true
            },
            {
                "Name": "name",
                "AttributeDataType": "String",
                "Required": false,
                "Mutable": true
            }
        ]' \
        --account-recovery-setting '{
            "RecoveryMechanisms": [
                {
                    "Name": "verified_email",
                    "Priority": 1
                }
            ]
        }' \
        --mfa-configuration OFF \
        --email-configuration '{
            "EmailSendingAccount": "COGNITO_DEFAULT"
        }' \
        --admin-create-user-config '{
            "AllowAdminCreateUserOnly": false
        }' \
        --verification-message-template '{
            "DefaultEmailOption": "CONFIRM_WITH_CODE"
        }' \
        --output json)
    
    USER_POOL_ID=$(echo "$USER_POOL_RESPONSE" | jq -r '.UserPool.Id')
    USER_POOL_ARN=$(echo "$USER_POOL_RESPONSE" | jq -r '.UserPool.Arn')
    
    print_success "User Pool created successfully"
    print_status "User Pool ID: $USER_POOL_ID"
    print_status "User Pool ARN: $USER_POOL_ARN"
}

# Function to create Cognito Domain
create_cognito_domain() {
    print_status "Creating Cognito Domain..."
    
    aws cognito-idp create-user-pool-domain \
        --domain "$DOMAIN_PREFIX" \
        --user-pool-id "$USER_POOL_ID" \
        --output json >/dev/null
    
    COGNITO_DOMAIN="$DOMAIN_PREFIX.auth.$AWS_REGION.amazoncognito.com"
    
    print_success "Cognito Domain created successfully"
    print_status "Domain: $COGNITO_DOMAIN"
}

# Function to create App Client
create_app_client() {
    print_status "Creating App Client..."
    
    # Generate client secret
    CLIENT_SECRET=$(generate_random_string)
    
    APP_CLIENT_RESPONSE=$(aws cognito-idp create-user-pool-client \
        --user-pool-id "$USER_POOL_ID" \
        --client-name "$APP_CLIENT_NAME" \
        --generate-secret \
        --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH ALLOW_USER_SRP_AUTH \
        --supported-identity-providers COGNITO \
        --callback-urls "$CALLBACK_URL" \
        --logout-urls "$SIGNOUT_URL" \
        --allowed-o-auth-flows code \
        --allowed-o-auth-scopes email openid profile \
        --allowed-o-auth-flows-user-pool-client \
        --output json)
    
    CLIENT_ID=$(echo "$APP_CLIENT_RESPONSE" | jq -r '.UserPoolClient.ClientId')
    CLIENT_SECRET=$(echo "$APP_CLIENT_RESPONSE" | jq -r '.UserPoolClient.ClientSecret')
    
    print_success "App Client created successfully"
    print_status "Client ID: $CLIENT_ID"
    print_status "Client Secret: $CLIENT_SECRET"
}

# Function to create test user
create_test_user() {
    print_status "Creating test user..."
    
    TEST_EMAIL="test@example.com"
    TEST_PASSWORD="TestPassword123!"
    
    aws cognito-idp admin-create-user \
        --user-pool-id "$USER_POOL_ID" \
        --username "$TEST_EMAIL" \
        --user-attributes Name=email,Value="$TEST_EMAIL" Name=email_verified,Value=true Name=name,Value="Test User" \
        --temporary-password "$TEST_PASSWORD" \
        --message-action SUPPRESS \
        --output json >/dev/null
    
    print_success "Test user created successfully"
    print_status "Email: $TEST_EMAIL"
    print_status "Temporary Password: $TEST_PASSWORD"
}

# Function to create environment file
create_env_file() {
    print_status "Creating environment file..."
    
    # Generate NextAuth secret
    NEXTAUTH_SECRET=$(openssl rand -base64 32)
    
    cat > .env.local << EOF
# NextAuth.js Configuration
NEXTAUTH_URL=http://localhost:3001
NEXTAUTH_SECRET=$NEXTAUTH_SECRET

# AWS Cognito Configuration
COGNITO_CLIENT_ID=$CLIENT_ID
COGNITO_CLIENT_SECRET=$CLIENT_SECRET
COGNITO_ISSUER=https://cognito-idp.$AWS_REGION.amazonaws.com/$USER_POOL_ID

# AWS Configuration (for other AWS services)
AWS_REGION=$AWS_REGION
AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
EOF
    
    print_success "Environment file created: .env.local"
}

# Function to update NextAuth configuration
update_nextauth_config() {
    print_status "Updating NextAuth configuration..."
    
    # Create backup of current config
    cp src/app/api/auth/[...nextauth]/route.ts src/app/api/auth/[...nextauth]/route.ts.backup
    
    # Update the NextAuth config to use Cognito
    cat > src/app/api/auth/[...nextauth]/route.ts << 'EOF'
import NextAuth from "next-auth";
import CognitoProvider from "next-auth/providers/cognito";
import CredentialsProvider from "next-auth/providers/credentials";

const handler = NextAuth({
  providers: [
    // AWS Cognito provider
    CognitoProvider({
      clientId: process.env.COGNITO_CLIENT_ID!,
      clientSecret: process.env.COGNITO_CLIENT_SECRET!,
      issuer: process.env.COGNITO_ISSUER!,
    }),
    // Fallback credentials provider for development
    CredentialsProvider({
      id: "credentials",
      name: "Demo Login",
      credentials: {
        email: { label: "Email", type: "email" },
        password: { label: "Password", type: "password" }
      },
      async authorize(credentials) {
        // Mock authentication for demo purposes
        if (credentials?.email === "demo@example.com" && credentials?.password === "demo123") {
          return {
            id: "demo-user-123",
            email: "demo@example.com",
            name: "Demo User",
          };
        }
        return null;
      }
    }),
  ],
  session: {
    strategy: "jwt",
    maxAge: 30 * 24 * 60 * 60, // 30 days
  },
  callbacks: {
    async jwt({ token, user, account }) {
      // Persist the OAuth access_token and or the user id to the token right after signin
      if (account && user) {
        token.accessToken = account.access_token;
        token.refreshToken = account.refresh_token;
        token.idToken = account.id_token;
      }
      return token;
    },
    async session({ session, token }) {
      // Send properties to the client, like an access_token and user id from a provider.
      session.accessToken = token.accessToken;
      session.user.id = token.sub!;
      return session;
    },
  },
  pages: {
    signIn: "/auth/signin",
    signOut: "/auth/signout",
    error: "/auth/error",
  },
  debug: process.env.NODE_ENV === "development",
});

export { handler as GET, handler as POST };
EOF
    
    print_success "NextAuth configuration updated"
}

# Function to create setup summary
create_summary() {
    print_status "Creating setup summary..."
    
    cat > AWS_COGNITO_SETUP.md << EOF
# AWS Cognito Setup Summary

## Created Resources

### User Pool
- **Name**: $USER_POOL_NAME
- **ID**: $USER_POOL_ID
- **ARN**: $USER_POOL_ARN

### App Client
- **Name**: $APP_CLIENT_NAME
- **Client ID**: $CLIENT_ID
- **Client Secret**: $CLIENT_SECRET

### Domain
- **Domain**: $COGNITO_DOMAIN
- **Hosted UI URL**: https://$COGNITO_DOMAIN

### Test User
- **Email**: test@example.com
- **Temporary Password**: TestPassword123!

## Environment Variables

The following environment variables have been configured in \`.env.local\`:

\`\`\`bash
NEXTAUTH_URL=http://localhost:3001
NEXTAUTH_SECRET=$NEXTAUTH_SECRET
COGNITO_CLIENT_ID=$CLIENT_ID
COGNITO_CLIENT_SECRET=$CLIENT_SECRET
COGNITO_ISSUER=https://cognito-idp.$AWS_REGION.amazonaws.com/$USER_POOL_ID
AWS_REGION=$AWS_REGION
\`\`\`

## Next Steps

1. **Start the development server**:
   \`\`\`bash
   npm run dev
   \`\`\`

2. **Test the authentication**:
   - Visit http://localhost:3001
   - Use the test user credentials or create a new account

3. **For production**:
   - Update the callback URLs in AWS Cognito
   - Change the NEXTAUTH_URL to your production domain
   - Generate a new NEXTAUTH_SECRET

## AWS Console Links

- **Cognito User Pools**: https://console.aws.amazon.com/cognito/users/
- **Your User Pool**: https://console.aws.amazon.com/cognito/users/?region=$AWS_REGION#/pool/$USER_POOL_ID/users

## Security Notes

- Keep your Client Secret secure
- Rotate the NEXTAUTH_SECRET in production
- Consider enabling MFA for production use
- Review and adjust password policies as needed
EOF
    
    print_success "Setup summary created: AWS_COGNITO_SETUP.md"
}

# Function to display final instructions
display_final_instructions() {
    echo
    print_success "AWS Cognito setup completed successfully!"
    echo
    print_status "Next steps:"
    echo "1. Start your development server: npm run dev"
    echo "2. Visit http://localhost:3001"
    echo "3. Test authentication with the created test user"
    echo
    print_status "Test User Credentials:"
    echo "Email: test@example.com"
    echo "Password: TestPassword123!"
    echo
    print_status "Important files created:"
    echo "- .env.local (environment variables)"
    echo "- AWS_COGNITO_SETUP.md (setup summary)"
    echo "- src/app/api/auth/[...nextauth]/route.ts (updated NextAuth config)"
    echo
    print_warning "Remember to change the test user password on first login!"
}

# Main execution
main() {
    echo "AWS Management Utilities - Cognito Setup Script"
    echo "=============================================="
    echo
    
    # Check prerequisites
    if ! command_exists aws; then
        print_error "AWS CLI is not installed. Please install it first."
        print_status "Visit: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
    
    if ! command_exists jq; then
        print_error "jq is not installed. Please install it first."
        print_status "macOS: brew install jq"
        print_status "Ubuntu/Debian: sudo apt-get install jq"
        exit 1
    fi
    
    # Validate AWS credentials
    validate_aws_credentials
    
    # Get user input
    get_user_input
    
    # Create resources
    create_user_pool
    create_cognito_domain
    create_app_client
    create_test_user
    
    # Update application configuration
    create_env_file
    update_nextauth_config
    create_summary
    
    # Display final instructions
    display_final_instructions
}

# Run main function
main "$@" 