#!/bin/bash

# Master Infrastructure Setup Script
# This script orchestrates the complete AWS infrastructure setup

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
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_status "Starting complete AWS infrastructure setup..."
print_status "Project root: $PROJECT_ROOT"
print_status "Scripts directory: $SCRIPTS_DIR"

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install it first."
        exit 1
    fi
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed. Please install it first."
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Function to setup database infrastructure
setup_database() {
    print_status "Setting up database infrastructure..."
    
    cd "$PROJECT_ROOT"
    
    # Run database setup script
    if [ -f "aws/resources/master/setup-aws-database.sh" ]; then
        print_status "Running database setup script..."
        ./aws/resources/master/setup-aws-database.sh
        print_success "Database infrastructure setup completed"
    else
        print_error "Database setup script not found"
        exit 1
    fi
}

# Function to setup jump box (bastion host)
setup_jump_box() {
    print_status "Setting up jump box (bastion host)..."
    
    cd "$PROJECT_ROOT"
    
    # Run jump box setup script
    if [ -f "aws/resources/bastion/setup-jump-box.sh" ]; then
        print_status "Running jump box setup script..."
        ./aws/resources/bastion/setup-jump-box.sh
        print_success "Jump box setup completed"
    else
        print_error "Jump box setup script not found"
        exit 1
    fi
}

# Function to fix Redis access
fix_redis_access() {
    print_status "Fixing Redis access for jump box..."
    
    cd "$PROJECT_ROOT"
    
    # Run Redis access fix script
    if [ -f "aws/resources/redis/fix-redis-access.sh" ]; then
        print_status "Running Redis access fix script..."
        ./aws/resources/redis/fix-redis-access.sh
        print_success "Redis access fixed"
    else
        print_error "Redis access fix script not found"
        exit 1
    fi
}

# Function to setup Cognito authentication
setup_cognito() {
    print_status "Setting up AWS Cognito authentication..."
    
    cd "$PROJECT_ROOT"
    
    # Run Cognito setup script
    if [ -f "aws/resources/cognito/setup-aws-cognito.sh" ]; then
        print_status "Running Cognito setup script..."
        ./aws/resources/cognito/setup-aws-cognito.sh
        print_success "Cognito authentication setup completed"
    else
        print_error "Cognito setup script not found"
        exit 1
    fi
}

# Function to setup database schema
setup_database_schema() {
    print_status "Setting up database schema..."
    
    cd "$PROJECT_ROOT"
    
    # Run database schema setup
    if [ -f "aws/resources/database/setup-database-tunnel.js" ]; then
        print_status "Running database schema setup..."
        node aws/resources/database/setup-database-tunnel.js
        print_success "Database schema setup completed"
    else
        print_error "Database schema setup script not found"
        exit 1
    fi
}

# Function to run connectivity tests
run_connectivity_tests() {
    print_status "Running connectivity tests..."
    
    cd "$PROJECT_ROOT"
    
    # Start SSH tunnels
    print_status "Starting SSH tunnels..."
    ./aws/resources/bastion/tunnel-to-databases.sh &
    TUNNEL_PID=$!
    
    # Wait for tunnels to establish
    sleep 10
    
    # Run connectivity tests
    if [ -f "aws/test/test-local-connections.js" ]; then
        print_status "Running connectivity tests..."
        node aws/test/test-local-connections.js
        print_success "Connectivity tests completed"
    else
        print_error "Connectivity test script not found"
        kill $TUNNEL_PID 2>/dev/null || true
        exit 1
    fi
    
    # Stop tunnels
    print_status "Stopping SSH tunnels..."
    kill $TUNNEL_PID 2>/dev/null || true
}

# Function to generate documentation
generate_documentation() {
    print_status "Generating infrastructure documentation..."
    
    cd "$PROJECT_ROOT"
    
    # Create infrastructure summary
    cat > INFRASTRUCTURE_SUMMARY.md << 'EOF'
# AWS Infrastructure Summary

## Overview
This document summarizes the complete AWS infrastructure setup for the utils-aws-management project.

## Infrastructure Components

### 1. Database Infrastructure
- **PostgreSQL RDS**: Managed PostgreSQL database
- **Redis ElastiCache**: Managed Redis caching layer
- **Security Groups**: Properly configured for secure access

### 2. Jump Box (Bastion Host)
- **EC2 Instance**: t3.micro instance for SSH tunneling
- **Security Groups**: Restricted access to current IP only
- **SSH Tunnels**: Secure access to private databases

### 3. Network Configuration
- **VPC**: Custom VPC for resource isolation
- **Subnets**: Properly configured subnets
- **Security Groups**: Restrictive access policies

## Access Information

### Database Endpoints (via SSH tunnel)
- **PostgreSQL**: localhost:5433
- **Redis**: localhost:6380

### Jump Box Information
- **Public IP**: Available in JUMP_BOX_INFO.md
- **SSH Key**: aws-management-dev-key-*.pem
- **Access**: SSH tunneling only

## Scripts Organization

### Master Scripts
- `aws/resources/master/setup-all-infrastructure.sh`: Complete infrastructure setup
- `aws/resources/master/setup-aws-database.sh`: Database infrastructure setup
- `aws/resources/master/cleanup-aws-resources.sh`: Infrastructure cleanup

### Resource-Specific Scripts
- `aws/resources/database/`: Database setup and schema scripts
- `aws/resources/redis/`: Redis configuration scripts
- `aws/resources/bastion/`: Jump box setup and tunnel scripts

### Test Scripts
- `aws/test/`: All connectivity and functionality test scripts

## Usage

### Initial Setup
```bash
cd aws/resources/master
./setup-all-infrastructure.sh
```

### Start Database Access
```bash
cd aws/resources/bastion
./tunnel-to-databases.sh
```

### Test Connections
```bash
cd aws/test
node test-local-connections.js
```

### Cleanup
```bash
cd aws/resources/master
./cleanup-aws-resources.sh
```

## Security Notes
- All database access is restricted to the jump box
- SSH tunnels provide encrypted access
- Security groups are configured for minimal access
- Jump box is accessible only from authorized IPs

## Cost Estimation
- RDS PostgreSQL: ~$15-20/month
- ElastiCache Redis: ~$10-15/month
- EC2 Jump Box: ~$8-10/month
- **Total**: ~$33-45/month

## Maintenance
- Monitor AWS costs regularly
- Terminate jump box when not in use
- Keep security groups updated
- Regularly test connectivity
EOF

    print_success "Infrastructure documentation generated"
}

# Main execution flow
main() {
    print_status "Starting complete AWS infrastructure setup..."
    
    # Check prerequisites
    check_prerequisites
    
    # Setup Cognito authentication
    setup_cognito
    
    # Setup database infrastructure
    setup_database
    
    # Setup jump box
    setup_jump_box
    
    # Fix Redis access
    fix_redis_access
    
    # Setup database schema
    setup_database_schema
    
    # Run connectivity tests
    run_connectivity_tests
    
    # Generate documentation
    generate_documentation
    
    print_success "Complete AWS infrastructure setup finished!"
    echo ""
    echo "🎉 Infrastructure is ready!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Start SSH tunnels: ./aws/resources/bastion/tunnel-to-databases.sh"
    echo "2. Test connections: node aws/test/test-local-connections.js"
    echo "3. Review documentation: INFRASTRUCTURE_SUMMARY.md"
    echo ""
    echo "⚠️  Remember to terminate the jump box when not in use to save costs"
}

# Run main function
main "$@" 