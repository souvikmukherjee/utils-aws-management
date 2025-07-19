#!/bin/bash

# Setup Jump Box Script
# This script creates an EC2 instance to act as a jump box for database access

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
    print_status "Running jump box setup in TEST MODE with suffix: $RESOURCE_SUFFIX"
else
    RESOURCE_SUFFIX=""
    print_status "Running jump box setup in PRODUCTION MODE"
fi

# Configuration
PROJECT_NAME="aws-management"
ENVIRONMENT="dev"
TIMESTAMP=$(date +%s)
JUMP_BOX_NAME="${PROJECT_NAME}-${ENVIRONMENT}-jump-box-${TIMESTAMP}${RESOURCE_SUFFIX}"
KEY_PAIR_NAME="${PROJECT_NAME}-${ENVIRONMENT}-key-${TIMESTAMP}${RESOURCE_SUFFIX}"
SECURITY_GROUP_NAME="${PROJECT_NAME}-${ENVIRONMENT}-jump-sg-${TIMESTAMP}${RESOURCE_SUFFIX}"

# Get existing VPC and subnet information
print_status "Getting existing VPC and subnet information..."

# Get VPC ID from RDS instance (find the most recent one with our pattern)
# Convert underscore to hyphen for AWS resources
RESOURCE_PATTERN="${RESOURCE_SUFFIX//_/-}"
DB_INSTANCE_IDENTIFIER=$(aws rds describe-db-instances --query "DBInstances[?contains(DBInstanceIdentifier, 'aws-management-dev-db') && contains(DBInstanceIdentifier, '$RESOURCE_PATTERN')].DBInstanceIdentifier" --output text | tr '\t' '\n' | head -1)

if [ -z "$DB_INSTANCE_IDENTIFIER" ]; then
    print_error "No RDS instance found with pattern 'aws-management-dev-db*$RESOURCE_PATTERN'"
    exit 1
fi

print_status "Using RDS instance: $DB_INSTANCE_IDENTIFIER"

VPC_ID=$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" --query 'DBInstances[0].DBSubnetGroup.VpcId' --output text)
SUBNET_GROUP_NAME=$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" --query 'DBInstances[0].DBSubnetGroup.DBSubnetGroupName' --output text)

print_success "VPC ID: $VPC_ID"
print_success "Subnet Group: $SUBNET_GROUP_NAME"

# Get subnet IDs
SUBNET_IDS=$(aws rds describe-db-subnet-groups --db-subnet-group-name "$SUBNET_GROUP_NAME" --query 'DBSubnetGroups[0].Subnets[*].SubnetId' --output text)
SUBNET_ID=$(echo $SUBNET_IDS | cut -d' ' -f1)  # Use first subnet

print_success "Using Subnet ID: $SUBNET_ID"

# Create key pair
print_status "Creating key pair for jump box..."
aws ec2 create-key-pair --key-name "$KEY_PAIR_NAME" --query 'KeyMaterial' --output text > "${KEY_PAIR_NAME}.pem"
chmod 400 "${KEY_PAIR_NAME}.pem"

print_success "Key pair created: ${KEY_PAIR_NAME}.pem"

# Create security group for jump box
print_status "Creating security group for jump box..."
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name "$SECURITY_GROUP_NAME" \
    --description "Security group for jump box access" \
    --vpc-id "$VPC_ID" \
    --query 'GroupId' --output text)

print_success "Security group created: $SECURITY_GROUP_ID"

# Get current public IP
CURRENT_IP=$(curl -s https://checkip.amazonaws.com/ 2>/dev/null || echo "0.0.0.0/0")
print_status "Current public IP: $CURRENT_IP"

# Add SSH access rule
print_status "Adding SSH access rule..."
aws ec2 authorize-security-group-ingress \
    --group-id "$SECURITY_GROUP_ID" \
    --protocol tcp \
    --port 22 \
    --cidr "${CURRENT_IP}/32" \
    > /dev/null

print_success "SSH access rule added for IP: ${CURRENT_IP}/32"

# Add rule for database access from jump box
print_status "Adding database access rules..."
aws ec2 authorize-security-group-ingress \
    --group-id "$SECURITY_GROUP_ID" \
    --protocol tcp \
    --port 5432 \
    --source-group "$SECURITY_GROUP_ID" \
    > /dev/null

aws ec2 authorize-security-group-ingress \
    --group-id "$SECURITY_GROUP_ID" \
    --protocol tcp \
    --port 6379 \
    --source-group "$SECURITY_GROUP_ID" \
    > /dev/null

print_success "Database access rules added"

# Get the latest Amazon Linux 2 AMI
print_status "Getting latest Amazon Linux 2 AMI..."
AMI_ID=$(aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" "Name=state,Values=available" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text)

print_success "Using AMI: $AMI_ID"

# Create user data script for jump box
print_status "Creating user data script..."
cat > jump-box-user-data.sh << 'EOF'
#!/bin/bash
yum update -y
yum install -y postgresql15 redis

# Install Node.js
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# Install additional tools
yum install -y git htop nc

# Create directory for scripts
mkdir -p /home/ec2-user/scripts
chown ec2-user:ec2-user /home/ec2-user/scripts

# Create test script
cat > /home/ec2-user/scripts/test-databases.js << 'SCRIPT_EOF'
const { Client } = require('pg');
const Redis = require('redis');

// Load environment variables
require('dotenv').config();

async function testPostgreSQL() {
    console.log('Testing PostgreSQL connection from jump box...');
    
    const client = new Client({
        host: process.env.DB_HOST,
        port: process.env.DB_PORT,
        database: process.env.DB_NAME,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        ssl: {
            rejectUnauthorized: false
        }
    });
    
    try {
        await client.connect();
        console.log('✅ PostgreSQL connection successful from jump box');
        
        const result = await client.query('SELECT NOW() as current_time, version() as version');
        console.log('Current database time:', result.rows[0].current_time);
        console.log('PostgreSQL version:', result.rows[0].version.split(' ')[0]);
        
        await client.end();
    } catch (error) {
        console.error('❌ PostgreSQL connection failed:', error.message);
    }
}

async function testRedis() {
    console.log('Testing Redis connection from jump box...');
    
    const client = Redis.createClient({
        url: process.env.REDIS_URL
    });
    
    try {
        await client.connect();
        console.log('✅ Redis connection successful from jump box');
        
        await client.set('test_key', 'Hello Redis from jump box!');
        const value = await client.get('test_key');
        console.log('Test value from Redis:', value);
        
        await client.quit();
    } catch (error) {
        console.error('❌ Redis connection failed:', error.message);
    }
}

async function runTests() {
    console.log('🔍 Testing database connections from jump box...\n');
    
    await testPostgreSQL();
    console.log('');
    await testRedis();
    
    console.log('\n🎉 Connection tests completed from jump box!');
}

runTests().catch(console.error);
SCRIPT_EOF

# Install npm packages
cd /home/ec2-user/scripts
npm init -y
npm install pg redis dotenv

chown -R ec2-user:ec2-user /home/ec2-user/scripts

echo "Jump box setup completed!"
EOF

# Launch EC2 instance
print_status "Launching EC2 jump box instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --count 1 \
    --instance-type t3.micro \
    --key-name "$KEY_PAIR_NAME" \
    --security-group-ids "$SECURITY_GROUP_ID" \
    --subnet-id "$SUBNET_ID" \
    --user-data file://jump-box-user-data.sh \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$JUMP_BOX_NAME},{Key=Project,Value=$PROJECT_NAME},{Key=Environment,Value=$ENVIRONMENT}]" \
    --query 'Instances[0].InstanceId' --output text)

print_success "EC2 instance launched: $INSTANCE_ID"

# Wait for instance to be running
print_status "Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

# Get public IP address
print_status "Getting public IP address..."
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

print_success "Jump box public IP: $PUBLIC_IP"

# Wait for user data script to complete
print_status "Waiting for user data script to complete (this may take a few minutes)..."
sleep 60

# Create SSH tunnel script
print_status "Creating SSH tunnel script..."
cat > tunnel-to-databases.sh << EOF
#!/bin/bash

# SSH Tunnel Script
# This script creates SSH tunnels to access the databases through the jump box

set -e

# Configuration
JUMP_BOX_IP="$PUBLIC_IP"
KEY_FILE="${KEY_PAIR_NAME}.pem"
LOCAL_POSTGRES_PORT=5433
LOCAL_REDIS_PORT=6380

echo "🔗 Setting up SSH tunnels to databases through jump box..."
echo "Jump Box IP: $JUMP_BOX_IP"
echo ""

# Function to cleanup tunnels
cleanup() {
    echo ""
    echo "🧹 Cleaning up SSH tunnels..."
    pkill -f "ssh.*$JUMP_BOX_IP" || true
    echo "Tunnels cleaned up"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

echo "📡 Creating PostgreSQL tunnel (localhost:$LOCAL_POSTGRES_PORT -> jump box -> RDS:5432)..."
ssh -i "$KEY_FILE" -L $LOCAL_POSTGRES_PORT:aws-management-dev-db-1752944212.c7y6uccm606w.ap-southeast-2.rds.amazonaws.com:5432 -N ec2-user@$JUMP_BOX_IP &
POSTGRES_TUNNEL_PID=\$!

echo "📡 Creating Redis tunnel (localhost:$LOCAL_REDIS_PORT -> jump box -> Redis:6379)..."
ssh -i "$KEY_FILE" -L $LOCAL_REDIS_PORT:aws-management-dev-redis-1752944212.zrxyak.0001.apse2.cache.amazonaws.com:6379 -N ec2-user@$JUMP_BOX_IP &
REDIS_TUNNEL_PID=\$!

echo ""
echo "✅ SSH tunnels established!"
echo "PostgreSQL: localhost:$LOCAL_POSTGRES_PORT"
echo "Redis: localhost:$LOCAL_REDIS_PORT"
echo ""
echo "🔧 Update your .env.local file with these local endpoints:"
echo "DB_HOST=localhost"
echo "DB_PORT=$LOCAL_POSTGRES_PORT"
echo "REDIS_HOST=localhost"
echo "REDIS_PORT=$LOCAL_REDIS_PORT"
echo ""
echo "📝 To test connections, run: node test-connections.js"
echo "🛑 Press Ctrl+C to close tunnels"
echo ""

# Wait for user to stop
wait
EOF

chmod +x tunnel-to-databases.sh

# Create local test script
print_status "Creating local test script..."
cat > test-local-connections.js << 'EOF'
const { Client } = require('pg');
const Redis = require('redis');

// Load environment variables
require('dotenv').config({ path: '.env.local' });

// Test PostgreSQL connection through tunnel
async function testPostgreSQL() {
    console.log('Testing PostgreSQL connection through SSH tunnel...');
    
    const client = new Client({
        host: 'localhost',
        port: 5433, // Local tunnel port
        database: process.env.DB_NAME,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        ssl: {
            rejectUnauthorized: false
        },
        connectionTimeoutMillis: 10000
    });
    
    try {
        await client.connect();
        console.log('✅ PostgreSQL connection successful through tunnel');
        
        const result = await client.query('SELECT NOW() as current_time, version() as version');
        console.log('Current database time:', result.rows[0].current_time);
        console.log('PostgreSQL version:', result.rows[0].version.split(' ')[0]);
        
        await client.end();
    } catch (error) {
        console.error('❌ PostgreSQL connection failed:', error.message);
    }
}

// Test Redis connection through tunnel
async function testRedis() {
    console.log('Testing Redis connection through SSH tunnel...');
    
    const client = Redis.createClient({
        host: 'localhost',
        port: 6380, // Local tunnel port
        socket: {
            connectTimeout: 10000
        }
    });
    
    try {
        await client.connect();
        console.log('✅ Redis connection successful through tunnel');
        
        await client.set('test_key', 'Hello Redis through tunnel!');
        const value = await client.get('test_key');
        console.log('Test value from Redis:', value);
        
        await client.quit();
    } catch (error) {
        console.error('❌ Redis connection failed:', error.message);
    }
}

// Run tests
async function runTests() {
    console.log('🔍 Testing database connections through SSH tunnel...\n');
    
    await testPostgreSQL();
    console.log('');
    await testRedis();
    
    console.log('\n🎉 Tunnel connection tests completed!');
}

runTests().catch(console.error);
EOF

# Create jump box info file
print_status "Creating jump box information file..."
cat > JUMP_BOX_INFO.md << EOF
# Jump Box Information

## Instance Details
- **Instance ID**: $INSTANCE_ID
- **Name**: $JUMP_BOX_NAME
- **Public IP**: $PUBLIC_IP
- **Key Pair**: $KEY_PAIR_NAME
- **Security Group**: $SECURITY_GROUP_ID
- **VPC**: $VPC_ID
- **Subnet**: $SUBNET_ID

## SSH Access
\`\`\`bash
ssh -i ${KEY_PAIR_NAME}.pem ec2-user@$PUBLIC_IP
\`\`\`

## Database Tunnels
\`\`\`bash
# PostgreSQL tunnel
ssh -i ${KEY_PAIR_NAME}.pem -L 5433:aws-management-dev-db-1752944212.c7y6uccm606w.ap-southeast-2.rds.amazonaws.com:5432 -N ec2-user@$PUBLIC_IP

# Redis tunnel
ssh -i ${KEY_PAIR_NAME}.pem -L 6380:aws-management-dev-redis-1752944212.zrxyak.0001.apse2.cache.amazonaws.com:6379 -N ec2-user@$PUBLIC_IP
\`\`\`

## Quick Start
1. Run: \`./tunnel-to-databases.sh\`
2. Update .env.local with local endpoints:
   - DB_HOST=localhost
   - DB_PORT=5433
   - REDIS_HOST=localhost
   - REDIS_PORT=6380
3. Test: \`node test-local-connections.js\`

## Security Notes
- Jump box is accessible only from your current IP: $CURRENT_IP
- Key file permissions are set to 400 (read-only for owner)
- Security group allows only SSH access from your IP
- Database access is restricted to the jump box security group

## Cost Estimation
- t3.micro instance: ~$8-10/month
- Data transfer: Minimal for development use
- Storage: 8GB gp2 included in free tier

## Cleanup
To remove the jump box:
\`\`\`bash
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
aws ec2 delete-key-pair --key-name $KEY_PAIR_NAME
aws ec2 delete-security-group --group-id $SECURITY_GROUP_ID
rm ${KEY_PAIR_NAME}.pem
\`\`\`
EOF

# Update .env.local with tunnel endpoints
print_status "Creating .env.local.tunnel with tunnel endpoints..."
if [ -f .env.local ]; then
    cp .env.local .env.local.tunnel
    sed -i '' 's|DB_HOST=.*|DB_HOST=localhost|g' .env.local.tunnel
    sed -i '' 's|DB_PORT=.*|DB_PORT=5433|g' .env.local.tunnel
    sed -i '' 's|REDIS_HOST=.*|REDIS_HOST=localhost|g' .env.local.tunnel
    sed -i '' 's|REDIS_PORT=.*|REDIS_PORT=6380|g' .env.local.tunnel
    sed -i '' 's|DATABASE_URL=.*|DATABASE_URL=postgresql://postgres:${DB_PASSWORD}@localhost:5433/${DB_NAME}|g' .env.local.tunnel
    sed -i '' 's|REDIS_URL=.*|REDIS_URL=redis://localhost:6380|g' .env.local.tunnel
    
    print_success "Created .env.local.tunnel with tunnel endpoints"
fi

# Cleanup temporary files
rm -f jump-box-user-data.sh

print_success "Jump box setup completed!"
echo ""
echo "🎉 Jump box is ready!"
echo ""
echo "📋 Next steps:"
echo "1. Run: ./tunnel-to-databases.sh"
echo "2. In another terminal, test: node test-local-connections.js"
echo "3. Use .env.local.tunnel for tunnel configuration"
echo ""
echo "📖 Check JUMP_BOX_INFO.md for detailed information"
echo ""
echo "⚠️  Remember to terminate the jump box when not in use to save costs" 