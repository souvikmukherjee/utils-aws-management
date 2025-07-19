# Jump Box Information

## Instance Details
- **Instance ID**: i-0aad59cb1967168ae
- **Name**: aws-management-dev-jump-box-1752952389
- **Public IP**: 13.211.165.169
- **Key Pair**: aws-management-dev-key-1752952389
- **Security Group**: sg-0dd0e835d0e0c9778
- **VPC**: vpc-0fa493c68b834d38c
- **Subnet**: 

## SSH Access
```bash
ssh -i aws-management-dev-key-1752952389.pem ec2-user@13.211.165.169
```

## Database Tunnels
```bash
# PostgreSQL tunnel
ssh -i aws-management-dev-key-1752952389.pem -L 5433:aws-management-dev-db-1752944212.c7y6uccm606w.ap-southeast-2.rds.amazonaws.com:5432 -N ec2-user@13.211.165.169

# Redis tunnel
ssh -i aws-management-dev-key-1752952389.pem -L 6380:aws-management-dev-redis-1752944212.zrxyak.0001.apse2.cache.amazonaws.com:6379 -N ec2-user@13.211.165.169
```

## Quick Start
1. Run: `./tunnel-to-databases.sh`
2. Update .env.local with local endpoints:
   - DB_HOST=localhost
   - DB_PORT=5433
   - REDIS_HOST=localhost
   - REDIS_PORT=6380
3. Test: `node test-local-connections.js`

## Security Notes
- Jump box is accessible only from your current IP: 110.174.16.173
- Key file permissions are set to 400 (read-only for owner)
- Security group allows only SSH access from your IP
- Database access is restricted to the jump box security group

## Cost Estimation
- t3.micro instance: ~-10/month
- Data transfer: Minimal for development use
- Storage: 8GB gp2 included in free tier

## Cleanup
To remove the jump box:
```bash
aws ec2 terminate-instances --instance-ids i-0aad59cb1967168ae
aws ec2 delete-key-pair --key-name aws-management-dev-key-1752952389
aws ec2 delete-security-group --group-id sg-0dd0e835d0e0c9778
rm aws-management-dev-key-1752952389.pem
```
