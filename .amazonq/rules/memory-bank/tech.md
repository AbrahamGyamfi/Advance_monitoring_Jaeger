# TaskFlow - Technology Stack

## Programming Languages

### Backend
- **Node.js**: v18 (LTS)
- **JavaScript**: ES6+ with async/await patterns

### Frontend
- **JavaScript**: ES6+ with React JSX
- **HTML5**: Semantic markup
- **CSS3**: Modern styling with flexbox

### Infrastructure
- **HCL**: Terraform configuration language
- **Bash**: Shell scripts for automation
- **YAML**: Configuration files (Docker Compose, Jenkins, Prometheus)

## Core Technologies

### Application Framework
- **Backend**: Express 4.18.2
  - Lightweight web framework
  - Middleware-based architecture
  - RESTful API design
- **Frontend**: React 18.2.0
  - Component-based UI
  - Hooks for state management
  - Virtual DOM for performance

### Observability
- **Metrics**: Prometheus 2.54
  - Time-series database
  - PromQL query language
  - 15-second scrape interval
- **Tracing**: OpenTelemetry SDK 0.53
  - Auto-instrumentation for Node.js
  - OTLP HTTP exporter
  - Jaeger 1.58 backend
- **Logging**: Loki 3.1.1
  - Log aggregation
  - Promtail for shipping
  - LogQL query language
- **Visualization**: Grafana 11.1
  - Dashboard provisioning
  - Multiple data sources
  - Alert visualization
- **Alerting**: Alertmanager 0.27
  - Alert routing and grouping
  - Notification management

### Infrastructure & DevOps
- **IaC**: Terraform >= 1.0
  - AWS provider
  - Modular architecture
  - State management
- **CI/CD**: Jenkins
  - Declarative pipeline
  - Jenkins Configuration as Code (JCasC)
  - Docker-based builds
- **Containers**: Docker
  - Multi-stage builds
  - Docker Compose 3.8
  - Non-root execution
- **Cloud**: AWS
  - EC2 (t3.micro, t3.small)
  - ECR (container registry)
  - S3 (artifact storage)
  - ALB (load balancing)
  - ASG (auto scaling)
  - CodeDeploy (blue-green)
  - CloudWatch (logging)
  - CloudTrail (audit)
  - GuardDuty (threat detection)
  - IAM (access control)

## Dependencies

### Backend (`backend/package.json`)
**Production**:
- `express@^4.18.2` - Web framework
- `cors@^2.8.5` - Cross-origin resource sharing
- `uuid@^9.0.0` - Unique ID generation
- `prom-client@^15.1.3` - Prometheus metrics
- `@opentelemetry/api@^1.9.0` - Tracing API
- `@opentelemetry/sdk-node@^0.53.0` - Tracing SDK
- `@opentelemetry/auto-instrumentations-node@^0.53.0` - Auto-instrumentation
- `@opentelemetry/exporter-trace-otlp-http@^0.53.0` - OTLP exporter
- `@opentelemetry/resources@^1.26.0` - Resource attributes
- `@opentelemetry/semantic-conventions@^1.26.0` - Standard attributes

**Development**:
- `jest@^29.5.0` - Testing framework
- `jest-junit@^16.0.0` - JUnit XML reporter
- `supertest@^6.3.3` - HTTP assertion library
- `eslint@^8.40.0` - Code linting
- `prettier@^2.8.8` - Code formatting
- `nodemon@^2.0.22` - Development server

### Frontend (`frontend/package.json`)
**Production**:
- `react@^18.2.0` - UI library
- `react-dom@^18.2.0` - React DOM renderer
- `react-scripts@5.0.1` - Build tooling

## Build Systems

### Backend Build
```bash
# Development
npm install          # Install dependencies
npm run dev          # Start with nodemon
npm test             # Run Jest tests
npm run lint         # ESLint checks

# Production
docker build -t taskflow-backend .
docker run -p 5000:5000 taskflow-backend
```

### Frontend Build
```bash
# Development
npm install          # Install dependencies
npm start            # Development server (port 3000)
npm test             # Run React tests
npm run lint         # ESLint checks

# Production
npm run build        # Create optimized build
docker build -t taskflow-frontend .
docker run -p 80:80 taskflow-frontend
```

### Infrastructure Build
```bash
# Terraform
cd terraform
terraform init       # Initialize providers
terraform plan       # Preview changes
terraform apply      # Apply infrastructure
terraform destroy    # Tear down resources

# Outputs
terraform output jenkins_public_ip
terraform output monitoring_public_ip
terraform output alb_dns_name
```

## Development Commands

### Local Development
```bash
# Start backend
cd backend
npm install
npm run dev          # Runs on port 5000

# Start frontend
cd frontend
npm install
npm start            # Runs on port 3000

# Run tests
cd backend && npm test
cd frontend && npm test
```

### Docker Development
```bash
# Build images
docker build -t taskflow-backend ./backend
docker build -t taskflow-frontend ./frontend

# Run with Docker Compose
export REGISTRY_URL=local
export IMAGE_TAG=latest
export MONITORING_HOST=localhost
docker-compose up -d

# View logs
docker logs taskflow-backend-prod
docker logs taskflow-frontend-prod

# Stop services
docker-compose down
```

### Monitoring Stack
```bash
# Deploy monitoring
cd monitoring
docker-compose up -d

# Access services
# Grafana: http://localhost:3000
# Prometheus: http://localhost:9090
# Jaeger: http://localhost:16686
# Alertmanager: http://localhost:9093

# View logs
docker-compose logs -f prometheus
docker-compose logs -f grafana

# Stop monitoring
docker-compose down
```

### Testing Commands
```bash
# Backend tests (23 tests)
cd backend
npm test                    # Run all tests with coverage
npm run test:watch          # Watch mode

# Frontend tests (8 tests)
cd frontend
npm test                    # Run all tests
npm run test:watch          # Watch mode

# Integration tests
./monitoring/validate-observability.sh \
  --app-url http://localhost:5000 \
  --prom-url http://localhost:9090 \
  --duration-minutes 5
```

### Deployment Commands
```bash
# Full deployment
./deploy-and-verify.sh

# Manual deployment
cd terraform
terraform apply
# Wait for infrastructure
# Jenkins will auto-deploy on code push

# Cleanup
./cleanup.sh
# OR
cd terraform && terraform destroy
```

### AWS CLI Commands
```bash
# Get Jenkins password
aws ssm get-parameter \
  --name /taskflow/jenkins-admin-password \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text

# View CloudWatch logs
aws logs tail /aws/taskflow/docker --follow

# Check CloudTrail events
aws cloudtrail lookup-events --max-results 10

# List GuardDuty findings
aws guardduty list-detectors
aws guardduty list-findings --detector-id <ID>

# ECR login
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <ACCOUNT>.dkr.ecr.us-east-1.amazonaws.com
```

## Configuration Files

### Docker
- `backend/Dockerfile` - Multi-stage Node.js build
- `frontend/Dockerfile` - Multi-stage React + Nginx build
- `docker-compose.yml` - Application deployment
- `monitoring/docker-compose.yml` - Observability stack

### CI/CD
- `Jenkinsfile` - Declarative pipeline (8 stages)
- `jenkins/jenkins.yaml` - JCasC configuration
- `appspec.yml` - CodeDeploy specification

### Infrastructure
- `terraform/main.tf` - Root module
- `terraform/variables.tf` - Input variables
- `terraform/outputs.tf` - Output values
- `terraform/terraform.tfvars` - Variable values

### Monitoring
- `monitoring/config/prometheus.yml` - Scrape configuration
- `monitoring/config/alert_rules.yml` - Alert definitions
- `monitoring/config/grafana-datasource.yml` - Data sources
- `monitoring/dashboards/taskflow-observability.json` - Dashboard

## Version Requirements

### Minimum Versions
- Terraform: >= 1.0
- Node.js: >= 18
- Docker: >= 20.10
- Docker Compose: >= 2.0
- AWS CLI: >= 2.0

### Recommended Versions
- Terraform: 1.5+
- Node.js: 18 LTS
- Docker: 24+
- Docker Compose: 2.20+
- AWS CLI: 2.13+
