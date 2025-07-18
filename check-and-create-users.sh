#!/bin/bash

# Check and Create AWS Cognito Users
USER_POOL_ID="ap-southeast-2_r24gyJxHq"

echo "Checking existing users in User Pool: $USER_POOL_ID"
echo "=================================================="

# Check if users exist
echo "Listing existing users..."
aws cognito-idp list-users --user-pool-id "$USER_POOL_ID" --output json

echo ""
echo "Creating test user if it doesn't exist..."
aws cognito-idp admin-create-user \
    --user-pool-id "$USER_POOL_ID" \
    --username "test@example.com" \
    --user-attributes Name=email,Value="test@example.com" Name=email_verified,Value=true \
    --temporary-password "TempPass123!" \
    --message-action SUPPRESS

echo ""
echo "Creating demo user for development..."
aws cognito-idp admin-create-user \
    --user-pool-id "$USER_POOL_ID" \
    --username "demo@example.com" \
    --user-attributes Name=email,Value="demo@example.com" Name=email_verified,Value=true \
    --temporary-password "demo123" \
    --message-action SUPPRESS

echo ""
echo "Users created successfully!"
echo "Test user: test@example.com (password: TempPass123!)"
echo "Demo user: demo@example.com (password: demo123)" 