# TaskFlow - Technology Stack

## Programming Languages

### Backend
- **Node.js**: v18.x (LTS)
- **JavaScript**: ES6+ with async/await patterns

### Frontend
- **JavaScript**: ES6+ with JSX
- **React**: 18.2.0
- **CSS3**: Modern styling with flexbox/grid

### Infrastructure
- **HCL**: Terraform configuration language
- **Shell Script**: Bash for automation and userdata scripts

## Core Dependencies

### Backend (`backend/package.json`)
```json
{
  "dependencies": {
    "@opentelemetry/api": "^1.9.0",
    "@opentelemetry/auto-instrumentations-node": "^0.53.0",
    "@opentelemetry/exporter-trace-otlp-http": "^0.53.0",
    "@opentelemetry/resources": "^1.26.0",
    "@opentelemetry/sdk-node": "^0.53.0",
    "@opentelemetry/semantic-conventions": "^1.26.0",
    "cors": "^2.8.5",
    "express": "^4.18.2",
    "prom-client": "^15.1.3",
    "uuid": "^9.0.0"
  },
  "devDependencies": {
    "eslint": "^8.40.0",
    "jest": "^29.5.0",
    "jest-junit": "^16.0.0",
    "nodemon": "^2.0.22",
    "prettier": "^2.8.8",
    "supertest": "^6.3.3"
  }
}
```

### Frontend (`frontend/package.json`)
```json
{
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1"
  }
}
```

## Infrastructure Tools

### Terraform
- **Version**: >= 1.0
- **AWS Provider**: ~> 5.0
- **Null Provider**: ~> 3.0

### AWS Services
- **EC2**: t3.micro (App, Jenkins), t3.small (Monitoring)
- **ECR**: Docker image registry
- **S3**: CloudTrail log storage with encryption
- **IAM**: Roles and instance profiles
- **CloudWatch Logs**: Container log aggregation
- **CloudTrail**: API audit logging
- **GuardDuty**: Threat detection

### Containerization
- **Docker**: Multi-stage builds
- **Docker Compose**: v3.8 for service orchestration
- **Base Images**: 
  - `node:18-alpine` (backend build/test)
  - `nginx:alpine` (frontend serving)

## Observability Stack

### Monitoring Services
- **Prometheus**: v2.x - Metrics collection and storage
- **Grafana**: v10.x - Visualization and dashboards
- **Alertmanager**: v0.26.x - Alert routing and management
- **Node Exporter**: v1.x - System metrics collection
- **Loki**: v2.x - Log aggregation
- **Promtail**: v2.x - Log shipping agent
- **Jaeger**: v1.x - Distributed tracing backend

### Instrumentation Libraries
- **prom-client**: Prometheus metrics for Node.js
- **OpenTelemetry SDK**: Distributed tracing instrumentation
- **OpenTelemetry Auto-Instrumentation**: Automatic HTTP span creation

## CI/CD Tools

### Jenkins
- **Version**: Latest LTS
- **Plugins**: Git, Pipeline, AWS, Docker
- **Pipeline**: Declarative syntax with Groovy

### Build Tools
- **npm**: Package management and script execution
- **Docker CLI**: Image building and container management
- **AWS CLI**: ECR authentication and AWS service interaction

## Development Commands

### Backend Development
```bash
# Install dependencies
npm ci

# Start development server with hot reload
npm run dev

# Run unit tests with coverage
npm test

# Run tests in watch mode
npm run test:watch

# Lint code
npm run lint

# Format code
npm run format

# Start production server
npm start
```

### Frontend Development
```bash
# Install dependencies
npm ci

# Start development server (port 3000)
npm start

# Build production bundle
npm build

# Run unit tests
npm test

# Run tests in watch mode
npm run test:watch
```

### Infrastructure Management
```bash
# Initialize Terraform
cd terraform
terraform init

# Plan infrastructure changes
terraform plan

# Apply infrastructure
terraform apply

# Destroy infrastructure
terraform destroy

# Format Terraform files
terraform fmt -recursive

# Validate configuration
terraform validate
```

### Docker Operations
```bash
# Build backend image
docker build -t taskflow-backend:latest ./backend

# Build frontend image
docker build -t taskflow-frontend:latest ./frontend

# Run backend locally
docker run -p 5000:5000 taskflow-backend:latest

# Run frontend locally
docker run -p 80:80 taskflow-frontend:latest

# Production deployment
docker-compose -f docker-compose.prod.yml up -d

# View logs
docker-compose -f docker-compose.prod.yml logs -f

# Stop services
docker-compose -f docker-compose.prod.yml down
```

### Monitoring Stack
```bash
# Deploy monitoring stack
cd monitoring
docker-compose up -d

# View logs
docker-compose logs -f

# Restart services
docker-compose restart

# Stop monitoring
docker-compose down
```

## Testing Frameworks

### Backend Testing
- **Jest**: Unit testing framework
- **Supertest**: HTTP assertion library
- **jest-junit**: JUnit XML reporter for CI integration

### Frontend Testing
- **React Testing Library**: Component testing
- **Jest**: Test runner (via react-scripts)
- **@testing-library/jest-dom**: Custom matchers

## Code Quality Tools

### Linting
- **ESLint**: JavaScript linting with custom rules
- **eslint-config-react-app**: React-specific linting rules

### Formatting
- **Prettier**: Code formatting

## Build Systems

### Backend Build
- Multi-stage Dockerfile
- Stage 1: Dependencies installation
- Stage 2: Production runtime with minimal footprint

### Frontend Build
- Multi-stage Dockerfile
- Stage 1: Node.js build (npm run build)
- Stage 2: Nginx serving static files

### CI/CD Build
- Jenkins declarative pipeline
- Parallel execution for backend/frontend
- Containerized testing (no agent dependencies)
- Docker layer caching for faster builds

## Environment Configuration

### Backend Environment Variables
```bash
PORT=5000
NODE_ENV=production
OTEL_EXPORTER_OTLP_ENDPOINT=http://monitoring-host:4318
OTEL_SERVICE_NAME=taskflow-backend
```

### Frontend Environment Variables
```bash
REACT_APP_API_URL=http://app-server-ip:5000
```

### Terraform Variables
```hcl
aws_region              = "us-east-1"
jenkins_instance_type   = "t3.micro"
app_instance_type       = "t3.micro"
monitoring_instance_type = "t3.small"
key_name                = "taskflow-key"
public_key_path         = "~/.ssh/id_rsa.pub"
private_key_path        = "~/.ssh/id_rsa"
admin_cidr_blocks       = ["YOUR_IP/32"]
cloudtrail_bucket_name  = "taskflow-cloudtrail-logs"
```

## Version Requirements

### Minimum Versions
- Node.js: >= 18.0.0
- npm: >= 9.0.0
- Docker: >= 20.10.0
- Docker Compose: >= 2.0.0
- Terraform: >= 1.0.0
- AWS CLI: >= 2.0.0

### Recommended Versions
- Node.js: 18.x LTS
- Docker: Latest stable
- Terraform: Latest 1.x
- AWS CLI: Latest v2

## Port Allocations

### Application Ports
- `5000`: Backend API
- `80`: Frontend (production)
- `3000`: Frontend (development)

### Monitoring Ports
- `9090`: Prometheus
- `3000`: Grafana
- `9093`: Alertmanager
- `9100`: Node Exporter
- `3100`: Loki
- `9080`: Promtail
- `16686`: Jaeger UI
- `4318`: Jaeger OTLP HTTP

### Infrastructure Ports
- `8080`: Jenkins
- `22`: SSH

## AWS Resource Naming

### Naming Convention
- Pattern: `taskflow-{resource-type}-{environment}`
- Example: `taskflow-sg`, `taskflow-trail`, `taskflow-cloudtrail-logs`

### Resource Tags
```hcl
tags = {
  Project     = "TaskFlow"
  Environment = "Production"
  ManagedBy   = "Terraform"
}
```
