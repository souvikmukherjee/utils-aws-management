#!/bin/bash

# AWS Database and Caching Setup Script
# This script sets up PostgreSQL RDS and Redis ElastiCache for the AWS Management Utilities

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

# Function to check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    print_success "AWS CLI is installed"
}

# Function to check if jq is installed
check_jq() {
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install it first."
        exit 1
    fi
    print_success "jq is installed"
}

# Function to validate AWS credentials
validate_aws_credentials() {
    print_status "Validating AWS credentials..."
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured or invalid."
        print_status "Please run 'aws configure' to set up your credentials."
        exit 1
    fi
    
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION=$(aws configure get region)
    print_success "AWS credentials validated"
    print_status "Account ID: $AWS_ACCOUNT_ID"
    print_status "Region: $AWS_REGION"
}

# Function to get user input
get_user_input() {
    print_status "Please provide the following information:"
    
    # Check if running in test mode
    if [ "$INFRASTRUCTURE_TEST_MODE" = "true" ]; then
        RESOURCE_SUFFIX="${TEST_SUFFIX:-_test}"
        print_status "Running in TEST MODE with suffix: $RESOURCE_SUFFIX"
        # Use default values for test mode
        PROJECT_NAME="aws-management"
        ENVIRONMENT="dev"
        DB_INSTANCE_TYPE="db.t3.micro"
        REDIS_NODE_TYPE="cache.t3.micro"
        DB_PASSWORD="[PASSWORD]"
        print_success "Using test configuration"
    else
        RESOURCE_SUFFIX=""
        # Get project name
        read -p "Project name (default: aws-management): " PROJECT_NAME
        PROJECT_NAME=${PROJECT_NAME:-aws-management}
        
        # Get environment
        read -p "Environment (dev/staging/prod, default: dev): " ENVIRONMENT
        ENVIRONMENT=${ENVIRONMENT:-dev}
        
        # Get database instance type
        read -p "RDS instance type (default: db.t3.micro): " DB_INSTANCE_TYPE
        DB_INSTANCE_TYPE=${DB_INSTANCE_TYPE:-db.t3.micro}
        
        # Get Redis node type
        read -p "Redis node type (default: cache.t3.micro): " REDIS_NODE_TYPE
        REDIS_NODE_TYPE=${REDIS_NODE_TYPE:-cache.t3.micro}
        
        # Get database password
        read -s -p "Database master password: " DB_PASSWORD
        echo
        read -s -p "Confirm database master password: " DB_PASSWORD_CONFIRM
        echo
        
        if [ "$DB_PASSWORD" != "$DB_PASSWORD_CONFIRM" ]; then
            print_error "Passwords do not match"
            exit 1
        fi
    fi
    
    # Generate unique identifiers
    TIMESTAMP=$(date +%s)
    STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}-${TIMESTAMP}${RESOURCE_SUFFIX}"
    # Ensure RDS identifier follows AWS naming rules (no trailing hyphen, no consecutive hyphens)
    DB_INSTANCE_IDENTIFIER="${PROJECT_NAME}-${ENVIRONMENT}-db-${TIMESTAMP}${RESOURCE_SUFFIX//_/-}"
    REDIS_CLUSTER_ID="${PROJECT_NAME}-${ENVIRONMENT}-redis-${TIMESTAMP}${RESOURCE_SUFFIX//_/-}"
    SECURITY_GROUP_NAME="${PROJECT_NAME}-${ENVIRONMENT}-sg-${TIMESTAMP}${RESOURCE_SUFFIX//_/-}"
    
    print_success "Configuration validated"
}

# Function to create VPC and networking (if needed)
setup_networking() {
    print_status "Setting up networking infrastructure..."
    
    # Get default VPC
    VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
    
    if [ "$VPC_ID" == "None" ]; then
        print_error "No default VPC found. Please create a VPC first."
        exit 1
    fi
    
    # Get default subnets
    SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text)
    SUBNET_IDS_ARRAY=($SUBNET_IDS)
    
    if [ ${#SUBNET_IDS_ARRAY[@]} -lt 2 ]; then
        print_error "Need at least 2 subnets for RDS. Found ${#SUBNET_IDS_ARRAY[@]}"
        exit 1
    fi
    
    # Use first two subnets
    DB_SUBNET_GROUP_NAME="${PROJECT_NAME}-${ENVIRONMENT}-subnet-group-${TIMESTAMP}${RESOURCE_SUFFIX//_/-}"
    
    # Create DB subnet group
    aws rds create-db-subnet-group \
        --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
        --db-subnet-group-description "Subnet group for ${PROJECT_NAME} ${ENVIRONMENT}" \
        --subnet-ids "${SUBNET_IDS_ARRAY[0]}" "${SUBNET_IDS_ARRAY[1]}" \
        --tags Key=Project,Value="$PROJECT_NAME" Key=Environment,Value="$ENVIRONMENT" \
        > /dev/null
    
    print_success "Created DB subnet group: $DB_SUBNET_GROUP_NAME"
}

# Function to create security groups
create_security_groups() {
    print_status "Creating security groups..."
    
    # Create security group for RDS
    RDS_SECURITY_GROUP_ID=$(aws ec2 create-security-group \
        --group-name "${SECURITY_GROUP_NAME}-rds" \
        --description "Security group for ${PROJECT_NAME} RDS ${ENVIRONMENT}" \
        --vpc-id "$VPC_ID" \
        --query 'GroupId' --output text)
    
    # Create security group for Redis
    REDIS_SECURITY_GROUP_ID=$(aws ec2 create-security-group \
        --group-name "${SECURITY_GROUP_NAME}-redis" \
        --description "Security group for ${PROJECT_NAME} Redis ${ENVIRONMENT}" \
        --vpc-id "$VPC_ID" \
        --query 'GroupId' --output text)
    
    # Allow PostgreSQL access from anywhere (for development)
    # Function to add security group rule with error handling
    add_security_group_rule() {
        local group_id="$1"
        local protocol="$2"
        local port="$3"
        local cidr="$4"
        
        # Try to add the rule, but handle duplicate errors gracefully
        if aws ec2 authorize-security-group-ingress \
            --group-id "$group_id" \
            --protocol "$protocol" \
            --port "$port" \
            --cidr "$cidr" \
            > /dev/null 2>&1; then
            print_success "Added security group rule successfully (port $port)"
        else
            # Check if it's a duplicate error by checking existing rules
            if aws ec2 describe-security-groups \
                --group-ids "$group_id" \
                --query "SecurityGroups[0].IpPermissions[?FromPort==$port && ToPort==$port && IpProtocol=='$protocol' && length(IpRanges[?CidrIp=='$cidr']) > 0]" \
                --output text | grep -q .; then
                print_warning "Security group rule already exists (port $port, CIDR $cidr)"
            else
                print_error "Failed to add security group rule (port $port, CIDR $cidr)"
                return 1
            fi
        fi
    }
    
    # Add PostgreSQL access rule
    add_security_group_rule "$RDS_SECURITY_GROUP_ID" "tcp" "5432" "0.0.0.0/0"
    
    # Add Redis access rule
    add_security_group_rule "$REDIS_SECURITY_GROUP_ID" "tcp" "6379" "0.0.0.0/0"
    
    print_success "Created security groups"
    print_status "RDS Security Group: $RDS_SECURITY_GROUP_ID"
    print_status "Redis Security Group: $REDIS_SECURITY_GROUP_ID"
}

# Function to create RDS PostgreSQL instance
create_rds_instance() {
    print_status "Creating RDS PostgreSQL instance..."
    
    # Create RDS instance
    aws rds create-db-instance \
        --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
        --db-instance-class "$DB_INSTANCE_TYPE" \
        --engine postgres \
        --engine-version "15.13" \
        --master-username postgres \
        --master-user-password "$DB_PASSWORD" \
        --allocated-storage 20 \
        --storage-type gp2 \
        --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
        --vpc-security-group-ids "$RDS_SECURITY_GROUP_ID" \
        --backup-retention-period 7 \
        --preferred-backup-window "03:00-04:00" \
        --preferred-maintenance-window "sun:04:00-sun:05:00" \
        --tags Key=Project,Value="$PROJECT_NAME" Key=Environment,Value="$ENVIRONMENT" \
        > /dev/null
    
    print_success "RDS instance creation initiated: $DB_INSTANCE_IDENTIFIER"
    print_warning "RDS instance creation takes 5-10 minutes. Please wait..."
    
    # Wait for RDS instance to be available
    print_status "Waiting for RDS instance to be available..."
    aws rds wait db-instance-available --db-instance-identifier "$DB_INSTANCE_IDENTIFIER"
    
    # Get RDS endpoint
    DB_ENDPOINT=$(aws rds describe-db-instances \
        --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
        --query 'DBInstances[0].Endpoint.Address' --output text)
    
    print_success "RDS instance is available"
    print_status "RDS Endpoint: $DB_ENDPOINT"
}

# Function to create Redis ElastiCache cluster
create_redis_cluster() {
    print_status "Creating Redis ElastiCache cluster..."
    
    # Create Redis subnet group
    REDIS_SUBNET_GROUP_NAME="${PROJECT_NAME}-${ENVIRONMENT}-redis-subnet-${TIMESTAMP}${RESOURCE_SUFFIX//_/-}"
    
    aws elasticache create-cache-subnet-group \
        --cache-subnet-group-name "$REDIS_SUBNET_GROUP_NAME" \
        --cache-subnet-group-description "Redis subnet group for ${PROJECT_NAME} ${ENVIRONMENT}" \
        --subnet-ids "${SUBNET_IDS_ARRAY[0]}" "${SUBNET_IDS_ARRAY[1]}" \
        > /dev/null
    
    # Create Redis cluster
    aws elasticache create-cache-cluster \
        --cache-cluster-id "$REDIS_CLUSTER_ID" \
        --engine redis \
        --cache-node-type "$REDIS_NODE_TYPE" \
        --num-cache-nodes 1 \
        --cache-subnet-group-name "$REDIS_SUBNET_GROUP_NAME" \
        --security-group-ids "$REDIS_SECURITY_GROUP_ID" \
        --tags Key=Project,Value="$PROJECT_NAME" Key=Environment,Value="$ENVIRONMENT" \
        > /dev/null
    
    print_success "Redis cluster creation initiated: $REDIS_CLUSTER_ID"
    print_warning "Redis cluster creation takes 5-10 minutes. Please wait..."
    
    # Wait for Redis cluster to be available
    print_status "Waiting for Redis cluster to be available..."
    aws elasticache wait cache-cluster-available --cache-cluster-id "$REDIS_CLUSTER_ID"
    
    # Get Redis endpoint
    REDIS_ENDPOINT=$(aws elasticache describe-cache-clusters \
        --cache-cluster-id "$REDIS_CLUSTER_ID" \
        --show-cache-node-info \
        --query 'CacheClusters[0].CacheNodes[0].Endpoint.Address' --output text)
    
    REDIS_PORT=$(aws elasticache describe-cache-clusters \
        --cache-cluster-id "$REDIS_CLUSTER_ID" \
        --show-cache-node-info \
        --query 'CacheClusters[0].CacheNodes[0].Endpoint.Port' --output text)
    
    print_success "Redis cluster is available"
    print_status "Redis Endpoint: $REDIS_ENDPOINT:$REDIS_PORT"
}

# Function to generate environment variables
generate_env_vars() {
    print_status "Generating environment variables..."
    
    # Create .env.local with database configuration
    cat > .env.local << EOF
# NextAuth.js Configuration
NEXTAUTH_URL=http://localhost:3001
NEXTAUTH_SECRET=your-nextauth-secret-key-here

# AWS Cognito Configuration
COGNITO_CLIENT_ID=4dalr0pp7j5folc1g33khf6ai1
COGNITO_CLIENT_SECRET=
COGNITO_ISSUER=https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_r24gyJxHq

# AWS Configuration
AWS_REGION=$AWS_REGION

# Demo Authentication Credentials (for development only)
DEMO_USER_EMAIL=demo@example.com
DEMO_USER_PASSWORD=your-demo-user-password-here
TEST_USER_EMAIL=test@example.com
TEST_USER_PASSWORD=your-test-user-password-here

# Database Configuration
DATABASE_URL=postgresql://postgres:${DB_PASSWORD}@${DB_ENDPOINT}:5432/${PROJECT_NAME}_${ENVIRONMENT}
DB_HOST=${DB_ENDPOINT}
DB_PORT=5432
DB_NAME=${PROJECT_NAME}_${ENVIRONMENT}
DB_USER=postgres
DB_PASSWORD=${DB_PASSWORD}

# Redis Configuration
REDIS_URL=redis://${REDIS_ENDPOINT}:${REDIS_PORT}
REDIS_HOST=${REDIS_ENDPOINT}
REDIS_PORT=${REDIS_PORT}
REDIS_PASSWORD=

# AWS Resource IDs (for reference)
RDS_INSTANCE_ID=${DB_INSTANCE_IDENTIFIER}
REDIS_CLUSTER_ID=${REDIS_CLUSTER_ID}
RDS_SECURITY_GROUP=${RDS_SECURITY_GROUP_ID}
REDIS_SECURITY_GROUP=${REDIS_SECURITY_GROUP_ID}
DB_SUBNET_GROUP=${DB_SUBNET_GROUP_NAME}
EOF

    print_success "Generated .env.local with database configuration"
}

# Function to create database setup script
create_db_setup_script() {
    print_status "Creating database setup script..."
    
    cat > setup-database.sql << EOF
-- Database setup script for ${PROJECT_NAME} ${ENVIRONMENT}
-- Run this script to initialize the database schema

-- Create database if it doesn't exist
SELECT 'CREATE DATABASE ${PROJECT_NAME}_${ENVIRONMENT}'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${PROJECT_NAME}_${ENVIRONMENT}')\gexec

-- Connect to the database
\c ${PROJECT_NAME}_${ENVIRONMENT}

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create aws_resources table
CREATE TABLE IF NOT EXISTS aws_resources (
    id SERIAL PRIMARY KEY,
    resource_id VARCHAR(255) UNIQUE NOT NULL,
    resource_type VARCHAR(100) NOT NULL,
    resource_name VARCHAR(255),
    region VARCHAR(50),
    tags JSONB,
    cost_per_hour DECIMAL(10,4),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create cost_analytics table
CREATE TABLE IF NOT EXISTS cost_analytics (
    id SERIAL PRIMARY KEY,
    resource_id VARCHAR(255) NOT NULL,
    date DATE NOT NULL,
    cost DECIMAL(10,4) NOT NULL,
    usage_hours DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (resource_id) REFERENCES aws_resources(resource_id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_aws_resources_type ON aws_resources(resource_type);
CREATE INDEX IF NOT EXISTS idx_aws_resources_region ON aws_resources(region);
CREATE INDEX IF NOT EXISTS idx_cost_analytics_date ON cost_analytics(date);
CREATE INDEX IF NOT EXISTS idx_cost_analytics_resource ON cost_analytics(resource_id);

-- Insert sample data
INSERT INTO users (email, name) VALUES 
    ('demo@example.com', 'Demo User'),
    ('test@example.com', 'Test User')
ON CONFLICT (email) DO NOTHING;

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS \$\$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
\$\$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_aws_resources_updated_at BEFORE UPDATE ON aws_resources FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_cost_analytics_updated_at BEFORE UPDATE ON cost_analytics FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;
EOF

    print_success "Created database setup script: setup-database.sql"
}

# Function to create connection test script
create_test_script() {
    print_status "Creating connection test script..."
    
    cat > test-connections.js << EOF
const { Client } = require('pg');
const Redis = require('redis');

// Test PostgreSQL connection
async function testPostgreSQL() {
    console.log('Testing PostgreSQL connection...');
    
    const client = new Client({
        host: process.env.DB_HOST,
        port: process.env.DB_PORT,
        database: process.env.DB_NAME,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
    });
    
    try {
        await client.connect();
        console.log('✅ PostgreSQL connection successful');
        
        const result = await client.query('SELECT NOW() as current_time');
        console.log('Current database time:', result.rows[0].current_time);
        
        await client.end();
    } catch (error) {
        console.error('❌ PostgreSQL connection failed:', error.message);
    }
}

// Test Redis connection
async function testRedis() {
    console.log('Testing Redis connection...');
    
    const client = Redis.createClient({
        url: process.env.REDIS_URL
    });
    
    try {
        await client.connect();
        console.log('✅ Redis connection successful');
        
        await client.set('test_key', 'Hello Redis!');
        const value = await client.get('test_key');
        console.log('Test value from Redis:', value);
        
        await client.quit();
    } catch (error) {
        console.error('❌ Redis connection failed:', error.message);
    }
}

// Load environment variables
require('dotenv').config({ path: '.env.local' });

// Run tests
async function runTests() {
    console.log('🔍 Testing database connections...\\n');
    
    await testPostgreSQL();
    console.log('');
    await testRedis();
    
    console.log('\\n🎉 Connection tests completed!');
}

runTests().catch(console.error);
EOF

    print_success "Created connection test script: test-connections.js"
}

# Function to create cleanup script
create_cleanup_script() {
    print_status "Creating cleanup script..."
    
    cat > cleanup-aws-resources.sh << EOF
#!/bin/bash

# Cleanup script for AWS resources
# WARNING: This will delete all created resources!

set -e

echo "🧹 Cleaning up AWS resources..."

# Delete Redis cluster
echo "Deleting Redis cluster: $REDIS_CLUSTER_ID"
aws elasticache delete-cache-cluster --cache-cluster-id "$REDIS_CLUSTER_ID" --final-snapshot-identifier "${REDIS_CLUSTER_ID}-final-snapshot" || true

# Delete RDS instance
echo "Deleting RDS instance: $DB_INSTANCE_IDENTIFIER"
aws rds delete-db-instance --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" --skip-final-snapshot || true

# Delete security groups
echo "Deleting security groups..."
aws ec2 delete-security-group --group-id "$RDS_SECURITY_GROUP_ID" || true
aws ec2 delete-security-group --group-id "$REDIS_SECURITY_GROUP_ID" || true

# Delete subnet groups
echo "Deleting subnet groups..."
aws rds delete-db-subnet-group --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" || true
aws elasticache delete-cache-subnet-group --cache-subnet-group-name "$REDIS_SUBNET_GROUP_NAME" || true

echo "✅ Cleanup completed!"
echo "Note: Some resources may take a few minutes to be fully deleted."
EOF

    chmod +x cleanup-aws-resources.sh
    print_success "Created cleanup script: cleanup-aws-resources.sh"
}

# Function to create summary
create_summary() {
    print_status "Creating setup summary..."
    
    cat > DATABASE_SETUP_SUMMARY.md << EOF
# Database and Caching Setup Summary

## Project: ${PROJECT_NAME}
## Environment: ${ENVIRONMENT}
## Setup Date: $(date)

## AWS Resources Created

### PostgreSQL RDS
- **Instance ID**: ${DB_INSTANCE_IDENTIFIER}
- **Endpoint**: ${DB_ENDPOINT}
- **Port**: 5432
- **Database**: ${PROJECT_NAME}_${ENVIRONMENT}
- **Username**: postgres
- **Instance Type**: ${DB_INSTANCE_TYPE}
- **Security Group**: ${RDS_SECURITY_GROUP_ID}

### Redis ElastiCache
- **Cluster ID**: ${REDIS_CLUSTER_ID}
- **Endpoint**: ${REDIS_ENDPOINT}
- **Port**: ${REDIS_PORT}
- **Node Type**: ${REDIS_NODE_TYPE}
- **Security Group**: ${REDIS_SECURITY_GROUP_ID}

### Networking
- **VPC**: ${VPC_ID}
- **DB Subnet Group**: ${DB_SUBNET_GROUP_NAME}
- **Redis Subnet Group**: ${REDIS_SUBNET_GROUP_NAME}

## Environment Variables

The following environment variables have been added to \`.env.local\`:

\`\`\`
DATABASE_URL=postgresql://postgres:${DB_PASSWORD}@${DB_ENDPOINT}:5432/${PROJECT_NAME}_${ENVIRONMENT}
DB_HOST=${DB_ENDPOINT}
DB_PORT=5432
DB_NAME=${PROJECT_NAME}_${ENVIRONMENT}
DB_USER=postgres
DB_PASSWORD=${DB_PASSWORD}

REDIS_URL=redis://${REDIS_ENDPOINT}:${REDIS_PORT}
REDIS_HOST=${REDIS_ENDPOINT}
REDIS_PORT=${REDIS_PORT}
\`\`\`

## Next Steps

1. **Test Connections**: Run \`node test-connections.js\` to verify connectivity
2. **Initialize Database**: Connect to PostgreSQL and run \`setup-database.sql\`
3. **Update Application**: Configure your application to use these connection strings
4. **Monitor Costs**: Keep an eye on AWS billing for these resources

## Security Notes

- Security groups are currently open to 0.0.0.0/0 for development
- Consider restricting access to specific IP ranges for production
- Database password is stored in \`.env.local\` - keep this file secure
- Enable encryption at rest for production environments

## Cleanup

To delete all created resources, run:
\`\`\`bash
./cleanup-aws-resources.sh
\`\`\`

## Cost Estimation

- **RDS PostgreSQL (${DB_INSTANCE_TYPE})**: ~$15-30/month
- **Redis ElastiCache (${REDIS_NODE_TYPE})**: ~$15-30/month
- **Total estimated cost**: ~$30-60/month

*Costs may vary based on usage and region*
EOF

    print_success "Created setup summary: DATABASE_SETUP_SUMMARY.md"
}

# Main execution
main() {
    echo "🚀 AWS Database and Caching Setup Script"
    echo "========================================"
    echo ""
    
    # Check prerequisites
    check_aws_cli
    check_jq
    validate_aws_credentials
    
    # Get user input
    get_user_input
    
    # Setup infrastructure
    setup_networking
    create_security_groups
    create_rds_instance
    create_redis_cluster
    
    # Generate configuration
    generate_env_vars
    create_db_setup_script
    create_test_script
    create_cleanup_script
    create_summary
    
    echo ""
    echo "🎉 Setup completed successfully!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Test connections: node test-connections.js"
    echo "2. Initialize database: psql -h ${DB_ENDPOINT} -U postgres -d ${PROJECT_NAME}_${ENVIRONMENT} -f setup-database.sql"
    echo "3. Update your application to use the new environment variables"
    echo "4. Review DATABASE_SETUP_SUMMARY.md for details"
    echo ""
    echo "⚠️  Important: Keep your .env.local file secure and never commit it to version control!"
}

# Run main function
main "$@" 