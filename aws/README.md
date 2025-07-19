# AWS Infrastructure Scripts

This directory contains all AWS infrastructure setup, management, and testing scripts organized by resource type.

## Directory Structure

```
aws/
├── README.md                           # This file
├── resources/                          # Infrastructure setup scripts
│   ├── master/                         # Master orchestration scripts
│   │   ├── setup-all-infrastructure.sh # Complete infrastructure setup
│   │   ├── setup-aws-database.sh       # Database infrastructure setup
│   │   ├── setup-aws-database-simple.sh # Simplified database setup
│   │   ├── fix-database-connectivity.sh # Database connectivity fixes
│   │   ├── check-public-endpoints.sh   # Endpoint analysis
│   │   └── cleanup-aws-resources.sh    # Infrastructure cleanup
│   ├── database/                       # Database-specific scripts
│   │   ├── setup-database.sql          # Database schema (psql format)
│   │   ├── setup-database-clean.sql    # Database schema (Node.js format)
│   │   └── setup-database-tunnel.js    # Database setup through tunnel
│   ├── redis/                          # Redis-specific scripts
│   │   └── fix-redis-access.sh         # Redis security group fixes
│   └── bastion/                        # Jump box (bastion host) scripts
│       ├── setup-jump-box.sh           # Jump box provisioning
│       └── tunnel-to-databases.sh      # SSH tunnel management
└── test/                               # Testing scripts
    ├── test-local-connections.js       # Main connectivity test
    ├── test-db-direct.js               # Direct database test
    ├── test-redis-url.js               # Redis URL format test
    ├── test-redis-simple.js            # Simple Redis test
    ├── test-redis-debug.js             # Redis debug test
    ├── test-redis-no-env.js            # Redis test without env vars
    ├── test-connections.js             # Basic connectivity test
    └── test-connectivity-enhanced.js   # Enhanced connectivity test
```

## Quick Start

### Complete Infrastructure Setup
```bash
cd aws/resources/master
./setup-all-infrastructure.sh
```

### Start Database Access (SSH Tunnels)
```bash
cd aws/resources/bastion
./tunnel-to-databases.sh
```

### Test Connections
```bash
cd aws/test
node test-local-connections.js
```

### Cleanup Infrastructure
```bash
cd aws/resources/master
./cleanup-aws-resources.sh
```

## Resource Types

### Master Scripts (`resources/master/`)
- **setup-all-infrastructure.sh**: Orchestrates complete infrastructure setup
- **setup-aws-database.sh**: Creates RDS PostgreSQL and ElastiCache Redis
- **cleanup-aws-resources.sh**: Removes all AWS resources

### Database Scripts (`resources/database/`)
- **setup-database.sql**: Complete database schema with tables, indexes, triggers
- **setup-database-clean.sql**: Clean schema without psql-specific commands
- **setup-database-tunnel.js**: Sets up database schema through SSH tunnel

### Redis Scripts (`resources/redis/`)
- **fix-redis-access.sh**: Configures Redis security groups for jump box access

### Bastion Scripts (`resources/bastion/`)
- **setup-jump-box.sh**: Creates EC2 jump box for SSH tunneling
- **tunnel-to-databases.sh**: Manages SSH tunnels to databases

### Test Scripts (`test/`)
- **test-local-connections.js**: Main connectivity test through tunnels
- **test-db-direct.js**: Direct database connection test
- **test-redis-*.js**: Various Redis connection tests

## Infrastructure Components

### Database Infrastructure
- **PostgreSQL RDS**: Managed PostgreSQL database
- **Redis ElastiCache**: Managed Redis caching layer
- **Security Groups**: Properly configured for secure access

### Jump Box (Bastion Host)
- **EC2 Instance**: t3.micro instance for SSH tunneling
- **Security Groups**: Restricted access to current IP only
- **SSH Tunnels**: Secure access to private databases

### Network Configuration
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

## Security Features

- All database access is restricted to the jump box
- SSH tunnels provide encrypted access
- Security groups are configured for minimal access
- Jump box is accessible only from authorized IPs
- SSH key-based authentication with proper permissions

## Cost Estimation

- **RDS PostgreSQL**: ~$15-20/month
- **ElastiCache Redis**: ~$10-15/month
- **EC2 Jump Box**: ~$8-10/month
- **Total**: ~$33-45/month

## Maintenance

- Monitor AWS costs regularly
- Terminate jump box when not in use
- Keep security groups updated
- Regularly test connectivity
- Update scripts as AWS services evolve

## Troubleshooting

### Common Issues
1. **SSH tunnel not working**: Check jump box is running and accessible
2. **Database connection failed**: Verify SSH tunnels are active
3. **Redis connection failed**: Check Redis security group configuration
4. **Permission denied**: Ensure SSH key has correct permissions (400)

### Debug Steps
1. Check jump box status: `aws ec2 describe-instances`
2. Test SSH connection: `ssh -i key.pem ec2-user@ip`
3. Verify tunnels: `ps aux | grep ssh`
4. Test ports: `nc -z localhost 5433` and `nc -z localhost 6380`

## Best Practices

1. **Security**: Always use SSH tunnels, never expose databases directly
2. **Cost Management**: Terminate jump box when not in use
3. **Monitoring**: Regularly check AWS costs and resource usage
4. **Documentation**: Keep infrastructure documentation updated
5. **Testing**: Run connectivity tests after any changes
6. **Backup**: Regularly backup database schemas and configurations 