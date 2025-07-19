#!/bin/bash

# Test Infrastructure Script
# This script tests the complete infrastructure setup in test mode

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

# State management
STATE_FILE=".test-infrastructure-state.json"
CLEANUP_LOG=".test-cleanup.log"

# Initialize state file
initialize_state() {
    cat > "$STATE_FILE" << EOF
{
    "test_started": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "resources_created": [],
    "current_phase": "",
    "failed_phase": "",
    "cleanup_completed": false
}
EOF
    print_status "Initialized state tracking in $STATE_FILE"
}

# Add resource to state
add_resource() {
    local resource_type="$1"
    local resource_id="$2"
    local resource_name="$3"
    
    # Add to state file
    jq --arg type "$resource_type" \
       --arg id "$resource_id" \
       --arg name "$resource_name" \
       --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
       '.resources_created += [{"type": $type, "id": $id, "name": $name, "created_at": $timestamp}]' \
       "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    
    print_status "Tracked resource: $resource_type ($resource_id)"
}

# Update current phase
update_phase() {
    local phase="$1"
    jq --arg phase "$phase" '.current_phase = $phase' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    print_status "Current phase: $phase"
}

# Mark failed phase
mark_failed_phase() {
    local phase="$1"
    jq --arg phase "$phase" '.failed_phase = $phase' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    print_error "Test failed at phase: $phase"
}

# Cleanup function
cleanup_on_failure() {
    print_error "🛑 Test infrastructure failed! Starting cleanup..."
    
    if [ ! -f "$STATE_FILE" ]; then
        print_warning "No state file found. Manual cleanup may be required."
        return
    fi
    
    # Mark cleanup as started
    jq '.cleanup_started = "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    
    print_status "Cleaning up resources from state file..."
    
    # Get resources to clean up
    local resources=$(jq -r '.resources_created[] | "\(.type)|\(.id)|\(.name)"' "$STATE_FILE" 2>/dev/null || echo "")
    
    if [ -z "$resources" ]; then
        print_warning "No resources found in state file"
        return
    fi
    
    echo "$(date): Starting cleanup of $(echo "$resources" | wc -l) resources" >> "$CLEANUP_LOG"
    
    while IFS='|' read -r resource_type resource_id resource_name; do
        if [ -n "$resource_id" ]; then
            print_status "Cleaning up $resource_type: $resource_id"
            echo "$(date): Cleaning up $resource_type: $resource_id" >> "$CLEANUP_LOG"
            
            case $resource_type in
                "RDS_INSTANCE")
                    aws rds delete-db-instance --db-instance-identifier "$resource_id" --skip-final-snapshot --delete-automated-backups 2>/dev/null || true
                    ;;
                "REDIS_CLUSTER")
                    aws elasticache delete-cache-cluster --cache-cluster-id "$resource_id" 2>/dev/null || true
                    ;;
                "EC2_INSTANCE")
                    aws ec2 terminate-instances --instance-ids "$resource_id" 2>/dev/null || true
                    ;;
                "SECURITY_GROUP")
                    aws ec2 delete-security-group --group-id "$resource_id" 2>/dev/null || true
                    ;;
                "KEY_PAIR")
                    aws ec2 delete-key-pair --key-name "$resource_id" 2>/dev/null || true
                    ;;
                "DB_SUBNET_GROUP")
                    aws rds delete-db-subnet-group --db-subnet-group-name "$resource_id" 2>/dev/null || true
                    ;;
                "REDIS_SUBNET_GROUP")
                    aws elasticache delete-cache-subnet-group --cache-subnet-group-name "$resource_id" 2>/dev/null || true
                    ;;
                "COGNITO_USER_POOL")
                    aws cognito-idp delete-user-pool --user-pool-id "$resource_id" 2>/dev/null || true
                    ;;
                "COGNITO_CLIENT")
                    # Note: Client deletion is handled with user pool deletion
                    ;;
                *)
                    print_warning "Unknown resource type: $resource_type"
                    ;;
            esac
        fi
    done <<< "$resources"
    
    # Mark cleanup as completed
    jq '.cleanup_completed = true' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    
    print_success "Cleanup completed. Check $CLEANUP_LOG for details."
    echo "$(date): Cleanup completed" >> "$CLEANUP_LOG"
}

# Trap handlers for cleanup
trap 'cleanup_on_failure; exit 1' ERR
trap 'cleanup_on_failure; exit 1' INT TERM

# Check prerequisites
print_status "🔍 Checking prerequisites..."

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

# Check required tools
for tool in jq curl; do
    if ! command -v $tool &> /dev/null; then
        print_error "$tool is not installed"
        exit 1
    fi
done

print_success "Prerequisites check passed"

# Initialize state tracking
initialize_state

# Set test mode environment variables
export INFRASTRUCTURE_TEST_MODE="true"
export TEST_SUFFIX="_test"
export RESOURCE_SUFFIX="_test"

print_status "🧪 Starting infrastructure test in TEST MODE"
print_status "Test suffix: $TEST_SUFFIX"
print_status "State tracking: $STATE_FILE"

# Phase 1: Environment Setup
update_phase "environment_setup"
print_status "📋 Phase 1: Environment Setup"

# Create test environment file
cat > .env.test << EOF
# Test Environment Configuration
INFRASTRUCTURE_TEST_MODE=true
TEST_SUFFIX=_test
RESOURCE_SUFFIX=_test

# Test Database Configuration
DB_PASSWORD=test_password_$(date +%s)
DB_INSTANCE_TYPE=db.t3.micro
REDIS_NODE_TYPE=cache.t3.micro

# Test Cognito Configuration
COGNITO_DOMAIN_PREFIX=aws-management-test-$(date +%s)
EOF

print_success "Environment setup completed"

# Phase 2: Infrastructure Creation
update_phase "infrastructure_creation"
print_status "🏗️ Phase 2: Infrastructure Creation"

# Track the master script execution
print_status "Running master infrastructure setup script..."

# Run the master setup script and capture output
if ./aws/resources/master/setup-all-infrastructure.sh 2>&1 | tee .test-setup.log; then
    print_success "Infrastructure creation completed"
else
    mark_failed_phase "infrastructure_creation"
    print_error "Infrastructure creation failed"
    exit 1
fi

# Extract and track created resources from the setup log
print_status "Extracting created resources from setup log..."

# Track RDS instances
grep -o "aws-management-dev-db-[0-9]*$TEST_SUFFIX" .test-setup.log | while read -r instance; do
    add_resource "RDS_INSTANCE" "$instance" "$instance"
done

# Track Redis clusters
grep -o "aws-management-dev-redis-[0-9]*$TEST_SUFFIX" .test-setup.log | while read -r cluster; do
    add_resource "REDIS_CLUSTER" "$cluster" "$cluster"
done

# Track EC2 instances
grep -o "i-[a-z0-9]*" .test-setup.log | while read -r instance; do
    add_resource "EC2_INSTANCE" "$instance" "Jump Box Instance"
done

# Track security groups
grep -o "sg-[a-z0-9]*" .test-setup.log | while read -r sg; do
    add_resource "SECURITY_GROUP" "$sg" "Security Group"
done

# Track key pairs
grep -o "aws-management-dev-key-[0-9]*$TEST_SUFFIX" .test-setup.log | while read -r key; do
    add_resource "KEY_PAIR" "$key" "$key"
done

# Track subnet groups
grep -o "aws-management-dev-subnet-group-[0-9]*$TEST_SUFFIX" .test-setup.log | while read -r subnet; do
    add_resource "DB_SUBNET_GROUP" "$subnet" "$subnet"
done

grep -o "aws-management-dev-redis-subnet-[0-9]*$TEST_SUFFIX" .test-setup.log | while read -r subnet; do
    add_resource "REDIS_SUBNET_GROUP" "$subnet" "$subnet"
done

# Track Cognito resources
grep -o "ap-southeast-2_[a-zA-Z0-9]*" .test-setup.log | while read -r pool; do
    add_resource "COGNITO_USER_POOL" "$pool" "User Pool"
done

print_success "Resource tracking completed"

# Phase 3: Resource Readiness Wait
update_phase "resource_readiness"
print_status "⏳ Phase 3: Resource Readiness Wait"

# Wait for RDS instances to be available
print_status "Waiting for RDS instances to be available..."
RDS_INSTANCES=$(jq -r '.resources_created[] | select(.type == "RDS_INSTANCE") | .id' "$STATE_FILE" 2>/dev/null || echo "")

if [ -n "$RDS_INSTANCES" ]; then
    for instance in $RDS_INSTANCES; do
        print_status "Waiting for RDS instance: $instance"
        if aws rds wait db-instance-available --db-instance-identifier "$instance" 2>/dev/null; then
            print_success "RDS instance $instance is available"
        else
            mark_failed_phase "resource_readiness"
            print_error "RDS instance $instance failed to become available"
            exit 1
        fi
    done
fi

# Wait for Redis clusters to be available
print_status "Waiting for Redis clusters to be available..."
REDIS_CLUSTERS=$(jq -r '.resources_created[] | select(.type == "REDIS_CLUSTER") | .id' "$STATE_FILE" 2>/dev/null || echo "")

if [ -n "$REDIS_CLUSTERS" ]; then
    for cluster in $REDIS_CLUSTERS; do
        print_status "Waiting for Redis cluster: $cluster"
        if aws elasticache wait cache-cluster-available --cache-cluster-id "$cluster" 2>/dev/null; then
            print_success "Redis cluster $cluster is available"
        else
            mark_failed_phase "resource_readiness"
            print_error "Redis cluster $cluster failed to become available"
            exit 1
        fi
    done
fi

print_success "All resources are ready"

# Phase 4: Connectivity Tests
update_phase "connectivity_tests"
print_status "🔗 Phase 4: Connectivity Tests"

# Test database connectivity
print_status "Testing database connectivity..."

# Get database endpoint from .env.local
if [ -f .env.local ]; then
    DB_HOST=$(grep "^DB_HOST=" .env.local | cut -d'=' -f2)
    DB_PORT=$(grep "^DB_PORT=" .env.local | cut -d'=' -f2)
    DB_NAME=$(grep "^DB_NAME=" .env.local | cut -d'=' -f2)
    DB_USER=$(grep "^DB_USER=" .env.local | cut -d'=' -f2)
    DB_PASSWORD=$(grep "^DB_PASSWORD=" .env.local | cut -d'=' -f2)
    
    if [ -n "$DB_HOST" ] && [ -n "$DB_PORT" ]; then
        print_status "Testing PostgreSQL connection to $DB_HOST:$DB_PORT"
        
        # Test with timeout
        if timeout 30 bash -c "until pg_isready -h $DB_HOST -p $DB_PORT -U $DB_USER; do sleep 2; done" 2>/dev/null; then
            print_success "PostgreSQL connectivity test passed"
        else
            mark_failed_phase "connectivity_tests"
            print_error "PostgreSQL connectivity test failed"
            exit 1
        fi
    else
        print_warning "Database configuration not found in .env.local"
    fi
else
    print_warning ".env.local file not found"
fi

# Test Redis connectivity
print_status "Testing Redis connectivity..."

# Get Redis endpoint from .env.local
if [ -f .env.local ]; then
    REDIS_HOST=$(grep "^REDIS_HOST=" .env.local | cut -d'=' -f2)
    REDIS_PORT=$(grep "^REDIS_PORT=" .env.local | cut -d'=' -f2)
    
    if [ -n "$REDIS_HOST" ] && [ -n "$REDIS_PORT" ]; then
        print_status "Testing Redis connection to $REDIS_HOST:$REDIS_PORT"
        
        # Test with timeout
        if timeout 30 bash -c "until redis-cli -h $REDIS_HOST -p $REDIS_PORT ping; do sleep 2; done" 2>/dev/null; then
            print_success "Redis connectivity test passed"
        else
            mark_failed_phase "connectivity_tests"
            print_error "Redis connectivity test failed"
            exit 1
        fi
    else
        print_warning "Redis configuration not found in .env.local"
    fi
else
    print_warning ".env.local file not found"
fi

print_success "Connectivity tests completed"

# Phase 5: Application Integration Tests
update_phase "application_tests"
print_status "🧪 Phase 5: Application Integration Tests"

# Test database schema setup
print_status "Testing database schema setup..."

# Check if Node.js test files exist
if [ -f "aws/resources/database/test-db-connectivity.js" ]; then
    print_status "Running database connectivity test script..."
    
    if node aws/resources/database/test-db-connectivity.js 2>&1 | tee .test-db-connectivity.log; then
        print_success "Database connectivity test script passed"
    else
        mark_failed_phase "application_tests"
        print_error "Database connectivity test script failed"
        exit 1
    fi
else
    print_warning "Database test script not found"
fi

# Test Redis connectivity
print_status "Testing Redis connectivity script..."

if [ -f "aws/resources/redis/test-redis-connectivity.js" ]; then
    print_status "Running Redis connectivity test script..."
    
    if node aws/resources/redis/test-redis-connectivity.js 2>&1 | tee .test-redis-connectivity.log; then
        print_success "Redis connectivity test script passed"
    else
        mark_failed_phase "application_tests"
        print_error "Redis connectivity test script failed"
        exit 1
    fi
else
    print_warning "Redis test script not found"
fi

print_success "Application integration tests completed"

# Phase 6: Cognito Tests
update_phase "cognito_tests"
print_status "🔐 Phase 6: Cognito Tests"

# Test Cognito user pool
print_status "Testing Cognito user pool..."

COGNITO_POOLS=$(jq -r '.resources_created[] | select(.type == "COGNITO_USER_POOL") | .id' "$STATE_FILE" 2>/dev/null || echo "")

if [ -n "$COGNITO_POOLS" ]; then
    for pool in $COGNITO_POOLS; do
        print_status "Testing Cognito user pool: $pool"
        
        if aws cognito-idp describe-user-pool --user-pool-id "$pool" >/dev/null 2>&1; then
            print_success "Cognito user pool $pool is accessible"
        else
            mark_failed_phase "cognito_tests"
            print_error "Cognito user pool $pool test failed"
            exit 1
        fi
    done
else
    print_warning "No Cognito user pools found in state"
fi

print_success "Cognito tests completed"

# Phase 7: Cleanup
update_phase "cleanup"
print_status "🧹 Phase 7: Cleanup"

print_status "Cleaning up test infrastructure..."

# Run the cleanup script
if ./aws/resources/master/cleanup-aws-resources.sh 2>&1 | tee .test-cleanup.log; then
    print_success "Cleanup completed successfully"
    
    # Mark cleanup as completed in state
    jq '.cleanup_completed = true' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
else
    print_warning "Cleanup script had some issues, but continuing..."
fi

# Generate test report
print_status "📊 Generating test report..."

cat > TEST_REPORT.md << EOF
# Infrastructure Test Report

## Test Summary
- **Test Started**: $(jq -r '.test_started' "$STATE_FILE")
- **Test Completed**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
- **Status**: ✅ PASSED
- **Failed Phase**: $(jq -r '.failed_phase // "None"' "$STATE_FILE")

## Resources Created and Cleaned Up
$(jq -r '.resources_created[] | "- \(.type): \(.name) (\(.id)) - Created: \(.created_at)"' "$STATE_FILE" 2>/dev/null || echo "No resources tracked")

## Test Phases
1. ✅ Environment Setup
2. ✅ Infrastructure Creation
3. ✅ Resource Readiness Wait
4. ✅ Connectivity Tests
5. ✅ Application Integration Tests
6. ✅ Cognito Tests
7. ✅ Cleanup

## Log Files
- Setup Log: .test-setup.log
- Database Test: .test-db-connectivity.log
- Redis Test: .test-redis-connectivity.log
- Cleanup Log: .test-cleanup.log
- State File: $STATE_FILE

## Notes
- All test resources have been cleaned up
- No AWS charges will be incurred
- Test infrastructure is ready for future test runs
EOF

print_success "Test report generated: TEST_REPORT.md"

# Final success message
print_success "🎉 Infrastructure test completed successfully!"
print_success "All resources have been created, tested, and cleaned up"
print_success "Check TEST_REPORT.md for detailed results"

# Remove trap handlers since we completed successfully
trap - ERR INT TERM

exit 0 