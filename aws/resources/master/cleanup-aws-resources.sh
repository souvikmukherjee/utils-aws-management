#!/bin/bash

# Cleanup script for AWS resources
# WARNING: This will delete all created resources!
# Supports test mode with dynamic resource discovery

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

# Check if running in test mode
if [ "$INFRASTRUCTURE_TEST_MODE" = "true" ]; then
    RESOURCE_SUFFIX="${TEST_SUFFIX:-_test}"
    print_status "Running cleanup in TEST MODE with suffix: $RESOURCE_SUFFIX"
else
    RESOURCE_SUFFIX=""
    print_status "Running cleanup in PRODUCTION MODE"
fi

print_status "🧹 Cleaning up AWS resources..."

# Function to cleanup Redis clusters
cleanup_redis_clusters() {
    print_status "Cleaning up Redis clusters..."
    
    # Find Redis clusters with our naming pattern (convert underscore to hyphen for AWS resources)
    RESOURCE_PATTERN="${RESOURCE_SUFFIX//_/-}"
    REDIS_CLUSTERS=$(aws elasticache describe-cache-clusters --query "CacheClusters[?contains(CacheClusterId, 'aws-management-dev-redis') && contains(CacheClusterId, '$RESOURCE_PATTERN')].CacheClusterId" --output text)
    
    for cluster_id in $REDIS_CLUSTERS; do
        if [ ! -z "$cluster_id" ]; then
            print_status "Deleting Redis cluster: $cluster_id"
            aws elasticache delete-cache-cluster --cache-cluster-id "$cluster_id" --final-snapshot-identifier "${cluster_id}-final-snapshot" || true
        fi
    done
}

# Function to cleanup RDS instances
cleanup_rds_instances() {
    print_status "Cleaning up RDS instances..."
    
    # Find RDS instances with our naming pattern (convert underscore to hyphen for AWS resources)
    RESOURCE_PATTERN="${RESOURCE_SUFFIX//_/-}"
    RDS_INSTANCES=$(aws rds describe-db-instances --query "DBInstances[?contains(DBInstanceIdentifier, 'aws-management-dev-db') && contains(DBInstanceIdentifier, '$RESOURCE_PATTERN')].DBInstanceIdentifier" --output text)
    
    for instance_id in $RDS_INSTANCES; do
        if [ ! -z "$instance_id" ]; then
            print_status "Deleting RDS instance: $instance_id"
            aws rds delete-db-instance --db-instance-identifier "$instance_id" --skip-final-snapshot || true
        fi
    done
}

# Function to cleanup security groups
cleanup_security_groups() {
    print_status "Cleaning up security groups..."
    
    # Find security groups with our naming pattern
    SECURITY_GROUPS=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=aws-management-dev-sg*$RESOURCE_SUFFIX" --query 'SecurityGroups[*].GroupId' --output text)
    
    for sg_id in $SECURITY_GROUPS; do
        if [ ! -z "$sg_id" ]; then
            print_status "Deleting security group: $sg_id"
            aws ec2 delete-security-group --group-id "$sg_id" || true
        fi
    done
}

# Function to cleanup subnet groups
cleanup_subnet_groups() {
    print_status "Cleaning up subnet groups..."
    
    # Find DB subnet groups with our naming pattern (convert underscore to hyphen for AWS resources)
    RESOURCE_PATTERN="${RESOURCE_SUFFIX//_/-}"
    DB_SUBNET_GROUPS=$(aws rds describe-db-subnet-groups --query "DBSubnetGroups[?contains(DBSubnetGroupName, 'aws-management-dev-subnet-group') && contains(DBSubnetGroupName, '$RESOURCE_PATTERN')].DBSubnetGroupName" --output text)
    
    for subnet_group in $DB_SUBNET_GROUPS; do
        if [ ! -z "$subnet_group" ]; then
            print_status "Deleting DB subnet group: $subnet_group"
            aws rds delete-db-subnet-group --db-subnet-group-name "$subnet_group" || true
        fi
    done
    
    # Find Redis subnet groups with our naming pattern (convert underscore to hyphen for AWS resources)
    RESOURCE_PATTERN="${RESOURCE_SUFFIX//_/-}"
    REDIS_SUBNET_GROUPS=$(aws elasticache describe-cache-subnet-groups --query "CacheSubnetGroups[?contains(CacheSubnetGroupName, 'aws-management-dev-redis-subnet') && contains(CacheSubnetGroupName, '$RESOURCE_PATTERN')].CacheSubnetGroupName" --output text)
    
    for subnet_group in $REDIS_SUBNET_GROUPS; do
        if [ ! -z "$subnet_group" ]; then
            print_status "Deleting Redis subnet group: $subnet_group"
            aws elasticache delete-cache-subnet-group --cache-subnet-group-name "$subnet_group" || true
        fi
    done
}

# Function to cleanup EC2 instances (jump box)
cleanup_ec2_instances() {
    print_status "Cleaning up EC2 instances..."
    
    # Find EC2 instances with our naming pattern
    EC2_INSTANCES=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=aws-management-dev-jump-box*$RESOURCE_SUFFIX" "Name=instance-state-name,Values=running,stopped" --query 'Reservations[*].Instances[*].InstanceId' --output text)
    
    for instance_id in $EC2_INSTANCES; do
        if [ ! -z "$instance_id" ]; then
            print_status "Terminating EC2 instance: $instance_id"
            aws ec2 terminate-instances --instance-ids "$instance_id" || true
        fi
    done
}

# Function to cleanup Cognito resources
cleanup_cognito_resources() {
    print_status "Cleaning up Cognito resources..."
    
    # Find user pools with our naming pattern
    USER_POOLS=$(aws cognito-idp list-user-pools --max-results 20 --query "UserPools[?contains(Name, 'aws-management-dev') && contains(Name, '$RESOURCE_SUFFIX')].Id" --output text)
    
    for pool_id in $USER_POOLS; do
        if [ ! -z "$pool_id" ]; then
            print_status "Deleting Cognito user pool: $pool_id"
            aws cognito-idp delete-user-pool --user-pool-id "$pool_id" || true
        fi
    done
}

# Main cleanup execution
main() {
    print_status "Starting comprehensive cleanup..."
    
    # Run cleanup functions
    cleanup_redis_clusters
    cleanup_rds_instances
    cleanup_security_groups
    cleanup_subnet_groups
    cleanup_ec2_instances
    cleanup_cognito_resources
    
    print_success "✅ Cleanup completed!"
    print_warning "Note: Some resources may take a few minutes to be fully deleted."
}

# Run main function
main "$@"
