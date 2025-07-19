#!/bin/bash

# Fix Database Connectivity Script
# This script makes the RDS and Redis instances publicly accessible

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

# Get the instance identifiers from environment or use defaults
DB_INSTANCE_IDENTIFIER="aws-management-dev-db-1752944212"
REDIS_CLUSTER_ID="aws-management-dev-redis-1752944212"

print_status "Fixing database connectivity issues..."

# Check if RDS instance exists and get current status
print_status "Checking RDS instance status..."
RDS_STATUS=$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$RDS_STATUS" == "NOT_FOUND" ]; then
    print_error "RDS instance $DB_INSTANCE_IDENTIFIER not found"
    exit 1
fi

print_success "RDS instance found with status: $RDS_STATUS"

# Check if RDS is publicly accessible
print_status "Checking RDS public accessibility..."
IS_PUBLIC=$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" --query 'DBInstances[0].PubliclyAccessible' --output text 2>/dev/null || echo "false")

if [ "$IS_PUBLIC" == "true" ]; then
    print_success "RDS instance is already publicly accessible"
else
    print_warning "RDS instance is not publicly accessible. Making it public..."
    
    # Make RDS instance publicly accessible
    aws rds modify-db-instance \
        --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
        --publicly-accessible \
        --apply-immediately \
        > /dev/null
    
    print_success "RDS instance modification initiated"
    print_warning "This may take a few minutes to complete..."
    
    # Wait for the modification to complete
    print_status "Waiting for RDS modification to complete..."
    aws rds wait db-instance-available --db-instance-identifier "$DB_INSTANCE_IDENTIFIER"
    
    print_success "RDS instance is now publicly accessible"
fi

# Check Redis cluster status
print_status "Checking Redis cluster status..."
REDIS_STATUS=$(aws elasticache describe-cache-clusters --cache-cluster-id "$REDIS_CLUSTER_ID" --query 'CacheClusters[0].CacheClusterStatus' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$REDIS_STATUS" == "NOT_FOUND" ]; then
    print_error "Redis cluster $REDIS_CLUSTER_ID not found"
    exit 1
fi

print_success "Redis cluster found with status: $REDIS_STATUS"

# Get the current endpoints
print_status "Getting current endpoints..."

DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" --query 'DBInstances[0].Endpoint.Address' --output text)
REDIS_ENDPOINT=$(aws elasticache describe-cache-clusters --cache-cluster-id "$REDIS_CLUSTER_ID" --show-cache-node-info --query 'CacheClusters[0].CacheNodes[0].Endpoint.Address' --output text)
REDIS_PORT=$(aws elasticache describe-cache-clusters --cache-cluster-id "$REDIS_CLUSTER_ID" --show-cache-node-info --query 'CacheClusters[0].CacheNodes[0].Endpoint.Port' --output text)

print_success "Current endpoints:"
print_status "RDS: $DB_ENDPOINT"
print_status "Redis: $REDIS_ENDPOINT:$REDIS_PORT"

# Test connectivity
print_status "Testing connectivity..."

# Test RDS connectivity
print_status "Testing RDS connectivity..."
if nc -z "$DB_ENDPOINT" 5432 2>/dev/null; then
    print_success "RDS port 5432 is accessible"
else
    print_warning "RDS port 5432 is not accessible from this machine"
    print_status "This is expected if you're connecting from outside AWS"
fi

# Test Redis connectivity
print_status "Testing Redis connectivity..."
if nc -z "$REDIS_ENDPOINT" "$REDIS_PORT" 2>/dev/null; then
    print_success "Redis port $REDIS_PORT is accessible"
else
    print_warning "Redis port $REDIS_PORT is not accessible from this machine"
    print_status "This is expected if you're connecting from outside AWS"
fi

# Update .env.local with the current endpoints
print_status "Updating .env.local with current endpoints..."

# Read the current .env.local file
if [ -f .env.local ]; then
    # Create a backup
    cp .env.local .env.local.backup
    
    # Update the database and Redis endpoints
    sed -i '' "s|DB_HOST=.*|DB_HOST=$DB_ENDPOINT|g" .env.local
    sed -i '' "s|REDIS_HOST=.*|REDIS_HOST=$REDIS_ENDPOINT|g" .env.local
    sed -i '' "s|REDIS_PORT=.*|REDIS_PORT=$REDIS_PORT|g" .env.local
    sed -i '' "s|DATABASE_URL=.*|DATABASE_URL=postgresql://postgres:\${DB_PASSWORD}@$DB_ENDPOINT:5432/\${DB_NAME}|g" .env.local
    sed -i '' "s|REDIS_URL=.*|REDIS_URL=redis://$REDIS_ENDPOINT:$REDIS_PORT|g" .env.local
    
    print_success "Updated .env.local with current endpoints"
else
    print_error ".env.local file not found"
    exit 1
fi

# Create a connectivity test script
print_status "Creating enhanced connectivity test script..."

cat > test-connectivity-enhanced.js << EOF
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
        ssl: {
            rejectUnauthorized: false
        },
        connectionTimeoutMillis: 10000,
        query_timeout: 10000
    });
    
    try {
        await client.connect();
        console.log('✅ PostgreSQL connection successful');
        
        const result = await client.query('SELECT NOW() as current_time, version() as version');
        console.log('Current database time:', result.rows[0].current_time);
        console.log('PostgreSQL version:', result.rows[0].version.split(' ')[0]);
        
        await client.end();
    } catch (error) {
        console.error('❌ PostgreSQL connection failed:', error.message);
        console.error('Error details:', error);
    }
}

// Test Redis connection
async function testRedis() {
    console.log('Testing Redis connection...');
    
    const client = Redis.createClient({
        url: process.env.REDIS_URL,
        socket: {
            connectTimeout: 10000,
            commandTimeout: 10000
        }
    });
    
    try {
        await client.connect();
        console.log('✅ Redis connection successful');
        
        await client.set('test_key', 'Hello Redis!');
        const value = await client.get('test_key');
        console.log('Test value from Redis:', value);
        
        // Test Redis info
        const info = await client.info('server');
        console.log('Redis server info:', info.split('\\n')[0]);
        
        await client.quit();
    } catch (error) {
        console.error('❌ Redis connection failed:', error.message);
        console.error('Error details:', error);
    }
}

// Load environment variables
require('dotenv').config({ path: '.env.local' });

// Run tests
async function runTests() {
    console.log('🔍 Testing database connections with enhanced error reporting...\\n');
    
    console.log('Environment variables:');
    console.log('DB_HOST:', process.env.DB_HOST);
    console.log('DB_PORT:', process.env.DB_PORT);
    console.log('DB_NAME:', process.env.DB_NAME);
    console.log('REDIS_HOST:', process.env.REDIS_HOST);
    console.log('REDIS_PORT:', process.env.REDIS_PORT);
    console.log('');
    
    await testPostgreSQL();
    console.log('');
    await testRedis();
    
    console.log('\\n🎉 Connection tests completed!');
}

runTests().catch(console.error);
EOF

print_success "Created enhanced connectivity test script: test-connectivity-enhanced.js"

# Create a troubleshooting guide
print_status "Creating troubleshooting guide..."

cat > DATABASE_TROUBLESHOOTING.md << EOF
# Database Connectivity Troubleshooting Guide

## Current Configuration

### PostgreSQL RDS
- **Instance ID**: $DB_INSTANCE_IDENTIFIER
- **Endpoint**: $DB_ENDPOINT
- **Publicly Accessible**: $IS_PUBLIC
- **Status**: $RDS_STATUS

### Redis ElastiCache
- **Cluster ID**: $REDIS_CLUSTER_ID
- **Endpoint**: $REDIS_ENDPOINT:$REDIS_PORT
- **Status**: $REDIS_STATUS

## Common Issues and Solutions

### 1. Connection Refused (ECONNREFUSED)

**Cause**: The database is not publicly accessible or security groups are not configured correctly.

**Solution**: 
- Ensure RDS instance is publicly accessible
- Check security group rules allow access from your IP
- Verify the endpoint is correct

### 2. SSL Connection Issues

**Cause**: PostgreSQL requires SSL connections by default.

**Solution**: 
- Use SSL configuration in connection string
- Set \`ssl: { rejectUnauthorized: false }\` for development

### 3. Authentication Failed

**Cause**: Incorrect username/password or database name.

**Solution**:
- Verify credentials in .env.local
- Check database name exists
- Ensure user has proper permissions

### 4. Timeout Issues

**Cause**: Network latency or firewall blocking connections.

**Solution**:
- Increase connection timeout settings
- Check firewall rules
- Verify network connectivity

## Testing Commands

### Test RDS Connectivity
\`\`\`bash
# Test port connectivity
nc -z $DB_ENDPOINT 5432

# Test with psql (if installed)
psql -h $DB_ENDPOINT -U postgres -d aws-management_dev -c "SELECT 1;"
\`\`\`

### Test Redis Connectivity
\`\`\`bash
# Test port connectivity
nc -z $REDIS_ENDPOINT $REDIS_PORT

# Test with redis-cli (if installed)
redis-cli -h $REDIS_ENDPOINT -p $REDIS_PORT ping
\`\`\`

### Test with Node.js
\`\`\`bash
# Run the enhanced test script
node test-connectivity-enhanced.js
\`\`\`

## Security Considerations

⚠️ **Important**: The current configuration allows access from anywhere (0.0.0.0/0). For production:

1. Restrict security groups to specific IP ranges
2. Use VPC peering or VPN for secure access
3. Enable encryption at rest and in transit
4. Use IAM database authentication
5. Implement proper network segmentation

## Next Steps

1. Run \`node test-connectivity-enhanced.js\` to test connections
2. If connections fail, check the troubleshooting steps above
3. For production deployment, implement proper security measures
4. Consider using AWS Secrets Manager for credential management
EOF

print_success "Created troubleshooting guide: DATABASE_TROUBLESHOOTING.md"

echo ""
echo "🎉 Database connectivity fixes completed!"
echo ""
echo "📋 Next steps:"
echo "1. Run: node test-connectivity-enhanced.js"
echo "2. Check: DATABASE_TROUBLESHOOTING.md for detailed troubleshooting"
echo "3. If still having issues, the databases may need to be accessed from within AWS"
echo ""
echo "⚠️  Note: For production, consider using AWS Secrets Manager and proper network security" 