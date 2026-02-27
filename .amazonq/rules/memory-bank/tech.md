# TaskFlow - Technology Stack

## Programming Languages

### JavaScript/Node.js
- **Backend**: Node.js 18 (LTS)
- **Frontend**: React 18.2.0
- **Runtime**: Node.js Alpine Linux containers for production

### Infrastructure as Code
- **Terraform**: HCL (HashiCorp Configuration Language)
- **Version**: >= 1.0
- **Provider**: AWS ~> 5.0

### Configuration
- **YAML**: Prometheus, Grafana, Docker Compose, Alert rules
- **JSON**: Grafana dashboards, package manifests
- **Shell**: Bash scripts for automation

## Backend Technology Stack

### Core Framework
- **Express.js**: 4.18.2 - Web application framework
- **CORS**: 2.8.5 - Cross-origin resource sharing

### Observability Libraries
- **prom-client**: 15.1.3 - Prometheus metrics client
- **@opentelemetry/sdk-node**: 0.53.0 - OpenTelemetry SDK
- **@opentelemetry/auto-instrumentations-node**: 0.53.0 - Auto-instrumentation
- **@opentelemetry/exporter-trace-otlp-http**: 0.53.0 - OTLP trace exporter
- **@opentelemetry/resources**: 1.26.0 - Resource definitions
- **@opentelemetry/semantic-conventions**: 1.26.0 - Semantic conventions

### Utilities
- **uuid**: 9.0.0 - Unique identifier generation

### Development Tools
- **Jest**: 29.5.0 - Testing framework
- **Supertest**: 6.3.3 - HTTP assertion library
- **ESLint**: 8.40.0 - Code linting
- **Prettier**: 2.8.8 - Code formatting
- **Nodemon**: 2.0.22 - Development server with hot reload
- **jest-junit**: 16.0.0 - JUnit XML reporter

## Frontend Technology Stack

### Core Framework
- **React**: 18.2.0 - UI library
- **React DOM**: 18.2.0 - React rendering
- **react-scripts**: 5.0.1 - Create React App tooling

### Build Tools
- **Webpack**: (via react-scripts) - Module bundler
- **Babel**: (via react-scripts) - JavaScript transpiler

### Testing
- **React Testing Library**: (via react-scripts) - Component testing
- **Jest**: (via react-scripts) - Test runner

## Infrastructure & DevOps

### Container Platform
- **Docker**: Multi-stage builds
- **Docker Compose**: 3.8 specification
- **Base Images**:
  - `node:18-alpine` - Backend runtime
  - `nginx:alpine` - Frontend web server

### Cloud Platform (AWS)
- **Compute**: EC2 (t3.micro, t3.small)
- **Container Registry**: ECR
- **Storage**: S3 (CloudTrail logs)
- **Identity**: IAM (roles, instance profiles)
- **Logging**: CloudWatch Logs
- **Audit**: CloudTrail
- **Security**: GuardDuty

### CI/CD
- **Jenkins**: Declarative pipeline
- **Git**: Version control
- **GitHub**: Repository hosting with webhook triggers

### Infrastructure as Code
- **Terraform**: 1.0+
- **Modules**: Custom modular architecture
  - networking
  - compute
  - deployment
  - monitoring
  - security

## Monitoring & Observability Stack

### Metrics
- **Prometheus**: 2.x - Time-series database
- **Node Exporter**: System metrics collector
- **Grafana**: 10.x - Visualization platform

### Tracing
- **Jaeger**: Distributed tracing backend
- **OpenTelemetry**: Instrumentation standard

### Logging
- **Loki**: Log aggregation system
- **Promtail**: Log shipping agent

### Alerting
- **Alertmanager**: Alert routing and management

## Development Commands

### Backend Development

```bash
# Install dependencies
cd backend
npm install

# Run development server (with hot reload)
npm run dev

# Run production server
npm start

# Run tests with coverage
npm test

# Run tests in watch mode
npm run test:watch

# Lint code
npm run lint

# Format code
npm run format

# Build Docker image
docker build -t taskflow-backend .

# Run in container
docker run -p 5000:5000 taskflow-backend
```

### Frontend Development

```bash
# Install dependencies
cd frontend
npm install

# Run development server (port 3000)
npm start

# Build production bundle
npm run build

# Run tests
npm test

# Run tests in watch mode
npm run test:watch

# Build Docker image
docker build -t taskflow-frontend .

# Run in container
docker run -p 80:80 taskflow-frontend
```

### Infrastructure Management

```bash
# Initialize Terraform
cd terraform
terraform init

# Validate configuration
terraform validate

# Plan infrastructure changes
terraform plan

# Apply infrastructure
terraform apply

# Destroy infrastructure
terraform destroy

# Format Terraform files
terraform fmt -recursive

# Show current state
terraform show

# List resources
terraform state list

# Output values
terraform output
```

### Docker Compose Operations

```bash
# Start production stack
docker-compose -f docker-compose.prod.yml up -d

# Stop stack
docker-compose -f docker-compose.prod.yml down

# View logs
docker-compose -f docker-compose.prod.yml logs -f

# Rebuild and restart
docker-compose -f docker-compose.prod.yml up -d --build

# Start monitoring stack
cd monitoring
docker-compose up -d

# View monitoring logs
docker-compose logs -f prometheus grafana
```

### Testing & Verification

```bash
# Deploy and verify entire stack
./deploy-and-verify.sh

# Validate observability stack
cd monitoring
./validate-observability.sh \
  --app-url http://APP_IP:5000 \
  --prom-url http://MONITORING_IP:9090 \
  --alert-url http://MONITORING_IP:9093 \
  --jaeger-url http://MONITORING_IP:16686 \
  --loki-url http://MONITORING_IP:3100 \
  --duration-minutes 12

# Load testing
./load-test.sh

# Check metrics endpoint
curl http://localhost:5000/metrics

# Check health endpoint
curl http://localhost:5000/health

# Check CloudWatch logs
aws logs tail /aws/taskflow/docker --follow

# Check CloudTrail events
aws cloudtrail lookup-events --max-results 10

# Check GuardDuty findings
aws guardduty list-detectors
aws guardduty list-findings --detector-id DETECTOR_ID
```

### Cleanup

```bash
# Automated cleanup
./cleanup.sh

# Manual Jenkins cleanup
./jenkins-cleanup.sh

# Terraform cleanup
cd terraform
terraform destroy -auto-approve
```

## Build Systems

### Backend Build
- **Package Manager**: npm
- **Test Runner**: Jest with coverage reporting
- **Linter**: ESLint with standard configuration
- **Formatter**: Prettier
- **Docker**: Multi-stage build with Alpine base

### Frontend Build
- **Package Manager**: npm
- **Build Tool**: react-scripts (Webpack + Babel)
- **Test Runner**: Jest + React Testing Library
- **Docker**: Multi-stage build (Node build → Nginx serve)

### Infrastructure Build
- **Provisioning**: Terraform with modular architecture
- **Validation**: terraform validate, terraform plan
- **State Management**: Local state files (terraform.tfstate)

## Port Allocations

### Application Ports
- **5000**: Backend API
- **80**: Frontend web server
- **3000**: React development server

### Monitoring Ports
- **9090**: Prometheus
- **3000**: Grafana
- **9093**: Alertmanager
- **9100**: Node Exporter
- **16686**: Jaeger UI
- **3100**: Loki

### CI/CD Ports
- **8080**: Jenkins

### System Ports
- **22**: SSH

## Environment Requirements

### Development
- Node.js 18+
- Docker 20+
- Docker Compose 2+
- Git 2+
- AWS CLI 2+
- Terraform 1.0+

### Production
- AWS Account with appropriate permissions
- SSH key pair (~/.ssh/id_rsa)
- Terraform variables configured (terraform.tfvars)
- Jenkins credentials configured
- Admin CIDR blocks for security group access

## Testing Frameworks

### Backend Testing
- **Jest**: Unit test framework
- **Supertest**: HTTP endpoint testing
- **Coverage**: Collected for app.js, server.js, metrics.js, logger.js, telemetry.js
- **Reporter**: jest-junit for CI integration

### Frontend Testing
- **Jest**: Test runner
- **React Testing Library**: Component testing
- **CI Mode**: Runs without watch mode

### Integration Testing
- **Containerized**: Tests run in Docker containers
- **Health Checks**: Automated endpoint verification
- **Load Testing**: Custom bash scripts for stress testing

## Version Control

### Git Configuration
- **Repository**: GitHub
- **Branching**: Main branch for production
- **Webhooks**: Jenkins integration for CI/CD triggers
- **Ignored Files**: node_modules, coverage, .terraform, *.tfstate, *.pem

## Dependency Management

### Backend Dependencies
- **Production**: 10 packages (Express, OpenTelemetry, prom-client, etc.)
- **Development**: 6 packages (Jest, ESLint, Supertest, etc.)
- **Lock File**: package-lock.json for reproducible builds

### Frontend Dependencies
- **Production**: 3 packages (React, React DOM, react-scripts)
- **Lock File**: package-lock.json for reproducible builds

### Infrastructure Dependencies
- **Providers**: AWS, Null
- **Lock File**: .terraform.lock.hcl for provider versions
