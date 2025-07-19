#!/bin/bash

# Fix AWS Cognito Users
USER_POOL_ID="ap-southeast-2_r24gyJxHq"

echo "Fixing AWS Cognito Users"
echo "======================="

echo "Creating demo user with proper password..."
aws cognito-idp admin-create-user \
    --user-pool-id "$USER_POOL_ID" \
    --username "demo@example.com" \
    --user-attributes Name=email,Value="demo@example.com" Name=email_verified,Value=true \
    --temporary-password "your-temporary-password-here" \
    --message-action SUPPRESS

echo ""
echo "Setting demo user password permanently..."
aws cognito-idp admin-set-user-password \
    --user-pool-id "$USER_POOL_ID" \
    --username "demo@example.com" \
    --password "your-permanent-password-here" \
    --permanent

echo ""
echo "Users ready for authentication:"
echo "1. AWS Cognito: test@example.com / TempPass123! (temporary - change on first login)"
echo "2. Demo: demo@example.com / your-password-here"
echo ""
echo "Note: The demo user now has a permanent password that meets AWS requirements." 