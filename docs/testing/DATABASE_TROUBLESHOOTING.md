# Database Connectivity Troubleshooting Guide

## Current Configuration

### PostgreSQL RDS
- **Instance ID**: aws-management-dev-db-1752944212
- **Endpoint**: aws-management-dev-db-1752944212.c7y6uccm606w.ap-southeast-2.rds.amazonaws.com
- **Publicly Accessible**: False
- **Status**: available

### Redis ElastiCache
- **Cluster ID**: aws-management-dev-redis-1752944212
- **Endpoint**: aws-management-dev-redis-1752944212.zrxyak.0001.apse2.cache.amazonaws.com:6379
- **Status**: available

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
- Set `ssl: { rejectUnauthorized: false }` for development

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
```bash
# Test port connectivity
nc -z aws-management-dev-db-1752944212.c7y6uccm606w.ap-southeast-2.rds.amazonaws.com 5432

# Test with psql (if installed)
psql -h aws-management-dev-db-1752944212.c7y6uccm606w.ap-southeast-2.rds.amazonaws.com -U postgres -d aws-management_dev -c "SELECT 1;"
```

### Test Redis Connectivity
```bash
# Test port connectivity
nc -z aws-management-dev-redis-1752944212.zrxyak.0001.apse2.cache.amazonaws.com 6379

# Test with redis-cli (if installed)
redis-cli -h aws-management-dev-redis-1752944212.zrxyak.0001.apse2.cache.amazonaws.com -p 6379 ping
```

### Test with Node.js
```bash
# Run the enhanced test script
node test-connectivity-enhanced.js
```

## Security Considerations

⚠️ **Important**: The current configuration allows access from anywhere (0.0.0.0/0). For production:

1. Restrict security groups to specific IP ranges
2. Use VPC peering or VPN for secure access
3. Enable encryption at rest and in transit
4. Use IAM database authentication
5. Implement proper network segmentation

## Next Steps

1. Run `node test-connectivity-enhanced.js` to test connections
2. If connections fail, check the troubleshooting steps above
3. For production deployment, implement proper security measures
4. Consider using AWS Secrets Manager for credential management
