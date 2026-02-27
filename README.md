<div align="center">

# TaskFlow - Enterprise Observability & Security Stack

### Production-Ready Task Management with Complete Monitoring Infrastructure

[![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=for-the-badge&logo=terraform)](https://www.terraform.io/)
[![Jenkins](https://img.shields.io/badge/CI%2FCD-Jenkins-D24939?style=for-the-badge&logo=jenkins)](https://jenkins.io/)
[![Docker](https://img.shields.io/badge/Container-Docker-2496ED?style=for-the-badge&logo=docker)](https://www.docker.com/)
[![AWS](https://img.shields.io/badge/Cloud-AWS-FF9900?style=for-the-badge&logo=amazon-aws)](https://aws.amazon.com/)
[![Prometheus](https://img.shields.io/badge/Monitoring-Prometheus-E6522C?style=for-the-badge&logo=prometheus)](https://prometheus.io/)
[![Grafana](https://img.shields.io/badge/Visualization-Grafana-F46800?style=for-the-badge&logo=grafana)](https://grafana.com/)

[Features](#key-features) • [Architecture](#architecture) • [Quick Start](#quick-start) • [Documentation](#documentation) • [Screenshots](#live-deployment)

</div>

---

## Overview

TaskFlow is a production-grade task management application demonstrating enterprise DevOps practices with comprehensive observability, security, and automation. Built as a reference implementation for cloud-native application deployment on AWS.

### Key Features

**Infrastructure & Automation**
- Modular Terraform infrastructure (5 specialized modules)
- Jenkins CI/CD with 8-stage declarative pipeline
- Multi-stage Docker builds (56% smaller images)
- Parallel build execution and Docker layer caching
- Automated testing with 31 unit tests

**Observability Stack**
- Prometheus metrics with RED methodology
- Grafana dashboards with 16+ visualization panels
- Distributed tracing via OpenTelemetry and Jaeger
- Log aggregation with Loki and Promtail
- Alertmanager with configured SLO-based alerts

**Security & Compliance**
- AWS CloudWatch Logs for centralized logging
- CloudTrail audit logging with 90-day retention
- GuardDuty threat detection
- Non-root container execution
- IAM roles with least-privilege access

## Architecture

```
┌──────────────────┐
│  Jenkins Server  │
│  - CI/CD         │
│  - Pipeline      │
└────────┬─────────┘
         │ Deploy
         ▼
┌──────────────────────────────────────────────────────────┐
│              App Server (Single Host)                     │
│  ┌─────────────────┐  ┌──────────────────┐              │
│  │ Application     │  │ Monitoring Stack │              │
│  │ - Backend       │  │ - Prometheus     │              │
│  │ - Frontend      │  │ - Grafana        │              │
│  │ - Node Exporter │  │ - Jaeger         │              │
│  └─────────────────┘  │ - Loki           │              │
│                       │ - Alertmanager   │              │
│                       └──────────────────┘              │
└────────────────────────┬─────────────────────────────────┘
                         │
                         ▼
                  ┌─────────────────┐
                  │  AWS Services   │
                  │  - CloudWatch   │
                  │  - CloudTrail   │
                  │  - GuardDuty    │
                  │  - ECR          │
                  └─────────────────┘
```

## Technology Stack

### Application Layer
- **Frontend**: React 18.2, Nginx (Alpine), non-root execution
- **Backend**: Node.js 18, Express 4.18, non-root execution
- **Testing**: Jest 29.5 (23 backend + 8 frontend tests)

### Infrastructure & DevOps
- **IaC**: Terraform 1.0+ with modular architecture
- **CI/CD**: Jenkins declarative pipeline with parallel stages
- **Containers**: Docker multi-stage builds, Docker Compose 3.8
- **Cloud**: AWS (EC2, ECR, S3, IAM, CloudWatch)
- **Registry**: AWS ECR with automated image tagging

### Observability Stack
- **Metrics**: Prometheus 2.54, Node Exporter 1.8
- **Tracing**: OpenTelemetry SDK 0.53, Jaeger 1.58
- **Logging**: Loki 3.1.1, Promtail, CloudWatch Logs
- **Visualization**: Grafana 11.1 with provisioned dashboards
- **Alerting**: Alertmanager 0.27 with SLO-based rules

## Quick Start

### Prerequisites
- Terraform >= 1.0
- AWS CLI configured
- SSH key pair (`~/.ssh/id_rsa.pub`)
- Docker & Docker Compose
- `terraform.tfvars` with `admin_cidr_blocks` set to trusted source IPs (for SSH/Jenkins/Grafana/Prometheus access)

### 1. Configure Terraform Variables
```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with your admin_cidr_blocks
```

### 2. Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 3. Configure Jenkins
```bash
# Get Jenkins initial password
ssh -i ~/.ssh/id_rsa ec2-user@<JENKINS_IP>
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# Access Jenkins at http://<JENKINS_IP>:8080
# Install suggested plugins and configure credentials
```

### 4. Access Services
- **Application**: http://APP_IP
- **Grafana**: http://APP_IP:3000 (admin / see monitoring/.env)
- **Prometheus**: http://APP_IP:9090
- **Jaeger**: http://APP_IP:16686
- **Alertmanager**: http://APP_IP:9093
- **Jenkins**: http://JENKINS_IP:8080

## Terraform Infrastructure

### Modular Structure
```
terraform/
├── main.tf                    # Root module
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
└── modules/
    ├── networking/            # Security groups, SSH keys
    ├── compute/               # EC2 instances
    ├── deployment/            # App deployment provisioner
    ├── monitoring/            # Prometheus + Grafana
    └── security/              # CloudTrail, GuardDuty, IAM
```

### Resources Provisioned
- 3 EC2 instances (Jenkins, App, Monitoring)
- Security group with required ports
- IAM roles for CloudWatch
- S3 bucket for CloudTrail logs (encrypted, 90-day lifecycle)
- CloudWatch log groups
- Imported existing CloudTrail and GuardDuty

## Observability Stack

### Infrastructure Monitoring

![Infrastructure Dashboard](Screenshots/Grafana_dashboard.png)
*System metrics: CPU, memory, disk I/O, and network utilization*

### Metrics Exposed

![Metrics Endpoint](Screenshots/metrics_endpoint.png)
*Prometheus-format metrics exposed at `/metrics` endpoint*

The backend exports OpenTelemetry traces and RED metrics:

| Signal | Name | Description |
|--------|------|-------------|
| Traces | `taskflow-backend` service spans | HTTP server and HTTP client spans exported to Jaeger OTLP |
| Counter | `taskflow_http_requests_total` | Total HTTP requests by `method`, `route`, `status_code` |
| Counter | `taskflow_http_errors_total` | Total 4xx/5xx responses by `method`, `route`, `status_code` |
| Histogram | `taskflow_http_request_duration_seconds` | Request duration buckets for latency SLOs |
| Gauge | `taskflow_tasks_total` | Current number of in-memory tasks |
| Process metrics | `taskflow_process_*` | Node.js/process runtime metrics from `prom-client` |

| Target | Endpoint | Status | Scrape Interval |
|--------|----------|--------|----------------|
| **taskflow-backend** | `APP_SERVER_IP:5000/metrics` | UP | 15s |
| **node-exporter** | `APP_SERVER_IP:9100/metrics` | UP | 15s |
| **prometheus** | `localhost:9090` | UP | 15s |

### Alerts Configured

![Alert Rules](./monitoring/config/alert_rules.yml)
*Configured alert rules in Prometheus*

| Alert | Condition | Duration | Severity |
|-------|-----------|----------|----------|
| **TaskflowHighErrorRate** | Error rate > 5% | 10 minutes | Critical |
| **TaskflowHighLatency** | p95 latency > 300ms | 10 minutes | Critical |
| **TaskflowServiceDown** | Backend unreachable | 1 minute | Critical |

### Grafana Dashboards
Provisioned dashboard: `TaskFlow Observability` (`monitoring/dashboards/taskflow-observability.json`)

Dashboard coverage:
- RED: request rate, error rate, p95 latency
- Infrastructure: CPU and memory
- Correlation: Loki error logs with `trace_id`/`span_id`, clickable trace links into Jaeger

Core PromQL queries:
```promql
# Request Rate
sum(rate(taskflow_http_requests_total{route!="/metrics"}[5m]))

# Error Rate
100 * sum(rate(taskflow_http_errors_total{route!="/metrics"}[5m])) / clamp_min(sum(rate(taskflow_http_requests_total{route!="/metrics"}[5m])), 0.001)

# p95 Latency (ms)
histogram_quantile(0.95, sum(rate(taskflow_http_request_duration_seconds_bucket{route!="/metrics"}[5m])) by (le)) * 1000

# System Metrics (from Node Exporter)
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))
```

## Security Implementation

### CloudWatch Logs

![CloudWatch Logs](/Screenshots/Cloudwatch-logs.png)
*Docker container logs streaming to CloudWatch*

- **Log Group**: `/aws/taskflow/docker`
- **Retention**: 7 days
- **Streams**: taskflow-backend-prod, taskflow-frontend-prod
- **IAM Role**: Attached to EC2 instances for secure log delivery

### CloudTrail

![CloudTrail Events](Screenshots/Cloudtrail_events.png)
*AWS API audit trail showing recent events*

- **Trail Name**: `taskflow-trail`
- **S3 Bucket**: `taskflow-cloudtrail-logs`
- **Encryption**: AES256 server-side encryption
- **Lifecycle**: 90-day retention policy
- **Coverage**: Multi-region trail enabled
- **Events**: EC2, S3, IAM, ECR API calls tracked

### GuardDuty

![GuardDuty Dashboard](/Screenshots/GuardDutyFinding.png)
*GuardDuty threat detection enabled*

- **Detector ID**: `8eccab93586c4b21dc5166f92a396f54`
- **Status**: Enabled and monitoring
- **Coverage**: VPC Flow Logs, CloudTrail events, DNS logs
- **Findings**: Real-time threat detection and alerts

## CI/CD Pipeline

![Jenkins Pipeline](/Screenshots/pipeline-success.png)
*Jenkins CI/CD pipeline with 8 automated stages*

### Jenkins Pipeline Stages
1. **Checkout** - Clone from GitHub
2. **Build** - Docker images (parallel)
3. **Test** - Unit tests in containers
4. **Quality** - ESLint + image verification
5. **Integration** - API endpoint tests
6. **Push** - Upload to ECR
7. **Deploy** - SSH to EC2 with docker-compose
8. **Health Check** - Verify deployment

### Pipeline Optimizations
- **Docker Layer Caching**: 40% faster builds (20min → 12min)
- **Parallel Execution**: Build, test, and push stages run concurrently
- **Multi-stage Builds**: 56% smaller images (330MB → 145MB)
- **Resource Limits**: CPU and memory constraints prevent OOM kills

### Test Coverage
```bash
# Backend (23 tests)
- Health checks, CRUD operations, metrics endpoint
- Error handling, CORS, validation, filtering
- Performance and load testing

# Frontend (8 tests)
- Component rendering, task loading
- Error handling, filter functionality
- Form elements and user interactions
```

## API Endpoints

### Application
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/tasks` | Create new task |
| GET | `/api/tasks` | List all tasks |
| GET | `/api/tasks?status=completed` | Filter tasks by status |
| PATCH | `/api/tasks/:id` | Update task status |
| PUT | `/api/tasks/:id` | Edit task details |
| DELETE | `/api/tasks/:id` | Delete task |

### Observability
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check endpoint |
| GET | `/metrics` | Prometheus metrics (RED + process) |
| GET | `/api/system/overview` | Generate distributed traces |

## Verification & Testing

### Test Metrics Endpoint
```bash
curl http://APP_IP:5000/metrics
```

### Validate Observability Stack
```bash
./monitoring/validate-observability.sh \
  --app-url http://APP_IP:5000 \
  --prom-url http://APP_IP:9090 \
  --alert-url http://APP_IP:9093 \
  --jaeger-url http://APP_IP:16686 \
  --loki-url http://APP_IP:3100 \
  --duration-minutes 12
```

**Validation Steps:**
1. Generates sustained latency (450ms) and error traffic (25% error rate)
2. Verifies Prometheus alerts fire for high error rate and latency
3. Extracts `trace_id` and `span_id` from Loki logs
4. Confirms trace exists in Jaeger with matching trace_id
5. Validates alert → trace → log correlation

### Check CloudWatch Logs
```bash
aws logs tail /aws/taskflow/docker --follow
```

### Check CloudTrail
```bash
aws cloudtrail lookup-events --max-results 10
```

### Check GuardDuty
```bash
aws guardduty list-detectors
aws guardduty list-findings --detector-id DETECTOR_ID
```

## Cleanup

```bash
./cleanup.sh
# OR
cd terraform && terraform destroy
```

## Project Structure

```text
.
├── terraform/                 # Infrastructure as Code
│   ├── modules/
│   │   ├── networking/        # Security groups, SSH keys
│   │   ├── compute/           # EC2 instances
│   │   ├── deployment/        # Application provisioning
│   │   ├── monitoring/        # Observability stack setup
│   │   └── security/          # CloudTrail, GuardDuty, IAM
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── backend/                   # Node.js Express API
│   ├── app.js                 # Routes, middleware, metrics
│   ├── server.js              # HTTP server entrypoint
│   ├── telemetry.js           # OpenTelemetry tracing setup
│   ├── metrics.js             # Prometheus metrics definitions
│   ├── logger.js              # Structured logging with trace context
│   ├── server.test.js         # 23 unit tests
│   └── Dockerfile             # Multi-stage build
├── frontend/                  # React 18 application
│   ├── src/
│   │   ├── App.js
│   │   └── App.test.js        # 8 component tests
│   ├── nginx.conf             # Reverse proxy configuration
│   └── Dockerfile             # Multi-stage build
├── monitoring/                # Observability configuration
│   ├── config/
│   │   ├── prometheus.yml     # Scrape configs
│   │   ├── alert_rules.yml    # SLO-based alerts
│   │   ├── alertmanager.yml   # Alert routing
│   │   ├── loki-config.yml    # Log aggregation
│   │   └── grafana-datasource.yml
│   ├── dashboards/
│   │   └── taskflow-observability.json
│   └── validate-observability.sh
├── userdata/                  # EC2 cloud-init scripts
│   ├── jenkins-userdata.sh
│   ├── app-userdata.sh
│   └── monitoring-userdata.sh
├── docker-compose.yml         # Unified deployment configuration
├── Jenkinsfile                # Declarative CI/CD pipeline
└── README.md
```

## Cost Analysis

Monthly AWS costs (approximate):
- EC2 t3.micro (App): ~$7
- EC2 t3.micro (Jenkins): ~$7
- EC2 t3.small (Monitoring): ~$15
- CloudWatch Logs: ~$2
- CloudTrail: ~$2
- GuardDuty: ~$5
- S3 Storage: ~$1
- **Total**: ~$39/month

## Technical Highlights

### Infrastructure as Code
- Modular Terraform with 5 specialized modules
- Automated provisioning of 3 EC2 instances
- Security groups with least-privilege access
- IAM roles for service-to-service authentication

### Observability Implementation
- RED metrics (Rate, Errors, Duration) methodology
- Distributed tracing with OpenTelemetry and Jaeger
- Log aggregation with trace correlation
- SLO-based alerting (5% error rate, 300ms p95 latency)
- 15-day metrics retention with 5GB storage limit

### CI/CD Best Practices
- Declarative Jenkins pipeline with 8 stages
- Parallel execution for independent tasks
- Docker layer caching for faster builds
- Containerized testing for consistency
- Automated health checks post-deployment

### Security Measures
- Non-root container execution
- AWS CloudTrail audit logging (90-day retention)
- GuardDuty threat detection
- Encrypted S3 buckets for logs
- Security headers in Nginx configuration

## Credentials

### Grafana
Password is auto-generated during deployment:
```bash
ssh -i ~/.ssh/id_rsa ec2-user@APP_IP
cat ~/monitoring/.env | grep GF_SECURITY_ADMIN_PASSWORD
```

### Jenkins
Initial admin password:
```bash
ssh -i ~/.ssh/id_rsa ec2-user@JENKINS_IP
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### Required Jenkins Credentials
- `aws-credentials`: AWS Access Key ID and Secret
- `aws-region`: eu-west-1
- `aws-account-id`: Your AWS account ID
- `app-server-ip`: Public IP of app server
- `app-private-ip`: Private IP of app server
- `app-server-ssh`: SSH private key for EC2 access

## Troubleshooting

### Prometheus Not Scraping
```bash
# Check connectivity from monitoring server
ssh -i ~/.ssh/id_rsa ec2-user@MONITORING_IP
curl http://APP_IP:5000/metrics
```

### App Not Running
```bash
# Check containers on app server
ssh -i ~/.ssh/id_rsa ec2-user@APP_IP
docker ps
docker logs taskflow-backend-prod
```

### CloudWatch Logs Missing
```bash
# Verify IAM role attached
aws ec2 describe-instances --instance-ids INSTANCE_ID \
  --query 'Reservations[0].Instances[0].IamInstanceProfile'
```

## Performance Metrics

### Application Performance
- **Average Response Time**: ~50ms
- **Request Rate**: ~4 req/min (baseline)
- **Error Rate**: 0%
- **Uptime**: 99.9%

### Infrastructure Utilization
- **CPU Usage**: 5-10% average
- **Memory Usage**: 45% (2GB total)
- **Disk Usage**: 25% (8GB volume)
- **Network**: <1 Mbps

## Documentation

- **[Project Report](PROJECT_REPORT.md)** - Comprehensive 2-page implementation report
- **[deploy-and-verify.sh](deploy-and-verify.sh)** - End-to-end deployment and verification workflow
- **[cleanup.sh](cleanup.sh)** - Controlled resource cleanup script

## Contributing

This is an educational project demonstrating DevOps best practices. Feel free to fork and adapt for your learning purposes.

## License

MIT License - Educational Project

## Author

**Abraham Gyamfi**  
DevOps Engineer | Cloud Infrastructure Specialist

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-blue?style=flat&logo=linkedin)](https://linkedin.com/in/yourprofile)
[![GitHub](https://img.shields.io/badge/GitHub-Follow-black?style=flat&logo=github)](https://github.com/AbrahamGyamfi)

---

<div align="center">

### If you found this project helpful, please consider giving it a star!

**Version**: 2.0.0 | **Last Updated**: February 2026

[Back to Top](#taskflow---enterprise-observability--security-stack)

</div>
