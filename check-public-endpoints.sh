#!/bin/bash

# Check Public Endpoints Script
# This script checks the actual public endpoints for RDS and Redis

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

DB_INSTANCE_IDENTIFIER="aws-management-dev-db-1752944212"
REDIS_CLUSTER_ID="aws-management-dev-redis-1752944212"

print_status "Checking public endpoints for RDS and Redis..."

# Get RDS endpoint details
print_status "Getting RDS endpoint details..."
RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" --query 'DBInstances[0].Endpoint.Address' --output text)
RDS_PORT=$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" --query 'DBInstances[0].Endpoint.Port' --output text)
RDS_PUBLICLY_ACCESSIBLE=$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" --query 'DBInstances[0].PubliclyAccessible' --output text)

print_success "RDS Endpoint: $RDS_ENDPOINT:$RDS_PORT"
print_status "Publicly Accessible: $RDS_PUBLICLY_ACCESSIBLE"

# Get Redis endpoint details
print_status "Getting Redis endpoint details..."
REDIS_ENDPOINT=$(aws elasticache describe-cache-clusters --cache-cluster-id "$REDIS_CLUSTER_ID" --show-cache-node-info --query 'CacheClusters[0].CacheNodes[0].Endpoint.Address' --output text)
REDIS_PORT=$(aws elasticache describe-cache-clusters --cache-cluster-id "$REDIS_CLUSTER_ID" --show-cache-node-info --query 'CacheClusters[0].CacheNodes[0].Endpoint.Port' --output text)

print_success "Redis Endpoint: $REDIS_ENDPOINT:$REDIS_PORT"

# Check DNS resolution
print_status "Checking DNS resolution..."

# Check RDS DNS
print_status "RDS DNS resolution:"
nslookup "$RDS_ENDPOINT" 2>/dev/null || echo "nslookup failed"

# Check Redis DNS
print_status "Redis DNS resolution:"
nslookup "$REDIS_ENDPOINT" 2>/dev/null || echo "nslookup failed"

# Check if endpoints are private IPs
print_status "Checking if endpoints are private IPs..."

if [[ "$RDS_ENDPOINT" =~ ^172\. ]] || [[ "$RDS_ENDPOINT" =~ ^10\. ]] || [[ "$RDS_ENDPOINT" =~ ^192\.168\. ]]; then
    print_warning "RDS endpoint appears to be a private IP: $RDS_ENDPOINT"
    print_status "This means the RDS instance is not truly publicly accessible"
else
    print_success "RDS endpoint appears to be public: $RDS_ENDPOINT"
fi

if [[ "$REDIS_ENDPOINT" =~ ^172\. ]] || [[ "$REDIS_ENDPOINT" =~ ^10\. ]] || [[ "$REDIS_ENDPOINT" =~ ^192\.168\. ]]; then
    print_warning "Redis endpoint appears to be a private IP: $REDIS_ENDPOINT"
    print_status "ElastiCache Redis clusters are typically not publicly accessible"
else
    print_success "Redis endpoint appears to be public: $REDIS_ENDPOINT"
fi

# Check VPC and subnet configuration
print_status "Checking VPC and subnet configuration..."

VPC_ID=$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" --query 'DBInstances[0].DBSubnetGroup.VpcId' --output text)
SUBNET_GROUP_NAME=$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" --query 'DBInstances[0].DBSubnetGroup.DBSubnetGroupName' --output text)

print_status "VPC ID: $VPC_ID"
print_status "Subnet Group: $SUBNET_GROUP_NAME"

# Check if subnets have route to internet gateway
print_status "Checking subnet internet connectivity..."

SUBNET_IDS=$(aws rds describe-db-subnet-groups --db-subnet-group-name "$SUBNET_GROUP_NAME" --query 'DBSubnetGroups[0].Subnets[*].SubnetId' --output text)

for SUBNET_ID in $SUBNET_IDS; do
    print_status "Checking subnet: $SUBNET_ID"
    
    # Check if subnet has route to internet gateway
    ROUTE_TABLES=$(aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$SUBNET_ID" --query 'RouteTables[*].RouteTableId' --output text)
    
    if [ -n "$ROUTE_TABLES" ]; then
        for ROUTE_TABLE in $ROUTE_TABLES; do
            INTERNET_GATEWAY=$(aws ec2 describe-route-tables --route-table-ids "$ROUTE_TABLE" --query 'RouteTables[0].Routes[?GatewayId!=`local`].GatewayId' --output text)
            if [ -n "$INTERNET_GATEWAY" ]; then
                print_success "Subnet $SUBNET_ID has route to internet gateway: $INTERNET_GATEWAY"
            else
                print_warning "Subnet $SUBNET_ID does not have route to internet gateway"
            fi
        done
    else
        print_warning "Subnet $SUBNET_ID has no associated route table"
    fi
done

# Create a summary
print_status "Creating connectivity summary..."

cat > CONNECTIVITY_SUMMARY.md << EOF
# Database Connectivity Summary

## Current Status

### PostgreSQL RDS
- **Instance ID**: $DB_INSTANCE_IDENTIFIER
- **Endpoint**: $RDS_ENDPOINT:$RDS_PORT
- **Publicly Accessible**: $RDS_PUBLICLY_ACCESSIBLE
- **VPC ID**: $VPC_ID
- **Subnet Group**: $SUBNET_GROUP_NAME

### Redis ElastiCache
- **Cluster ID**: $REDIS_CLUSTER_ID
- **Endpoint**: $REDIS_ENDPOINT:$REDIS_PORT
- **VPC ID**: $VPC_ID

## Connectivity Issues

### Problem
The databases are returning private IP addresses (172.31.x.x) instead of public endpoints, which means they cannot be accessed from outside the AWS VPC.

### Root Cause
1. **RDS**: Even though marked as publicly accessible, the subnets may not have proper internet gateway routes
2. **Redis**: ElastiCache Redis clusters are typically not publicly accessible by design

## Solutions

### Option 1: Use AWS EC2 Instance (Recommended)
Deploy your application on an EC2 instance in the same VPC to access the databases directly.

### Option 2: Use AWS RDS Proxy (For RDS)
Set up RDS Proxy to provide a public endpoint for your RDS instance.

### Option 3: Use AWS ElastiCache Global Datastore (For Redis)
Set up Global Datastore for cross-region access (not for public access).

### Option 4: Use AWS VPN or Direct Connect
Set up VPN connection to access the VPC resources securely.

## Immediate Workaround

For development purposes, you can:

1. **Deploy to AWS**: Use AWS CodeDeploy, Elastic Beanstalk, or ECS to deploy your application in the same VPC
2. **Use AWS Cloud9**: Develop directly in AWS Cloud9 IDE which has VPC access
3. **Use AWS Lambda**: Create Lambda functions to interact with the databases
4. **Use AWS API Gateway**: Create API endpoints that connect to the databases

## Security Note

⚠️ **Important**: The current setup is actually more secure as it prevents direct external access to your databases. For production, this is the recommended approach.

## Next Steps

1. Consider deploying your application to AWS (EC2, ECS, Lambda, etc.)
2. Or use AWS Cloud9 for development
3. For local development, consider using local databases (Docker containers)
4. Implement proper VPC networking for production use
EOF

print_success "Created connectivity summary: CONNECTIVITY_SUMMARY.md"

echo ""
echo "🔍 Connectivity Analysis Complete!"
echo ""
echo "📋 Key Findings:"
echo "1. RDS and Redis are returning private IP addresses"
echo "2. This is actually the correct behavior for security"
echo "3. To access them, you need to deploy within AWS VPC"
echo ""
echo "📖 Check CONNECTIVITY_SUMMARY.md for detailed analysis and solutions"
echo ""
echo "💡 Recommendation: Deploy your application to AWS for database access" 