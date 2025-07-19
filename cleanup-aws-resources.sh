#!/bin/bash

# Cleanup script for AWS resources
# WARNING: This will delete all created resources!

set -e

echo "🧹 Cleaning up AWS resources..."

# Delete Redis cluster
echo "Deleting Redis cluster: aws-management-dev-redis-1752944212"
aws elasticache delete-cache-cluster --cache-cluster-id "aws-management-dev-redis-1752944212" --final-snapshot-identifier "aws-management-dev-redis-1752944212-final-snapshot" || true

# Delete RDS instance
echo "Deleting RDS instance: aws-management-dev-db-1752944212"
aws rds delete-db-instance --db-instance-identifier "aws-management-dev-db-1752944212" --skip-final-snapshot || true

# Delete security groups
echo "Deleting security groups..."
aws ec2 delete-security-group --group-id "sg-0413dfcd792a38454" || true
aws ec2 delete-security-group --group-id "sg-08b0594cd09923e85" || true

# Delete subnet groups
echo "Deleting subnet groups..."
aws rds delete-db-subnet-group --db-subnet-group-name "aws-management-dev-subnet-group-1752944212" || true
aws elasticache delete-cache-subnet-group --cache-subnet-group-name "aws-management-dev-redis-subnet-1752944212" || true

echo "✅ Cleanup completed!"
echo "Note: Some resources may take a few minutes to be fully deleted."
