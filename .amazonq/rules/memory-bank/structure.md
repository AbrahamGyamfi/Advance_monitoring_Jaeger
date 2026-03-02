# TaskFlow - Project Structure

## Directory Organization

### Root Level
```
/home/ab/ Advanced Observability/
├── backend/              # Node.js Express API service
├── frontend/             # React 18 web application
├── terraform/            # Infrastructure as Code modules
├── monitoring/           # Observability stack configuration
├── jenkins/              # Jenkins Configuration as Code
├── userdata/             # EC2 cloud-init scripts
├── hooks/                # CodeDeploy lifecycle hooks
├── scripts/              # Utility and automation scripts
├── security-scans/       # Security scanning tools
├── ecs/                  # ECS task definitions (alternative deployment)
├── sonarqube/            # Code quality analysis
├── Screenshots/          # Documentation images
├── docker-compose.yml    # Application deployment manifest
├── Jenkinsfile           # CI/CD pipeline definition
└── appspec.yml           # CodeDeploy specification
```

## Core Components

### Backend Service (`/backend/`)
**Purpose**: RESTful API server with observability instrumentation

**Key Files**:
- `app.js` - Express application with routes, middleware, metrics
- `server.js` - HTTP server entrypoint
- `telemetry.js` - OpenTelemetry tracing configuration
- `metrics.js` - Prometheus metrics definitions
- `logger.js` - Structured logging with trace context
- `server.test.js` - 23 unit tests for API endpoints
- `Dockerfile` - Multi-stage build for production image

**Responsibilities**:
- Task CRUD operations (in-memory storage)
- Health check endpoint (`/health`)
- Metrics endpoint (`/metrics`) with RED methodology
- Distributed tracing with OpenTelemetry
- Structured logging with trace correlation

### Frontend Application (`/frontend/`)
**Purpose**: React-based user interface

**Structure**:
```
frontend/
├── src/
│   ├── App.js           # Main application component
│   ├── App.test.js      # 8 component tests
│   ├── components/      # Reusable UI components
│   └── index.js         # React entrypoint
├── public/
│   └── index.html       # HTML template
├── nginx.conf           # Reverse proxy configuration
└── Dockerfile           # Multi-stage build with Nginx
```

**Responsibilities**:
- Task list display and filtering
- Task creation and editing forms
- Status updates and deletion
- API communication with backend
- Responsive UI design

### Infrastructure (`/terraform/`)
**Purpose**: Modular Terraform infrastructure

**Module Architecture**:
```
terraform/
├── main.tf              # Root module orchestration
├── variables.tf         # Input variables
├── outputs.tf           # Output values
└── modules/
    ├── networking/      # Security groups, SSH keys
    ├── compute/         # EC2 instances (Jenkins, monitoring)
    ├── deployment/      # Application provisioning
    ├── monitoring/      # Observability stack setup
    ├── security/        # CloudTrail, GuardDuty, IAM, SSM
    └── codedeploy/      # ALB, ASG, Blue-Green deployment
```

**Resources Provisioned**:
- 2 EC2 instances (Jenkins, Monitoring)
- Auto Scaling Group (1-2 app instances)
- Application Load Balancer
- CodeDeploy application and deployment group
- Security groups with monitoring ports
- IAM roles (CloudWatch, CodeDeploy, Jenkins)
- S3 buckets (CloudTrail, CodeDeploy artifacts)
- CloudWatch log groups
- CloudTrail and GuardDuty

### Observability Stack (`/monitoring/`)
**Purpose**: Complete monitoring infrastructure

**Configuration Files**:
```
monitoring/
├── docker-compose.yml           # 7-service stack deployment
├── config/
│   ├── prometheus.yml           # Scrape targets and intervals
│   ├── alert_rules.yml          # SLO-based alert definitions
│   ├── alertmanager.yml         # Alert routing configuration
│   ├── loki-config.yml          # Log aggregation settings
│   ├── promtail-app.yml         # Log shipping configuration
│   └── grafana-datasource.yml   # Data source provisioning
├── dashboards/
│   └── taskflow-observability.json  # Pre-built dashboard
└── validate-observability.sh    # End-to-end validation script
```

**Services Deployed**:
- Prometheus (metrics collection, port 9090)
- Grafana (visualization, port 3000)
- Jaeger (distributed tracing, port 16686)
- Loki (log aggregation, port 3100)
- Promtail (log shipping)
- Alertmanager (alert routing, port 9093)
- Node Exporter (system metrics, port 9100)

### CI/CD Pipeline (`/jenkins/`, `Jenkinsfile`)
**Purpose**: Automated build, test, and deployment

**Pipeline Stages**:
1. **Checkout** - Clone from GitHub
2. **Build** - Docker images (parallel)
3. **Test** - Unit tests in containers
4. **Quality** - ESLint + image verification
5. **Integration** - API endpoint tests
6. **Push** - Upload to ECR
7. **Deploy** - CodeDeploy Blue-Green
8. **Health Check** - Verify via ALB

**Jenkins Configuration**:
- `jenkins.yaml` - Jenkins Configuration as Code (JCasC)
- Auto-configured credentials from AWS metadata
- SSH keys from SSM Parameter Store
- No manual setup required

### Deployment Automation (`/userdata/`, `/hooks/`)
**Purpose**: EC2 initialization and deployment lifecycle

**User Data Scripts**:
- `jenkins-userdata.sh` - Jenkins installation with JCasC
- `app-userdata.sh` - Docker and CloudWatch agent setup
- `monitoring-userdata.sh` - Observability stack deployment

**CodeDeploy Hooks**:
- `start.sh` - Pull images and start containers
- `stop.sh` - Graceful container shutdown
- `validate.sh` - Health check verification

## Architectural Patterns

### Microservices Architecture
- **Frontend**: Static React app served by Nginx
- **Backend**: Stateless Node.js API
- **Separation**: Clear API boundaries via REST

### Infrastructure as Code
- **Modularity**: 6 specialized Terraform modules
- **Reusability**: Parameterized configurations
- **Versioning**: Git-tracked infrastructure

### Observability by Design
- **Three Pillars**: Metrics, traces, logs
- **Correlation**: Trace IDs in logs for debugging
- **Proactive**: SLO-based alerting

### Blue-Green Deployment
- **Zero Downtime**: Traffic shift via ALB
- **Rollback**: Keep blue environment until validated
- **Health Checks**: Automated validation before cutover

### Container-First
- **Multi-stage Builds**: Optimized image sizes
- **Docker Compose**: Unified deployment manifest
- **Non-root Execution**: Security best practice

### Security in Depth
- **Audit Trail**: CloudTrail for all API calls
- **Threat Detection**: GuardDuty monitoring
- **Least Privilege**: IAM roles per service
- **Encryption**: S3 server-side encryption

## Component Relationships

```
GitHub → Jenkins → ECR → CodeDeploy → ASG → ALB → Users
                                      ↓
                                  Monitoring Stack
                                      ↓
                              Prometheus/Grafana/Jaeger
                                      ↓
                                  CloudWatch Logs
```

### Data Flow
1. **Code Push**: GitHub webhook triggers Jenkins
2. **Build**: Jenkins builds Docker images
3. **Test**: Automated tests run in containers
4. **Push**: Images uploaded to ECR
5. **Deploy**: CodeDeploy creates green ASG
6. **Health Check**: ALB validates new instances
7. **Traffic Shift**: ALB routes to green environment
8. **Monitor**: Metrics/traces/logs collected continuously

### Monitoring Flow
1. **Application**: Exports metrics at `/metrics`
2. **Prometheus**: Scrapes metrics every 15s
3. **Grafana**: Queries Prometheus for visualization
4. **Alertmanager**: Evaluates rules and sends alerts
5. **Jaeger**: Receives OTLP traces from backend
6. **Loki**: Aggregates logs from Promtail
7. **CloudWatch**: Receives container logs via agent
