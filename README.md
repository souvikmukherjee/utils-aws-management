# AWS Management Utilities

A comprehensive web-based platform for efficient AWS infrastructure management, cost optimization, and resource monitoring. Built with Next.js, TypeScript, and Tailwind CSS.

## 🚀 Quick Start

### Prerequisites
- Node.js 18+ 
- AWS Account with appropriate permissions
- PostgreSQL database (AWS RDS recommended)
- Redis cache (AWS ElastiCache recommended)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd utils-aws-management
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Set up environment variables**
   ```bash
   cp .env.example .env.local
   # Edit .env.local with your AWS credentials and configuration
   ```

4. **Run the development server**
   ```bash
   npm run dev
   ```

5. **Open your browser**
   Navigate to [http://localhost:3000](http://localhost:3000)

## 📋 Project Management

This project uses **Task Master** for comprehensive project management and task tracking. All development tasks, features, and progress are managed through the Task Master system.

### Key Project Files
- **Task Management**: `.taskmaster/tasks/tasks.json` - Complete task breakdown
- **Project Configuration**: `.taskmaster/config.json` - Task Master configuration
- **Product Features**: [ProductFeatures.md](./ProductFeatures.md) - Comprehensive feature documentation

### Task Master Commands
```bash
# View all tasks
task-master list

# See next task to work on
task-master next

# View specific task details
task-master show <task-id>

# Mark task as complete
task-master set-status --id=<task-id> --status=done
```

## 🏗️ Architecture

### Tech Stack
- **Frontend**: Next.js 14, TypeScript, Tailwind CSS
- **Backend**: Next.js API Routes, AWS SDK
- **Database**: PostgreSQL (AWS RDS)
- **Caching**: Redis (AWS ElastiCache)
- **Authentication**: AWS Cognito + NextAuth.js
- **Deployment**: AWS (ECS, Lambda, or Vercel)

### AWS Services Integration
- **AWS Cognito**: User authentication and management
- **AWS Cost Explorer**: Cost data and analytics
- **AWS Organizations**: Multi-account management
- **AWS RDS**: Managed PostgreSQL database
- **AWS ElastiCache**: Managed Redis caching
- **AWS IAM**: Identity and access management

## 📖 Documentation

### Product Features
For detailed information about all features, capabilities, and development roadmap, see:
**[ProductFeatures.md](./ProductFeatures.md)**

This document includes:
- Complete feature breakdown
- Technical architecture details
- Development phases and roadmap
- Task and subtask specifications
- Security and compliance information

### Development Documentation
- **API Documentation**: Available at `/api/docs` when running locally
- **Component Library**: Built with Tailwind CSS and custom components
- **Database Schema**: PostgreSQL schema definitions
- **AWS Integration**: AWS service configuration and setup guides

## 🔧 Development

### Available Scripts
```bash
# Development
npm run dev          # Start development server
npm run build        # Build for production
npm run start        # Start production server
npm run lint         # Run ESLint
npm run type-check   # Run TypeScript type checking

# Testing
npm run test         # Run tests
npm run test:watch   # Run tests in watch mode
npm run test:coverage # Run tests with coverage

# Database
npm run db:migrate   # Run database migrations
npm run db:seed      # Seed database with sample data
```

### Environment Variables
```bash
# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key

# Database
DATABASE_URL=postgresql://user:password@host:port/database
REDIS_URL=redis://host:port

# Authentication
NEXTAUTH_SECRET=your-nextauth-secret
NEXTAUTH_URL=http://localhost:3000

# AWS Cognito
COGNITO_CLIENT_ID=your-cognito-client-id
COGNITO_CLIENT_SECRET=your-cognito-client-secret
COGNITO_ISSUER=https://cognito-idp.region.amazonaws.com/region_pool_id
```

## 🚀 Deployment

### AWS Deployment
1. **Set up AWS infrastructure** using AWS CDK or Terraform
2. **Configure environment variables** for production
3. **Build and deploy** using your preferred method:
   - AWS ECS with Fargate
   - AWS Lambda with API Gateway
   - Vercel (recommended for Next.js)

### Environment Setup
- **Development**: Local development with hot reload
- **Staging**: Pre-production testing environment
- **Production**: Live production environment

## 🤝 Contributing

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Commit your changes** (`git commit -m 'Add amazing feature'`)
4. **Push to the branch** (`git push origin feature/amazing-feature`)
5. **Open a Pull Request**

### Development Guidelines
- Follow TypeScript best practices
- Use Tailwind CSS for styling
- Write comprehensive tests
- Update documentation as needed
- Follow the Task Master workflow

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: [ProductFeatures.md](./ProductFeatures.md)
- **Issues**: Create an issue in the GitHub repository
- **Discussions**: Use GitHub Discussions for questions and ideas

---

**Built with ❤️ using Next.js, TypeScript, and AWS services**
