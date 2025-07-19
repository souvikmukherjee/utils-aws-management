#!/bin/bash

# Test Infrastructure Setup Script
# This script tests the complete AWS infrastructure setup from scratch
# It creates all resources with "_test" suffix, verifies connectivity, then cleans up

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

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if AWS credentials are configured
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    # Check if Node.js is installed
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install it first."
        exit 1
    fi
    
    # Check if npm is installed
    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed. Please install it first."
        exit 1
    fi
    
    # Check if required Node.js packages are installed
    if [ ! -d "node_modules" ]; then
        print_status "Installing Node.js dependencies..."
        npm install
    fi
    
    print_success "All prerequisites are satisfied"
}

# Function to set test environment variables
setup_test_environment() {
    print_status "Setting up test environment variables..."
    
    # Create test environment file
    cat > .env.test << EOF
# Test Environment Variables
NODE_ENV=test
AWS_REGION=ap-southeast-2

# Test Database Configuration
DB_HOST=localhost
DB_PORT=5433
DB_NAME=aws_management_test
DB_USER=postgres
DB_PASSWORD=test_password_123

# Test Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6380
REDIS_PASSWORD=

# Test Cognito Configuration
COGNITO_USER_POOL_ID=test_user_pool_id
COGNITO_CLIENT_ID=test_client_id
COGNITO_REGION=ap-southeast-2

# Test Application Configuration
NEXTAUTH_SECRET=test-nextauth-secret-key-here
NEXTAUTH_URL=http://localhost:3000
EOF
    
    print_success "Test environment variables created"
}

# Function to run the master infrastructure script with test parameters
run_master_script() {
    print_status "Running master infrastructure script with test parameters..."
    
    # Set test environment variable
    export INFRASTRUCTURE_TEST_MODE=true
    export TEST_SUFFIX="_test"
    
    # Run the master script
    cd "$PROJECT_ROOT/aws/resources/master"
    ./setup-all-infrastructure.sh
    
    print_success "Master infrastructure script completed"
}

# Function to wait for resources to be ready
wait_for_resources() {
    print_status "Waiting for AWS resources to be ready..."
    
    # Wait for RDS to be available
    print_status "Waiting for RDS instance to be available..."
    aws rds wait db-instance-available --db-instance-identifier aws-management-dev-db-test
    
    # Wait for ElastiCache to be available
    print_status "Waiting for ElastiCache cluster to be available..."
    aws elasticache wait cache-cluster-available --cache-cluster-id aws-management-dev-redis-test
    
    # Wait for EC2 instance to be running
    print_status "Waiting for EC2 jump box to be running..."
    aws ec2 wait instance-running --instance-ids $(aws ec2 describe-instances --filters "Name=tag:Name,Values=aws-management-dev-jump-box-test" --query 'Reservations[].Instances[].InstanceId' --output text)
    
    print_success "All AWS resources are ready"
}

# Function to test database connectivity
test_database_connectivity() {
    print_status "Testing database connectivity..."
    
    # Wait a bit for SSH tunnels to establish
    sleep 10
    
    # Test PostgreSQL connection
    print_status "Testing PostgreSQL connection..."
    if node aws/test/test-local-connections.js; then
        print_success "PostgreSQL connectivity test passed"
    else
        print_error "PostgreSQL connectivity test failed"
        return 1
    fi
    
    # Test Redis connection
    print_status "Testing Redis connection..."
    if node aws/test/test-redis-simple.js; then
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
    if node aws/resources/database/setup-database-tunnel.js; then
        print_success "Database schema setup test passed"
    else
        print_error "Database schema setup test failed"
        return 1
    fi
    
    # Test CRUD operations
    print_status "Testing CRUD operations..."
    if node aws/test/test-db-direct.js; then
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
    if ./aws/resources/auth/check-and-create-users.sh; then
        print_success "User creation test passed"
    else
        print_error "User creation test failed"
        return 1
    fi
    
    print_success "All Cognito functionality tests passed"
}

# Function to cleanup test resources
cleanup_test_resources() {
    print_status "Cleaning up test resources..."
    
    # Set test environment variable for cleanup
    export INFRASTRUCTURE_TEST_MODE=true
    export TEST_SUFFIX="_test"
    
    # Run cleanup script
    cd "$PROJECT_ROOT/aws/resources/master"
    ./cleanup-aws-resources.sh
    
    # Remove test environment file
    rm -f "$PROJECT_ROOT/.env.test"
    
    print_success "Test resources cleaned up"
}

# Function to generate test report
generate_test_report() {
    print_status "Generating test report..."
    
    cat > TEST_INFRASTRUCTURE_REPORT.md << EOF
# AWS Infrastructure Test Report

## Test Summary
- **Test Date**: $(date)
- **Test Duration**: $((SECONDS / 60)) minutes
- **Test Status**: $1

## Test Components
- [x] Prerequisites Check
- [x] Test Environment Setup
- [x] Master Infrastructure Script Execution
- [x] Resource Availability Wait
- [x] Database Connectivity Test
- [x] Redis Connectivity Test
- [x] Application Integration Test
- [x] Cognito Functionality Test
- [x] Resource Cleanup

## Test Results
$2

## Recommendations
$3

## Next Steps
$4
EOF
    
    print_success "Test report generated: TEST_INFRASTRUCTURE_REPORT.md"
}

# Main execution function
main() {
    local start_time=$SECONDS
    local test_status="PASSED"
    local test_results=""
    local recommendations=""
    local next_steps=""
    
    print_status "Starting comprehensive AWS infrastructure test..."
    echo ""
    
    # Get project root
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
    cd "$PROJECT_ROOT"
    
    # Test phases
    phases=(
        "check_prerequisites"
        "setup_test_environment"
        "run_master_script"
        "wait_for_resources"
        "test_database_connectivity"
        "test_application_integration"
        "test_cognito_functionality"
        "cleanup_test_resources"
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
        recommendations="The infrastructure setup is working correctly and ready for production use."
        next_steps="You can now confidently use the master infrastructure script for production deployments."
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
        echo "📋 Test Report: TEST_INFRASTRUCTURE_REPORT.md"
        echo "🚀 You can now use the master script with confidence!"
    else
        print_error "❌ Some tests failed. Please review the report and fix issues."
        echo ""
        echo "📋 Test Report: TEST_INFRASTRUCTURE_REPORT.md"
        echo "🔧 Fix the identified issues and re-run the test."
        exit 1
    fi
}

# Run main function
main "$@" 