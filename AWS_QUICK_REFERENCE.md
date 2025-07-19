# AWS Infrastructure Quick Reference

## 🚀 Quick Start Commands

### Complete Infrastructure Setup
```bash
cd aws/resources/master
./setup-all-infrastructure.sh
```

### Setup Cognito Authentication Only
```bash
cd aws/resources/cognito
./setup-aws-cognito.sh
```

### Start Database Access (SSH Tunnels)
```bash
cd aws/resources/bastion
./tunnel-to-databases.sh
```

### Test Connections
```bash
node aws/test/test-local-connections.js
```

### Cleanup Infrastructure
```bash
cd aws/resources/master
./cleanup-aws-resources.sh
```

## 📁 Directory Structure

```
aws/
├── README.md                           # Complete documentation
├── resources/                          # Infrastructure setup scripts
│   ├── master/                         # Master orchestration scripts
│   │   ├── setup-all-infrastructure.sh # 🎯 Complete infrastructure setup
│   │   ├── setup-aws-database.sh       # Database infrastructure setup
│   │   ├── cleanup-aws-resources.sh    # Infrastructure cleanup
│   │   └── ...                         # Other master scripts
│   ├── cognito/                        # AWS Cognito authentication scripts
│   │   ├── setup-aws-cognito.sh        # Manual Cognito setup
│   │   └── setup-aws-cognito-auto.sh   # Automated Cognito setup
│   ├── auth/                           # Authentication management scripts
│   │   ├── check-and-create-users.sh   # User creation and management
│   │   └── fix-users.sh                # User password fixes
│   ├── database/                       # Database-specific scripts
│   │   ├── setup-database.sql          # Database schema
│   │   ├── setup-database-clean.sql    # Clean schema for Node.js
│   │   └── setup-database-tunnel.js    # Database setup through tunnel
│   ├── redis/                          # Redis-specific scripts
│   │   └── fix-redis-access.sh         # Redis security group fixes
│   └── bastion/                        # Jump box (bastion host) scripts
│       ├── setup-jump-box.sh           # Jump box provisioning
│       └── tunnel-to-databases.sh      # SSH tunnel management
└── test/                               # Testing scripts
    ├── test-local-connections.js       # 🎯 Main connectivity test
    ├── test-db-direct.js               # Direct database test
    ├── test-redis-*.js                 # Various Redis tests
    └── ...                             # Other test scripts
```

## 🔧 Key Scripts

### Master Scripts (`aws/resources/master/`)
- **`setup-all-infrastructure.sh`** 🎯 - Complete infrastructure setup (recommended)
- **`setup-aws-database.sh`** - Database infrastructure setup
- **`cleanup-aws-resources.sh`** - Infrastructure cleanup

### Cognito Scripts (`aws/resources/cognito/`)
- **`setup-aws-cognito.sh`** 🎯 - Manual AWS Cognito setup
- **`setup-aws-cognito-auto.sh`** - Automated Cognito setup

### Auth Scripts (`aws/resources/auth/`)
- **`check-and-create-users.sh`** - Creates and manages Cognito users
- **`fix-users.sh`** - Fixes user passwords and authentication issues

### Bastion Scripts (`aws/resources/bastion/`)
- **`setup-jump-box.sh`** - Creates EC2 jump box for SSH tunneling
- **`tunnel-to-databases.sh`** 🎯 - Manages SSH tunnels to databases

### Test Scripts (`aws/test/`)
- **`test-local-connections.js`** 🎯 - Main connectivity test through tunnels

## 🏗️ Infrastructure Components

### Authentication Infrastructure
- **AWS Cognito**: User pool and identity pool for authentication
- **User Management**: Demo and test users with proper permissions
- **Security Policies**: Password policies and MFA configuration

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

## 🌐 Access Information

### Database Endpoints (via SSH tunnel)
- **PostgreSQL**: `localhost:5433`
- **Redis**: `localhost:6380`

### Jump Box Information
- **Public IP**: Available in `JUMP_BOX_INFO.md`
- **SSH Key**: `aws-management-dev-key-*.pem`
- **Access**: SSH tunneling only

## 💰 Cost Estimation

- **RDS PostgreSQL**: ~$15-20/month
- **ElastiCache Redis**: ~$10-15/month
- **EC2 Jump Box**: ~$8-10/month
- **Total**: ~$33-45/month

## 🔒 Security Features

- All database access is restricted to the jump box
- SSH tunnels provide encrypted access
- Security groups are configured for minimal access
- Jump box is accessible only from authorized IPs
- SSH key-based authentication with proper permissions

## 🛠️ Troubleshooting

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

## 📚 Documentation

- **`aws/README.md`** - Complete AWS infrastructure documentation
- **`INFRASTRUCTURE_SUMMARY.md`** - Infrastructure overview
- **`JUMP_BOX_INFO.md`** - Jump box details and usage
- **`DATABASE_SETUP_SUMMARY.md`** - Database setup documentation

## 🎯 Recommended Workflow

1. **Initial Setup**: Run `aws/resources/master/setup-all-infrastructure.sh`
2. **Daily Development**: 
   - Start tunnels: `aws/resources/bastion/tunnel-to-databases.sh`
   - Test connections: `node aws/test/test-local-connections.js`
3. **Cleanup**: Run `aws/resources/master/cleanup-aws-resources.sh` when done

## ⚠️ Important Notes

- **Cost Management**: Terminate jump box when not in use
- **Security**: Always use SSH tunnels, never expose databases directly
- **Monitoring**: Regularly check AWS costs and resource usage
- **Testing**: Run connectivity tests after any changes 