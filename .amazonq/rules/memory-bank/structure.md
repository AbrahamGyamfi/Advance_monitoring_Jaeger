# TaskFlow - Project Structure

## Directory Organization

```
/home/ab/ Advanced Observability/
├── backend/                    # Node.js Express API service
├── frontend/                   # React 18 web application
├── terraform/                  # Infrastructure as Code
├── monitoring/                 # Observability stack configuration
├── userdata/                   # EC2 initialization scripts
├── Screenshots/                # Documentation images
├── .amazonq/                   # Amazon Q configuration
├── Jenkinsfile                 # CI/CD pipeline definition
├── docker-compose.prod.yml     # Production deployment config
└── deployment scripts          # Automation utilities
```

## Core Components

### Backend Service (`/backend`)
**Purpose**: RESTful API server with observability instrumentation

**Key Files**:
- `app.js` - Express application with routes, middleware, and metrics
- `server.js` - HTTP server entrypoint
- `metrics.js` - Prometheus metrics definitions (counters, histograms, gauges)
- `telemetry.js` - OpenTelemetry SDK configuration for distributed tracing
- `logger.js` - Structured logging with trace context injection
- `server.test.js` - Jest unit tests with Supertest
- `Dockerfile` - Multi-stage build for production image
- `package.json` - Dependencies and scripts

**Architecture Pattern**: Express middleware chain with instrumentation layers
- Request logging → Metrics collection → Route handlers → Response

**Dependencies**:
- Express 4.18 for HTTP server
- prom-client 15.1 for Prometheus metrics
- OpenTelemetry SDK 0.53 for distributed tracing
- Jest 29.5 for testing

### Frontend Application (`/frontend`)
**Purpose**: React-based user interface for task management

**Structure**:
```
frontend/
├── src/
│   ├── components/         # React components
│   ├── App.js             # Main application component
│   ├── App.css            # Styling
│   ├── index.js           # React DOM entry point
│   └── setupTests.js      # Jest configuration
├── public/
│   └── index.html         # HTML template
├── Dockerfile             # Nginx-based production image
└── nginx.conf             # Reverse proxy configuration
```

**Architecture Pattern**: Component-based React with API proxy
- React components → Fetch API → Backend REST endpoints

**Dependencies**:
- React 18.2 for UI framework
- react-scripts 5.0 for build tooling

### Infrastructure (`/terraform`)
**Purpose**: Modular Terraform for AWS resource provisioning

**Module Architecture**:
```
terraform/
├── main.tf                # Root module orchestration
├── variables.tf           # Input variable definitions
├── outputs.tf             # Output value exports
└── modules/
    ├── networking/        # Security groups, SSH keys
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── compute/           # EC2 instances (Jenkins, App)
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── deployment/        # Application provisioning
    │   ├── main.tf
    │   └── variables.tf
    ├── monitoring/        # Prometheus + Grafana stack
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── security/          # CloudTrail, GuardDuty, IAM
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

**Resource Relationships**:
1. `networking` → Creates security group and SSH key pair
2. `security` → Creates IAM roles and S3 bucket
3. `compute` → Provisions EC2 instances using networking and security outputs
4. `monitoring` → Deploys monitoring stack using compute outputs
5. `deployment` → Configures application on EC2 instances

**Provisioned Resources**:
- 3 EC2 instances (t3.micro for Jenkins/App, t3.small for Monitoring)
- Security group with ports: 22, 80, 3000, 5000, 8080, 9090, 9093, 9100, 16686
- IAM instance profile with CloudWatch Logs permissions
- S3 bucket for CloudTrail logs (encrypted, 90-day lifecycle)
- CloudWatch log groups
- Imported CloudTrail and GuardDuty resources

### Monitoring Stack (`/monitoring`)
**Purpose**: Complete observability infrastructure

**Configuration Files**:
```
monitoring/
├── config/
│   ├── prometheus.yml              # Scrape configs and targets
│   ├── alert_rules.yml             # Alert definitions
│   ├── alertmanager.yml            # Alert routing
│   ├── grafana-datasource.yml      # Datasource provisioning
│   ├── loki-config.yml             # Log aggregation config
│   └── promtail-app.yml            # Log shipping config
├── dashboards/
│   └── taskflow-observability.json # Grafana dashboard JSON
├── docker-compose.yml              # Stack orchestration
└── validate-observability.sh       # Testing script
```

**Stack Components**:
- **Prometheus**: Metrics collection and storage (port 9090)
- **Grafana**: Visualization and dashboards (port 3000)
- **Alertmanager**: Alert routing and notification (port 9093)
- **Node Exporter**: System metrics (port 9100)
- **Jaeger**: Distributed tracing backend (port 16686)
- **Loki**: Log aggregation (port 3100)
- **Promtail**: Log shipping agent

**Scrape Targets**:
- `taskflow-backend:5000/metrics` - Application metrics
- `node-exporter:9100/metrics` - System metrics
- `prometheus:9090/metrics` - Self-monitoring

### CI/CD Pipeline (`/Jenkinsfile`)
**Purpose**: Automated build, test, and deployment pipeline

**Pipeline Stages**:
1. **Checkout** - Clone repository and extract Git metadata
2. **Build Docker Images** - Parallel backend and frontend builds
3. **Run Unit Tests** - Parallel containerized testing
4. **Code Quality** - ESLint and image verification
5. **Integration Tests** - API endpoint validation
6. **Push to ECR** - Upload images to AWS registry
7. **Deploy to EC2** - SSH deployment with docker-compose
8. **Health Check** - Verify deployment success

**Architecture Pattern**: Declarative pipeline with parallel execution
- Parallel stages for independent tasks (build, test)
- Sequential stages for dependent tasks (deploy, verify)

### User Data Scripts (`/userdata`)
**Purpose**: EC2 instance initialization

**Scripts**:
- `jenkins-userdata.sh` - Install Jenkins, Docker, AWS CLI
- `app-userdata.sh` - Install Docker, Docker Compose, CloudWatch agent
- `monitoring-userdata.sh` - Deploy monitoring stack with docker-compose

**Execution**: Run at EC2 instance launch via Terraform

## Architectural Patterns

### Multi-Tier Architecture
```
┌─────────────────┐
│   Frontend      │ (React SPA)
│   Port 80       │
└────────┬────────┘
         │ HTTP
         ▼
┌─────────────────┐
│   Backend       │ (Express API)
│   Port 5000     │
└────────┬────────┘
         │ Metrics
         ▼
┌─────────────────┐
│   Monitoring    │ (Prometheus/Grafana)
│   Ports 3000,   │
│   9090, 16686   │
└─────────────────┘
```

### Observability Pattern
```
Application → Metrics → Prometheus → Grafana
           → Traces  → Jaeger
           → Logs    → Loki → Grafana
```

### Deployment Pattern
```
Git Push → Jenkins → Build → Test → ECR → EC2 → Docker Compose
```

### Security Pattern
```
EC2 Actions → CloudTrail → S3 Bucket
           → CloudWatch Logs
           → GuardDuty (threat detection)
```

## Component Relationships

### Data Flow
1. **User Request**: Browser → Frontend (Nginx) → Backend (Express)
2. **Metrics Collection**: Backend → Prometheus (scrape) → Grafana (query)
3. **Trace Collection**: Backend → Jaeger (OTLP) → Grafana (query)
4. **Log Collection**: Backend → Loki (via Promtail) → Grafana (query)
5. **Alerts**: Prometheus → Alertmanager → Notifications

### Deployment Flow
1. **Code Commit**: Developer → GitHub
2. **CI Trigger**: GitHub webhook → Jenkins
3. **Build**: Jenkins → Docker images
4. **Test**: Jenkins → Containerized tests
5. **Publish**: Jenkins → AWS ECR
6. **Deploy**: Jenkins → EC2 (via SSH) → Docker Compose
7. **Verify**: Jenkins → Health check endpoint

### Infrastructure Dependencies
1. **Networking Module** provides security group and SSH key
2. **Security Module** provides IAM roles and S3 bucket
3. **Compute Module** uses networking and security outputs
4. **Monitoring Module** uses compute outputs (IPs)
5. **Deployment Module** uses compute outputs (IPs)

## Configuration Management

### Environment Variables
- Jenkins credentials for AWS, EC2, and application settings
- Docker Compose environment files for runtime configuration
- Terraform variables for infrastructure customization

### Secrets Management
- Jenkins credentials store for AWS keys and SSH keys
- EC2 IAM roles for AWS service access
- Grafana admin password in monitoring `.env` file

### State Management
- Terraform state files for infrastructure tracking
- In-memory task storage in backend (ephemeral)
- Prometheus TSDB for metrics retention
- Loki storage for log retention
