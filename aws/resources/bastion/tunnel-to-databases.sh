#!/bin/bash

# SSH Tunnel Script
# This script creates SSH tunnels to access the databases through the jump box

set -e

# Configuration
JUMP_BOX_IP="16.176.104.97"
KEY_FILE="aws-management-dev-key-1752945390.pem"
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
POSTGRES_TUNNEL_PID=$!

echo "📡 Creating Redis tunnel (localhost:$LOCAL_REDIS_PORT -> jump box -> Redis:6379)..."
ssh -i "$KEY_FILE" -L $LOCAL_REDIS_PORT:aws-management-dev-redis-1752944212.zrxyak.0001.apse2.cache.amazonaws.com:6379 -N ec2-user@$JUMP_BOX_IP &
REDIS_TUNNEL_PID=$!

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
echo "📝 To test connections, run: node aws/test/test-local-connections.js"
echo "🛑 Press Ctrl+C to close tunnels"
echo ""

# Wait for user to stop
wait
