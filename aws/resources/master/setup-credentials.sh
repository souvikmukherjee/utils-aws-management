#!/bin/bash

# AWS Management Utilities - Credentials Setup Script
# This script helps you set up your credentials file securely

set -e

echo "AWS Management Utilities - Credentials Setup"
echo "============================================"
echo ""

# Check if credentials file already exists
if [ -f "credentials.env.local" ]; then
    echo "⚠️  credentials.env.local already exists!"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
fi

echo "📝 Setting up credentials file..."
echo ""

# Copy the template
cp credentials.env credentials.env.local

echo "✅ Created credentials.env.local"
echo ""
echo "🔧 Next steps:"
echo "1. Edit credentials.env.local with your actual values"
echo "2. Restart your development server: npm run dev"
echo ""
echo "🔒 Security notes:"
echo "- credentials.env.local is already in .gitignore"
echo "- Never commit this file to version control"
echo "- Use different credentials for production"
echo ""

# Check if the file was created successfully
if [ -f "credentials.env.local" ]; then
    echo "📋 Current credentials file contents:"
    echo "----------------------------------------"
    cat credentials.env.local
    echo "----------------------------------------"
    echo ""
    echo "🎉 Setup complete! Edit credentials.env.local with your actual values."
else
    echo "❌ Error: Failed to create credentials.env.local"
    exit 1
fi 