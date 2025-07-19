#!/bin/bash

# Cleanup script for AWS resources
# WARNING: This will delete all created resources!

set -e

echo "🧹 Cleaning up AWS resources..."

# Delete Redis cluster
echo "Deleting Redis cluster: aws-management-dev-redis-1752950390-test"
aws elasticache delete-cache-cluster --cache-cluster-id "aws-management-dev-redis-1752950390-test" --final-snapshot-identifier "aws-management-dev-redis-1752950390-test-final-snapshot" || true

# Delete RDS instance
echo "Deleting RDS instance: aws-management-dev-db-1752950390-test"
aws rds delete-db-instance --db-instance-identifier "aws-management-dev-db-1752950390-test" --skip-final-snapshot || true

# Delete security groups
echo "Deleting security groups..."
aws ec2 delete-security-group --group-id "sg-0d3e4cf78c2f753fc" || true
aws ec2 delete-security-group --group-id "sg-092b08d6e1b309424" || true

# Delete subnet groups
echo "Deleting subnet groups..."
aws rds delete-db-subnet-group --db-subnet-group-name "aws-management-dev-subnet-group-1752950390-test" || true
aws elasticache delete-cache-subnet-group --cache-subnet-group-name "aws-management-dev-redis-subnet-1752950390-test" || true

echo "✅ Cleanup completed!"
echo "Note: Some resources may take a few minutes to be fully deleted."
