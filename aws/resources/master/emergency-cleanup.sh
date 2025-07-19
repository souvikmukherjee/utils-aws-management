#!/bin/bash

# Emergency Cleanup Script
# This script cleans up orphaned test resources even without a state file

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
CLEANUP_LOG=".emergency-cleanup-$(date +%Y%m%d-%H%M%S).log"

# Function to safely delete RDS instances
cleanup_rds_instances() {
    print_status "Cleaning up RDS instances with '_test' suffix..."
    
    local instances=$(aws rds describe-db-instances --query "DBInstances[?contains(DBInstanceIdentifier, '_test') && DBInstanceStatus != 'deleting'].DBInstanceIdentifier" --output text 2>/dev/null || echo "")
    
    if [ -n "$instances" ]; then
        for instance in $instances; do
            print_status "Deleting RDS instance: $instance"
            echo "$(date): Deleting RDS instance: $instance" >> "$CLEANUP_LOG"
            
            aws rds delete-db-instance \
                --db-instance-identifier "$instance" \
                --skip-final-snapshot \
                --delete-automated-backups 2>/dev/null || true
        done
        print_success "RDS cleanup initiated"
    else
        print_status "No RDS instances with '_test' suffix found"
    fi
}

# Function to safely delete Redis clusters
cleanup_redis_clusters() {
    print_status "Cleaning up Redis clusters with '_test' suffix..."
    
    local clusters=$(aws elasticache describe-cache-clusters --query "CacheClusters[?contains(CacheClusterId, '_test') && CacheClusterStatus != 'deleting'].CacheClusterId" --output text 2>/dev/null || echo "")
    
    if [ -n "$clusters" ]; then
        for cluster in $clusters; do
            print_status "Deleting Redis cluster: $cluster"
            echo "$(date): Deleting Redis cluster: $cluster" >> "$CLEANUP_LOG"
            
            aws elasticache delete-cache-cluster --cache-cluster-id "$cluster" 2>/dev/null || true
        done
        print_success "Redis cleanup initiated"
    else
        print_status "No Redis clusters with '_test' suffix found"
    fi
}

# Function to safely delete EC2 instances
cleanup_ec2_instances() {
    print_status "Cleaning up EC2 instances with '_test' suffix..."
    
    local instances=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=*test*" "Name=instance-state-name,Values=running,stopped,pending" \
        --query 'Reservations[*].Instances[*].InstanceId' --output text 2>/dev/null || echo "")
    
    if [ -n "$instances" ]; then
        for instance in $instances; do
            print_status "Terminating EC2 instance: $instance"
            echo "$(date): Terminating EC2 instance: $instance" >> "$CLEANUP_LOG"
            
            aws ec2 terminate-instances --instance-ids "$instance" 2>/dev/null || true
        done
        print_success "EC2 cleanup initiated"
    else
        print_status "No EC2 instances with '_test' suffix found"
    fi
}

# Function to safely delete security groups
cleanup_security_groups() {
    print_status "Cleaning up security groups with '_test' suffix..."
    
    local security_groups=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=*test*" \
        --query 'SecurityGroups[*].GroupId' --output text 2>/dev/null || echo "")
    
    if [ -n "$security_groups" ]; then
        for sg in $security_groups; do
            print_status "Deleting security group: $sg"
            echo "$(date): Deleting security group: $sg" >> "$CLEANUP_LOG"
            
            aws ec2 delete-security-group --group-id "$sg" 2>/dev/null || true
        done
        print_success "Security group cleanup initiated"
    else
        print_status "No security groups with '_test' suffix found"
    fi
}

# Function to safely delete key pairs
cleanup_key_pairs() {
    print_status "Cleaning up key pairs with '_test' suffix..."
    
    local key_pairs=$(aws ec2 describe-key-pairs \
        --query "KeyPairs[?contains(KeyName, '_test')].KeyName" --output text 2>/dev/null || echo "")
    
    if [ -n "$key_pairs" ]; then
        for key in $key_pairs; do
            print_status "Deleting key pair: $key"
            echo "$(date): Deleting key pair: $key" >> "$CLEANUP_LOG"
            
            aws ec2 delete-key-pair --key-name "$key" 2>/dev/null || true
            
            # Also remove local key files
            if [ -f "${key}.pem" ]; then
                rm -f "${key}.pem"
                print_status "Removed local key file: ${key}.pem"
            fi
        done
        print_success "Key pair cleanup completed"
    else
        print_status "No key pairs with '_test' suffix found"
    fi
}

# Function to safely delete subnet groups
cleanup_subnet_groups() {
    print_status "Cleaning up subnet groups with '_test' suffix..."
    
    # RDS subnet groups
    local db_subnet_groups=$(aws rds describe-db-subnet-groups \
        --query "DBSubnetGroups[?contains(DBSubnetGroupName, '_test')].DBSubnetGroupName" --output text 2>/dev/null || echo "")
    
    if [ -n "$db_subnet_groups" ]; then
        for subnet in $db_subnet_groups; do
            print_status "Deleting RDS subnet group: $subnet"
            echo "$(date): Deleting RDS subnet group: $subnet" >> "$CLEANUP_LOG"
            
            aws rds delete-db-subnet-group --db-subnet-group-name "$subnet" 2>/dev/null || true
        done
    fi
    
    # Redis subnet groups
    local redis_subnet_groups=$(aws elasticache describe-cache-subnet-groups \
        --query "CacheSubnetGroups[?contains(CacheSubnetGroupName, '_test')].CacheSubnetGroupName" --output text 2>/dev/null || echo "")
    
    if [ -n "$redis_subnet_groups" ]; then
        for subnet in $redis_subnet_groups; do
            print_status "Deleting Redis subnet group: $subnet"
            echo "$(date): Deleting Redis subnet group: $subnet" >> "$CLEANUP_LOG"
            
            aws elasticache delete-cache-subnet-group --cache-subnet-group-name "$subnet" 2>/dev/null || true
        done
    fi
    
    print_success "Subnet group cleanup completed"
}

# Function to safely delete Cognito resources
cleanup_cognito_resources() {
    print_status "Cleaning up Cognito resources with '_test' suffix..."
    
    local user_pools=$(aws cognito-idp list-user-pools --max-results 60 \
        --query "UserPools[?contains(Name, '_test')].Id" --output text 2>/dev/null || echo "")
    
    if [ -n "$user_pools" ]; then
        for pool in $user_pools; do
            print_status "Deleting Cognito user pool: $pool"
            echo "$(date): Deleting Cognito user pool: $pool" >> "$CLEANUP_LOG"
            
            aws cognito-idp delete-user-pool --user-pool-id "$pool" 2>/dev/null || true
        done
        print_success "Cognito cleanup completed"
    else
        print_status "No Cognito user pools with '_test' suffix found"
    fi
}

# Function to show current test resources
show_current_resources() {
    print_status "Current test resources in AWS:"
    echo ""
    
    # RDS instances
    local rds_instances=$(aws rds describe-db-instances --query "DBInstances[?contains(DBInstanceIdentifier, '_test')].{ID:DBInstanceIdentifier,Status:DBInstanceStatus}" --output table 2>/dev/null || echo "No RDS instances found")
    echo "RDS Instances:"
    echo "$rds_instances"
    echo ""
    
    # Redis clusters
    local redis_clusters=$(aws elasticache describe-cache-clusters --query "CacheClusters[?contains(CacheClusterId, '_test')].{ID:CacheClusterId,Status:CacheClusterStatus}" --output table 2>/dev/null || echo "No Redis clusters found")
    echo "Redis Clusters:"
    echo "$redis_clusters"
    echo ""
    
    # EC2 instances
    local ec2_instances=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=*test*" --query 'Reservations[*].Instances[*].{ID:InstanceId,Name:Tags[?Key==`Name`].Value|[0],State:State.Name}' --output table 2>/dev/null || echo "No EC2 instances found")
    echo "EC2 Instances:"
    echo "$ec2_instances"
    echo ""
}

# Main cleanup function
main_cleanup() {
    print_status "🚨 Starting emergency cleanup of test resources..."
    echo "$(date): Emergency cleanup started" >> "$CLEANUP_LOG"
    
    # Show current resources before cleanup
    show_current_resources
    
    # Ask for confirmation
    echo ""
    print_warning "This will delete ALL resources with '_test' suffix!"
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_status "Cleanup cancelled"
        exit 0
    fi
    
    # Perform cleanup in dependency order
    cleanup_ec2_instances
    cleanup_rds_instances
    cleanup_redis_clusters
    cleanup_subnet_groups
    cleanup_security_groups
    cleanup_key_pairs
    cleanup_cognito_resources
    
    # Wait a moment for deletions to process
    print_status "Waiting for deletions to process..."
    sleep 10
    
    # Show remaining resources
    echo ""
    print_status "Remaining test resources:"
    show_current_resources
    
    echo "$(date): Emergency cleanup completed" >> "$CLEANUP_LOG"
    print_success "Emergency cleanup completed! Check $CLEANUP_LOG for details."
}

# Check if running in dry-run mode
if [ "$1" = "--dry-run" ]; then
    print_status "🔍 Dry run mode - showing current test resources only"
    show_current_resources
    exit 0
fi

# Check prerequisites
print_status "Checking prerequisites..."

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials are not configured"
    exit 1
fi

print_success "Prerequisites check passed"

# Run main cleanup
main_cleanup 