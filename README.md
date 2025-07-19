# AWS Management Utilities

> A comprehensive Next.js application for managing AWS resources with secure database connectivity, authentication, and infrastructure automation.

[![Next.js](https://img.shields.io/badge/Next.js-14-black)](https://nextjs.org/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5-blue)](https://www.typescriptlang.org/)
[![AWS](https://img.shields.io/badge/AWS-Infrastructure-orange)](https://aws.amazon.com/)
[![Security](https://img.shields.io/badge/Security-Audited-green)](docs/security/SECURITY_AUDIT_SUMMARY.md)

## 📖 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Documentation](#documentation)
- [Infrastructure](#infrastructure)
- [Development](#development)
- [Security](#security)
- [Contributing](#contributing)

## 🎯 Overview

AWS Management Utilities is a modern web application built with Next.js and TypeScript that provides comprehensive AWS resource management capabilities. The application features secure database connectivity through SSH tunnels, AWS Cognito authentication, and automated infrastructure provisioning.

### Key Capabilities

- **🔐 Secure Authentication**: AWS Cognito integration with user management
- **🗄️ Database Management**: PostgreSQL RDS with Redis caching
- **🔒 Secure Access**: SSH tunneling through bastion hosts
- **⚡ Infrastructure Automation**: Complete AWS resource provisioning
- **📊 Resource Monitoring**: Real-time AWS resource tracking
- **🛡️ Security First**: Comprehensive security audit and best practices

## ✨ Features

### Authentication & Security
- AWS Cognito user pool and identity pool integration
- Multi-factor authentication support
- Secure password policies and user management
- Role-based access control

### Database Infrastructure
- PostgreSQL RDS with automated schema management
- Redis ElastiCache for high-performance caching
- Secure SSH tunneling for database access
- Automated backup and recovery

### Infrastructure Management
- Complete AWS resource provisioning
- Automated VPC, subnets, and security groups
- Bastion host setup for secure access
- Cost optimization and monitoring

### Development Tools
- TypeScript for type safety
- Next.js 14 with App Router
- Comprehensive testing suite
- Automated deployment pipelines

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Next.js App   │    │   AWS Cognito   │    │   PostgreSQL    │
│   (Frontend)    │◄──►│  (Authentication)│    │     (RDS)       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │              ┌─────────────────┐              │
         │              │   Bastion Host  │              │
         │              │   (SSH Tunnel)  │              │
         │              └─────────────────┘              │
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Redis Cache   │
                    │  (ElastiCache)  │
                    └─────────────────┘
```

### Technology Stack

- **Frontend**: Next.js 14, TypeScript, Tailwind CSS
- **Authentication**: AWS Cognito
- **Database**: PostgreSQL RDS, Redis ElastiCache
- **Infrastructure**: AWS (VPC, EC2, RDS, ElastiCache)
- **Security**: SSH tunneling, IAM roles, security groups

## 🚀 Quick Start

### Prerequisites

- Node.js 18+ and npm
- AWS CLI configured with appropriate permissions
- SSH key pair for bastion host access

### 1. Clone and Setup

```bash
git clone <repository-url>
cd utils-aws-management
npm install
```

### 2. Environment Configuration

```bash
cp .env.example .env.local
# Edit .env.local with your configuration
```

### 3. Infrastructure Setup

```bash
# Complete infrastructure setup (recommended)
cd aws/resources/master
./setup-all-infrastructure.sh

# Or setup individual components
cd aws/resources/cognito
./setup-aws-cognito.sh
```

### 4. Start Development

```bash
# Start SSH tunnels for database access
cd aws/resources/bastion
./tunnel-to-databases.sh

# Start the development server
npm run dev
```

### 5. Test Connections

```bash
# Test database connectivity
node aws/test/test-local-connections.js
```

## 📚 Documentation

Our documentation is organized into logical sections for easy navigation:

### 🏗️ Infrastructure Documentation
- **[AWS Infrastructure Guide](docs/aws/README.md)** - Complete AWS setup and management
- **[Quick Reference](docs/aws/AWS_QUICK_REFERENCE.md)** - Essential commands and shortcuts
- **[Organization Summary](docs/aws/AWS_ORGANIZATION_SUMMARY.md)** - Infrastructure organization overview
- **[Jump Box Guide](docs/aws/JUMP_BOX_INFO.md)** - Bastion host setup and usage

### 🔧 Management & Setup
- **[AWS Management Guide](docs/aws-management/AWS_SETUP_README.md)** - AWS resource management
- **[Cognito Setup](docs/aws-management/AWS_COGNITO_SETUP.md)** - Authentication configuration

### 🛠️ Project Setup
- **[Environment Setup](docs/project-setup-guide/ENVIRONMENT_SETUP.md)** - Development environment configuration
- **[Product Features](docs/project-setup-guide/ProductFeatures.md)** - Complete feature documentation and roadmap

### 🧪 Testing & Troubleshooting
- **[Database Setup Summary](docs/testing/DATABASE_SETUP_SUMMARY.md)** - Database configuration and testing
- **[Troubleshooting Guide](docs/testing/DATABASE_TROUBLESHOOTING.md)** - Common issues and solutions
- **[Connectivity Summary](docs/testing/CONNECTIVITY_SUMMARY.md)** - Connection testing and validation

### 🔒 Security
- **[Security Audit Summary](docs/security/SECURITY_AUDIT_SUMMARY.md)** - Security assessment and best practices

## 🏗️ Infrastructure

### AWS Resources

The application uses the following AWS services:

| Service | Purpose | Cost Estimate |
|---------|---------|---------------|
| **RDS PostgreSQL** | Primary database | ~$15-20/month |
| **ElastiCache Redis** | Caching layer | ~$10-15/month |
| **EC2 Bastion Host** | SSH tunneling | ~$8-10/month |
| **Cognito** | Authentication | ~$0.50/month |
| **VPC & Security Groups** | Network isolation | ~$0/month |

**Total Estimated Cost**: ~$33-45/month

### Infrastructure Components

- **Authentication**: AWS Cognito user pool and identity pool
- **Database**: PostgreSQL RDS with automated schema management
- **Caching**: Redis ElastiCache for performance optimization
- **Security**: Bastion host with SSH tunneling
- **Networking**: Custom VPC with security groups

### Quick Infrastructure Commands

```bash
# Complete setup
cd aws/resources/master
./setup-all-infrastructure.sh

# Individual components
cd aws/resources/cognito && ./setup-aws-cognito.sh
cd aws/resources/bastion && ./tunnel-to-databases.sh
cd aws/resources/master && ./cleanup-aws-resources.sh
```

## 💻 Development

### Project Structure

```
├── src/                    # Next.js application source
│   ├── app/               # App Router pages and components
│   ├── types/             # TypeScript type definitions
│   └── utils/             # Utility functions
├── aws/                   # AWS infrastructure scripts
│   ├── resources/         # Infrastructure setup scripts
│   │   ├── master/        # Master orchestration scripts
│   │   ├── cognito/       # Authentication scripts
│   │   ├── database/      # Database scripts
│   │   ├── redis/         # Redis scripts
│   │   └── bastion/       # Bastion host scripts
│   └── test/              # Infrastructure testing scripts
├── docs/                  # Documentation
│   ├── aws/               # AWS infrastructure docs
│   ├── aws-management/    # Management guides
│   ├── project-setup-guide/ # Setup guides
│   ├── testing/           # Testing documentation
│   └── security/          # Security documentation
└── public/                # Static assets
```

### Development Workflow

1. **Setup Environment**: Configure environment variables
2. **Start Infrastructure**: Run infrastructure setup scripts
3. **Start Tunnels**: Establish SSH tunnels for database access
4. **Development**: Run the Next.js development server
5. **Testing**: Run connectivity and functionality tests
6. **Cleanup**: Terminate resources when done

### Available Scripts

```bash
npm run dev          # Start development server
npm run build        # Build for production
npm run start        # Start production server
npm run lint         # Run ESLint
npm run type-check   # Run TypeScript type checking
```

## 🔒 Security

### Security Features

- **SSH Tunneling**: All database access through encrypted tunnels
- **IAM Roles**: Least privilege access to AWS resources
- **Security Groups**: Restrictive network access policies
- **Environment Variables**: Secure credential management
- **Audit Trail**: Comprehensive security documentation

### Security Best Practices

- All sensitive files excluded from version control
- No hardcoded secrets in tracked files
- Regular security audits and updates
- Secure SSH key management
- Environment-specific configurations

For detailed security information, see [Security Audit Summary](docs/security/SECURITY_AUDIT_SUMMARY.md).

## 🤝 Contributing

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Follow the development workflow
4. Run tests and security checks
5. Submit a pull request

### Code Standards

- TypeScript for type safety
- ESLint for code quality
- Prettier for code formatting
- Comprehensive documentation
- Security-first approach

### Testing

```bash
# Test infrastructure connectivity
node aws/test/test-local-connections.js

# Test database operations
node aws/test/test-db-direct.js

# Test Redis connectivity
node aws/test/test-redis-simple.js
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

### Getting Help

1. **Documentation**: Check the relevant documentation sections
2. **Troubleshooting**: See [Troubleshooting Guide](docs/testing/DATABASE_TROUBLESHOOTING.md)
3. **Security Issues**: Review [Security Audit](docs/security/SECURITY_AUDIT_SUMMARY.md)
4. **Infrastructure**: Consult [AWS Infrastructure Guide](docs/aws/README.md)

### Common Issues

- **Database Connection**: Ensure SSH tunnels are active
- **Authentication**: Verify Cognito configuration
- **Infrastructure**: Check AWS credentials and permissions
- **Security**: Review security group configurations

---

**Built with ❤️ using Next.js, TypeScript, and AWS**

*For detailed documentation, see the [docs/](docs/) directory.*
