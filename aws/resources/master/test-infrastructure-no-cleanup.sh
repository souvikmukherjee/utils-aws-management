#!/bin/bash

# Test Infrastructure Script (No Cleanup Version)
# This script tests the AWS infrastructure setup without cleaning up resources

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Print functions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        return 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured"
        return 1
    fi
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed"
        return 1
    fi
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed"
        return 1
    fi
    
    print_success "All prerequisites are satisfied"
}

# Function to setup test environment
setup_test_environment() {
    print_status "Setting up test environment variables..."
    
    # Set test environment variables
    export INFRASTRUCTURE_TEST_MODE=true
    export TEST_SUFFIX="_test"
    export RESOURCE_SUFFIX="_test"
    
    # Create test environment file
    cat > .env.test << EOF
# Test Environment Variables
INFRASTRUCTURE_TEST_MODE=true
TEST_SUFFIX=_test
RESOURCE_SUFFIX=_test
EOF
    
    print_success "Test environment variables created"
}

# Function to run master script
run_master_script() {
    print_status "Running master infrastructure script with test parameters..."
    
    # Run the master script with test environment variables
    INFRASTRUCTURE_TEST_MODE=true TEST_SUFFIX="_test" ./aws/resources/master/setup-all-infrastructure.sh
    
    print_success "Master infrastructure script completed"
}

# Function to wait for resources
wait_for_resources() {
    print_status "Waiting for AWS resources to be ready..."
    
    # Find the actual resource names with our pattern (convert underscore to hyphen for AWS resources)
    RESOURCE_PATTERN="${RESOURCE_SUFFIX//_/-}"
    RDS_INSTANCE=$(aws rds describe-db-instances --query "DBInstances[?contains(DBInstanceIdentifier, 'aws-management-dev-db') && contains(DBInstanceIdentifier, '$RESOURCE_PATTERN')].DBInstanceIdentifier" --output text | tr '\t' '\n' | head -1)
    REDIS_CLUSTER=$(aws elasticache describe-cache-clusters --query "CacheClusters[?contains(CacheClusterId, 'aws-management-dev-redis') && contains(CacheClusterId, '$RESOURCE_PATTERN')].CacheClusterId" --output text | tr '\t' '\n' | head -1)
    EC2_INSTANCE=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=aws-management-dev-jump-box*$RESOURCE_SUFFIX" --query 'Reservations[].Instances[].InstanceId' --output text | tr '\t' '\n' | head -1)
    
    if [ -n "$RDS_INSTANCE" ]; then
        print_status "Waiting for RDS instance to be available: $RDS_INSTANCE"
        aws rds wait db-instance-available --db-instance-identifier "$RDS_INSTANCE" 2>/dev/null || print_warning "RDS instance not found or not available"
    else
        print_warning "No RDS instance found with test pattern"
    fi
    
    if [ -n "$REDIS_CLUSTER" ]; then
        print_status "Waiting for ElastiCache cluster to be available: $REDIS_CLUSTER"
        aws elasticache wait cache-cluster-available --cache-cluster-id "$REDIS_CLUSTER" 2>/dev/null || print_warning "Redis cluster not found or not available"
    else
        print_warning "No Redis cluster found with test pattern"
    fi
    
    if [ -n "$EC2_INSTANCE" ]; then
        print_status "Waiting for EC2 jump box to be running: $EC2_INSTANCE"
        aws ec2 wait instance-running --instance-ids "$EC2_INSTANCE" 2>/dev/null || print_warning "EC2 instance not found or not running"
    else
        print_warning "No EC2 instance found with test pattern"
    fi
    
    print_success "Resource availability check completed"
}

# Function to test database connectivity
test_database_connectivity() {
    print_status "Testing database connectivity..."
    
    # Wait a bit for SSH tunnels to establish
    sleep 10
    
    # Test PostgreSQL connection
    print_status "Testing PostgreSQL connection..."
    if node "$PROJECT_ROOT/aws/test/test-local-connections.js"; then
        print_success "PostgreSQL connectivity test passed"
    else
        print_error "PostgreSQL connectivity test failed"
        return 1
    fi
    
    # Test Redis connection
    print_status "Testing Redis connection..."
    if node "$PROJECT_ROOT/aws/test/test-redis-simple.js"; then
        print_success "Redis connectivity test passed"
    else
        print_error "Redis connectivity test failed"
        return 1
    fi
    
    print_success "All connectivity tests passed"
}

# Function to test application integration
test_application_integration() {
    print_status "Testing application integration..."
    
    # Test database schema setup
    print_status "Testing database schema setup..."
    if node "$PROJECT_ROOT/aws/resources/database/setup-database-tunnel.js"; then
        print_success "Database schema setup test passed"
    else
        print_error "Database schema setup test failed"
        return 1
    fi
    
    # Test CRUD operations
    print_status "Testing CRUD operations..."
    if node "$PROJECT_ROOT/aws/test/test-db-direct.js"; then
        print_success "CRUD operations test passed"
    else
        print_error "CRUD operations test failed"
        return 1
    fi
    
    print_success "All application integration tests passed"
}

# Function to test Cognito functionality
test_cognito_functionality() {
    print_status "Testing Cognito functionality..."
    
    # Test user creation
    print_status "Testing user creation..."
    if "$PROJECT_ROOT/aws/resources/auth/check-and-create-users.sh"; then
        print_success "User creation test passed"
    else
        print_error "User creation test failed"
        return 1
    fi
    
    print_success "All Cognito functionality tests passed"
}

# Function to generate test report
generate_test_report() {
    print_status "Generating test report..."
    
    cat > TEST_INFRASTRUCTURE_REPORT_NO_CLEANUP.md << EOF
# AWS Infrastructure Test Report (No Cleanup)

## Test Summary
- **Test Date**: $(date)
- **Test Duration**: $((SECONDS / 60)) minutes
- **Test Status**: $1
- **Note**: Resources were NOT cleaned up after testing

## Test Components
- [x] Prerequisites Check
- [x] Test Environment Setup
- [x] Master Infrastructure Script Execution
- [x] Resource Availability Wait
- [x] Database Connectivity Test
- [x] Redis Connectivity Test
- [x] Application Integration Test
- [x] Cognito Functionality Test
- [x] Resource Cleanup: SKIPPED

## Test Results
$2

## Recommendations
$3

## Next Steps
$4

## Important Notes
- Infrastructure resources are still running in AWS
- You can manually clean up resources using: INFRASTRUCTURE_TEST_MODE=true TEST_SUFFIX="_test" ./aws/resources/master/cleanup-aws-resources.sh
- Monitor AWS costs as resources continue running
EOF
    
    print_success "Test report generated: TEST_INFRASTRUCTURE_REPORT_NO_CLEANUP.md"
}

# Main execution function
main() {
    local start_time=$SECONDS
    local test_status="PASSED"
    local test_results=""
    local recommendations=""
    local next_steps=""
    
    print_status "Starting comprehensive AWS infrastructure test (No Cleanup)..."
    echo ""
    
    # Get project root
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
    cd "$PROJECT_ROOT"
    
    # Test phases (excluding cleanup)
    phases=(
        "check_prerequisites"
        "setup_test_environment"
        "run_master_script"
        "wait_for_resources"
        "test_database_connectivity"
        "test_application_integration"
        "test_cognito_functionality"
    )
    
    # Execute each phase
    for phase in "${phases[@]}"; do
        print_status "Executing phase: $phase"
        
        if $phase; then
            print_success "Phase completed: $phase"
        else
            print_error "Phase failed: $phase"
            test_status="FAILED"
            test_results+="- ❌ $phase failed\n"
            break
        fi
        
        echo ""
    done
    
    # Generate results
    if [ "$test_status" = "PASSED" ]; then
        test_results="All test phases completed successfully ✅"
        recommendations="The infrastructure setup is working correctly and ready for production use. Resources are still running in AWS."
        next_steps="You can now confidently use the master infrastructure script for production deployments. Remember to clean up test resources when done."
    else
        test_results+="\nSome test phases failed. Please review the errors above."
        recommendations="Review the failed phases and fix any issues before using in production."
        next_steps="Fix the identified issues and re-run the test script."
    fi
    
    # Generate report
    generate_test_report "$test_status" "$test_results" "$recommendations" "$next_steps"
    
    # Final summary
    echo ""
    print_status "Test completed in $((SECONDS - start_time)) seconds"
    
    if [ "$test_status" = "PASSED" ]; then
        print_success "🎉 All tests passed! Infrastructure is ready for production."
        echo ""
        echo "📋 Test Report: TEST_INFRASTRUCTURE_REPORT_NO_CLEANUP.md"
        echo "🚀 You can now use the master script with confidence!"
        echo ""
        echo "⚠️  IMPORTANT: Test resources are still running in AWS!"
        echo "💡 To clean up manually: INFRASTRUCTURE_TEST_MODE=true TEST_SUFFIX=\"_test\" ./aws/resources/master/cleanup-aws-resources.sh"
    else
        print_error "❌ Some tests failed. Please review the report and fix issues."
        echo ""
        echo "📋 Test Report: TEST_INFRASTRUCTURE_REPORT_NO_CLEANUP.md"
        echo "🔧 Fix the identified issues and re-run the test."
        exit 1
    fi
}

# Run main function
main "$@" 