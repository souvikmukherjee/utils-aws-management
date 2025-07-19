# AWS Infrastructure Test Framework

## Overview

This directory contains a comprehensive test framework for validating the complete AWS infrastructure setup. The test framework creates all AWS resources with a `_test` suffix, verifies connectivity and functionality, then cleans up all resources.

## 🧪 Test Infrastructure Script

### `test-infrastructure.sh`

**Purpose**: End-to-end testing of the complete AWS infrastructure setup

**What it does**:
1. ✅ **Prerequisites Check**: Validates AWS CLI, Node.js, npm, and credentials
2. ✅ **Test Environment Setup**: Creates `.env.test` with test configuration
3. ✅ **Master Script Execution**: Runs the complete infrastructure setup with test parameters
4. ✅ **Resource Availability Wait**: Waits for all AWS resources to be ready
5. ✅ **Connectivity Tests**: Tests PostgreSQL and Redis connections
6. ✅ **Application Integration**: Tests database schema and CRUD operations
7. ✅ **Cognito Functionality**: Tests user creation and authentication
8. ✅ **Resource Cleanup**: Deletes all test resources

## 🚀 Usage

### Run Complete Test

```bash
# From project root
./aws/resources/master/test-infrastructure.sh
```

### Test Mode Parameters

The test script uses these environment variables:

```bash
export INFRASTRUCTURE_TEST_MODE=true
export TEST_SUFFIX="_test"  # Default suffix for test resources
```

### Test Resource Naming

All test resources are created with the `_test` suffix:

- **RDS Instance**: `aws-management-dev-db-{timestamp}_test`
- **Redis Cluster**: `aws-management-dev-redis-{timestamp}_test`
- **EC2 Jump Box**: `aws-management-dev-jump-box-{timestamp}_test`
- **Security Groups**: `aws-management-dev-sg-{timestamp}_test`
- **Cognito User Pool**: `aws-management-utilities-user-pool_test`
- **Cognito App Client**: `aws-management-utilities-web-app_test`

## 📋 Test Phases

### Phase 1: Prerequisites Check
- ✅ AWS CLI installation
- ✅ AWS credentials configuration
- ✅ Node.js installation
- ✅ npm installation
- ✅ Node.js dependencies

### Phase 2: Test Environment Setup
- ✅ Creates `.env.test` with test configuration
- ✅ Sets up test database credentials
- ✅ Configures test Redis settings
- ✅ Sets up test Cognito parameters

### Phase 3: Infrastructure Creation
- ✅ Runs master infrastructure script in test mode
- ✅ Creates all AWS resources with `_test` suffix
- ✅ Sets up VPC, subnets, security groups
- ✅ Creates RDS PostgreSQL instance
- ✅ Creates Redis ElastiCache cluster
- ✅ Creates EC2 jump box (bastion host)
- ✅ Sets up Cognito user pool and app client

### Phase 4: Resource Validation
- ✅ Waits for RDS instance to be available
- ✅ Waits for Redis cluster to be available
- ✅ Waits for EC2 instance to be running
- ✅ Establishes SSH tunnels to databases

### Phase 5: Connectivity Testing
- ✅ Tests PostgreSQL connection via SSH tunnel
- ✅ Tests Redis connection via SSH tunnel
- ✅ Validates database schema setup
- ✅ Tests CRUD operations
- ✅ Tests Cognito user creation

### Phase 6: Cleanup
- ✅ Deletes all test resources
- ✅ Removes test environment file
- ✅ Generates test report

## 📊 Test Report

After completion, the script generates `TEST_INFRASTRUCTURE_REPORT.md` with:

- **Test Summary**: Date, duration, and status
- **Test Components**: List of all tested components
- **Test Results**: Detailed results for each phase
- **Recommendations**: Based on test outcomes
- **Next Steps**: Actions to take after testing

## 🔧 Configuration

### Test Environment Variables

The test script creates `.env.test` with:

```env
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
```

### Test Resource Configuration

- **RDS Instance Type**: `db.t3.micro`
- **Redis Node Type**: `cache.t3.micro`
- **EC2 Instance Type**: `t3.micro`
- **Database Password**: `test_password_123`
- **Region**: `ap-southeast-2`

## 🛡️ Safety Features

### Resource Isolation
- All test resources use `_test` suffix
- No interference with production resources
- Automatic cleanup after testing

### Error Handling
- Script exits on first error (`set -e`)
- Comprehensive error messages
- Graceful cleanup on failure

### Cost Control
- Uses smallest instance types
- Automatic resource deletion
- No persistent storage

## 📝 Test Output

### Success Example
```
[INFO] Starting comprehensive AWS infrastructure test...

[INFO] Checking prerequisites...
[SUCCESS] All prerequisites are satisfied

[INFO] Setting up test environment variables...
[SUCCESS] Test environment variables created

[INFO] Running master infrastructure script with test parameters...
[SUCCESS] Master infrastructure script completed

[INFO] Waiting for AWS resources to be ready...
[SUCCESS] All AWS resources are ready

[INFO] Testing database connectivity...
[SUCCESS] All connectivity tests passed

[INFO] Testing application integration...
[SUCCESS] All application integration tests passed

[INFO] Testing Cognito functionality...
[SUCCESS] All Cognito functionality tests passed

[INFO] Cleaning up test resources...
[SUCCESS] Test resources cleaned up

🎉 All tests passed! Infrastructure is ready for production.
```

### Failure Example
```
[ERROR] Phase failed: test_database_connectivity
[ERROR] PostgreSQL connectivity test failed

❌ Some tests failed. Please review the report and fix issues.
```

## 🔄 Manual Testing

### Test Individual Components

```bash
# Test database setup only
cd aws/resources/master
INFRASTRUCTURE_TEST_MODE=true TEST_SUFFIX="_test" ./setup-aws-database.sh

# Test jump box setup only
cd aws/resources/bastion
INFRASTRUCTURE_TEST_MODE=true TEST_SUFFIX="_test" ./setup-jump-box.sh

# Test Cognito setup only
cd aws/resources/cognito
INFRASTRUCTURE_TEST_MODE=true TEST_SUFFIX="_test" ./setup-aws-cognito.sh
```

### Manual Cleanup

```bash
# Clean up test resources manually
cd aws/resources/master
INFRASTRUCTURE_TEST_MODE=true TEST_SUFFIX="_test" ./cleanup-aws-resources.sh
```

## 🚨 Troubleshooting

### Common Issues

1. **AWS Credentials Not Configured**
   ```bash
   aws configure
   ```

2. **Node.js Dependencies Missing**
   ```bash
   npm install
   ```

3. **Resource Creation Fails**
   - Check AWS service limits
   - Verify VPC and subnet availability
   - Ensure sufficient IAM permissions

4. **Connectivity Tests Fail**
   - Wait longer for resources to be ready
   - Check security group rules
   - Verify SSH tunnel establishment

### Debug Mode

Add debug output to any script:

```bash
set -x  # Enable debug mode
./test-infrastructure.sh
set +x  # Disable debug mode
```

## 📈 Continuous Integration

### GitHub Actions Example

```yaml
name: Test AWS Infrastructure
on: [push, pull_request]

jobs:
  test-infrastructure:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-southeast-2
      - name: Install dependencies
        run: npm install
      - name: Run infrastructure tests
        run: ./aws/resources/master/test-infrastructure.sh
```

## 🎯 Best Practices

1. **Run Tests Regularly**: Test infrastructure changes before production
2. **Monitor Costs**: Test resources are automatically cleaned up
3. **Review Reports**: Always check test reports for issues
4. **Update Tests**: Keep tests in sync with infrastructure changes
5. **Use CI/CD**: Integrate tests into your deployment pipeline

## 📞 Support

For issues with the test framework:

1. Check the test report for specific error details
2. Review AWS CloudWatch logs for resource creation issues
3. Verify AWS service limits and quotas
4. Ensure proper IAM permissions for all AWS services

---

**Note**: This test framework ensures your AWS infrastructure is reliable and ready for production use. Always run tests before deploying to production environments. 