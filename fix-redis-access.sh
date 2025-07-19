#!/bin/bash

# Fix Redis Access Script
# This script adds the jump box security group to the Redis security group

set -e

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

# Configuration
REDIS_CLUSTER_ID="aws-management-dev-redis-1752944212"
JUMP_BOX_SECURITY_GROUP="sg-069637656d710b1b8"

print_status "Fixing Redis access for jump box..."

# Get Redis security group
print_status "Getting Redis security group..."
REDIS_SECURITY_GROUP=$(aws elasticache describe-cache-clusters --cache-cluster-id "$REDIS_CLUSTER_ID" --show-cache-node-info --query 'CacheClusters[0].SecurityGroups[0]' --output text | awk '{print $1}')

if [ -z "$REDIS_SECURITY_GROUP" ]; then
    print_error "Could not get Redis security group"
    exit 1
fi

print_success "Redis Security Group: $REDIS_SECURITY_GROUP"

# Add jump box security group to Redis security group
print_status "Adding jump box security group to Redis security group..."
aws ec2 authorize-security-group-ingress \
    --group-id "$REDIS_SECURITY_GROUP" \
    --protocol tcp \
    --port 6379 \
    --source-group "$JUMP_BOX_SECURITY_GROUP" \
    > /dev/null

print_success "Added jump box security group to Redis security group"

# Test Redis connection from jump box
print_status "Testing Redis connection from jump box..."
ssh -i aws-management-dev-key-1752945390.pem ec2-user@16.176.104.97 "cd /home/ec2-user/scripts && node test-databases.js"

print_success "Redis access fixed!" 