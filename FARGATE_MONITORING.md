# Fargate Monitoring Strategy - Hybrid Approach

## Overview

This project uses a **Hybrid Monitoring Approach** optimized for AWS Fargate, combining:

1. **CloudWatch Container Insights** - Infrastructure metrics (CPU, memory, task health)
2. **Prometheus via ALB** - Application metrics (RED methodology)
3. **Jaeger** - Distributed tracing (unchanged)
4. **Loki** - Centralized logging (unchanged)

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      ECS Fargate Cluster                        │
│  ┌──────────────────┐         ┌─────────────────────┐          │
│  │  Frontend Task   │         │   Backend Task      │          │
│  │  (nginx:80)      │────────▶│   (Node.js:5000)    │          │
│  └──────────────────┘         │   /metrics endpoint │          │
│                                └─────────────────────┘          │
└──────────────┬─────────────────────────┬──────────────────────┘
               │                         │
               │                         │ OTLP traces
               │                         │ (port 4318)
               │                         │
┌──────────────▼─────────────────────────▼──────────────────────┐
│                Application Load Balancer                        │
│  Port 80:  /              → Frontend                           │
│  Port 80:  /api/*         → Backend (API)                      │
│  Port 80:  /api/metrics   → Backend /metrics (Prometheus)      │
└──────────────┬─────────────────────────────────────────────────┘
               │
               │ HTTP scrape every 15s
               │ GET /api/metrics
               │
┌──────────────▼─────────────────────────────────────────────────┐
│              Monitoring EC2 Instance (t3.micro)                 │
│                                                                 │
│  ┌──────────────────┐  ┌──────────────────┐                   │
│  │   Prometheus     │  │   Grafana        │                   │
│  │   :9090          │◀─│   :3000          │                   │
│  │                  │  │                  │                   │
│  │  - App metrics   │  │  Data Sources:   │                   │
│  │    (via ALB)     │  │  - Prometheus    │                   │
│  └──────────────────┘  │  - CloudWatch    │                   │
│                        │  - Jaeger        │                   │
│  ┌──────────────────┐  │  - Loki          │                   │
│  │   Jaeger         │◀─┤                  │                   │
│  │   :16686         │  └──────────────────┘                   │
│  │   :4318 (OTLP)   │                                          │
│  └──────────────────┘  ┌──────────────────┐                   │
│                        │   Loki           │                   │
│  ┌──────────────────┐  │   :3100          │                   │
│  │   Alertmanager   │  └──────────────────┘                   │
│  │   :9093          │                                          │
│  └──────────────────┘                                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ IAM Role
                              │ CloudWatch Read
                              ▼
                    ┌──────────────────────┐
                    │  AWS CloudWatch      │
                    │  Container Insights  │
                    │                      │
                    │  - CPUUtilization    │
                    │  - MemoryUtilization │
                    │  - TaskCount         │
                    │  - NetworkIO         │
                    └──────────────────────┘
```

---

## Component Details

### 1. Application Metrics (Prometheus)

**Scrape Method:** HTTP via ALB  
**Endpoint:** `http://<ALB-DNS>:80/api/metrics`  
**Config:** `monitoring/config/prometheus.yml`

```yaml
scrape_configs:
  - job_name: 'taskflow-backend-fargate'
    static_configs:
      - targets: ['${ALB_DNS_NAME}']
    metrics_path: '/api/metrics'
    scrape_interval: 15s
```

**Metrics Collected:**
- `taskflow_http_requests_total` (Counter)
- `taskflow_http_errors_total` (Counter)
- `taskflow_http_request_duration_seconds` (Histogram)
- `taskflow_tasks_total` (Gauge)
- Node.js process metrics (CPU, memory, event loop)

**Why ALB?**
- ✅ Fargate tasks have dynamic IPs
- ✅ No need for ECS service discovery
- ✅ Simple configuration
- ⚠️ Only scrapes one task (load balanced)

---

### 2. Infrastructure Metrics (CloudWatch Container Insights)

**Enable Command:**
```bash
chmod +x scripts/enable-container-insights.sh
./scripts/enable-container-insights.sh
```

**Namespace:** `ECS/ContainerInsights`

**Metrics Available:**
| Metric | Description | Dimension |
|--------|-------------|-----------|
| `CPUUtilization` | Task CPU usage % | ClusterName, ServiceName |
| `MemoryUtilization` | Task memory usage % | ClusterName, ServiceName |
| `TaskCount` | Number of running tasks | ClusterName, ServiceName |
| `NetworkRxBytes` | Network bytes received | ClusterName, ServiceName |
| `NetworkTxBytes` | Network bytes transmitted | ClusterName, ServiceName |
| `StorageReadBytes` | Disk read bytes | ClusterName, ServiceName |
| `StorageWriteBytes` | Disk write bytes | ClusterName, ServiceName |

**Access in Grafana:**
- Data Source: CloudWatch
- Region: `eu-west-1`
- Auth: IAM Role (automatic via EC2 instance profile)

**Cost:** ~$0.50/task/month

---

### 3. Distributed Tracing (Jaeger)

**No Changes Required** - Works seamlessly with Fargate

**Backend Configuration:**
```javascript
// backend/telemetry.js
const OTEL_ENDPOINT = process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://monitoring-host:4318';
```

**Task Definition:**
```json
{
  "environment": [
    {
      "name": "OTEL_EXPORTER_OTLP_ENDPOINT",
      "value": "http://<monitoring-private-ip>:4318"
    }
  ]
}
```

---

### 4. Centralized Logging (Loki + Promtail)

**Logs sent to:** CloudWatch Logs (ECS native)  
**Log Groups:**
- `/ecs/taskflow-frontend`
- `/ecs/taskflow-backend`

**Alternative:** Ship directly to Loki using Promtail sidecar (not implemented)

---

## Configuration Files Changed

### 1. Prometheus Config
**File:** `monitoring/config/prometheus.yml`

**Changes:**
- ❌ Removed: `job_name: 'taskflow-backend'` with static IP
- ❌ Removed: `job_name: 'node-exporter'` (no EC2 host)
- ✅ Added: `job_name: 'taskflow-backend-fargate'` with ALB scraping

### 2. Nginx Config
**File:** `frontend/nginx.conf`

**Changes:**
- ✅ Added: `/api/metrics` location block that proxies to backend `/metrics`

```nginx
location /api/metrics {
    resolver 169.254.169.253 valid=10s;
    set $backend "taskflow-backend.taskflow.local:5000";
    proxy_pass http://$backend/metrics;
}
```

### 3. Grafana Datasources
**File:** `monitoring/config/grafana-datasource.yml`

**Changes:**
- ✅ Added: CloudWatch datasource with IAM role authentication

```yaml
- name: CloudWatch
  type: cloudwatch
  uid: cloudwatch
  jsonData:
    authType: default
    defaultRegion: eu-west-1
```

### 4. Terraform Monitoring Module
**File:** `terraform/modules/monitoring/main.tf`

**Changes:**
- ✅ Added variable: `alb_dns_name`
- ✅ Provisioner now uses `${ALB_DNS_NAME}` instead of `${APP_PRIVATE_IP}`
- ✅ IAM role has CloudWatch read permissions

### 5. IAM Permissions
**File:** `terraform/modules/security/main.tf`

**Changes:**
- ✅ Added: `cloudwatch_read` policy for Grafana datasource

Permissions granted:
- `cloudwatch:ListMetrics`
- `cloudwatch:GetMetricStatistics`
- `cloudwatch:GetMetricData`
- `logs:DescribeLogGroups`
- `logs:GetLogEvents`
- `ec2:DescribeTags` (for Container Insights)

---

## Deployment Steps

### Initial Setup

1. **Enable Container Insights:**
   ```bash
   cd scripts
   chmod +x enable-container-insights.sh
   ./enable-container-insights.sh
   ```

2. **Apply Terraform Changes:**
   ```bash
   cd terraform
   terraform plan
   terraform apply
   ```

3. **Verify Monitoring Stack:**
   ```bash
   # Check Prometheus targets
   curl http://<monitoring-ip>:9090/targets
   
   # Check Grafana datasources
   curl http://<monitoring-ip>:3000/api/datasources
   ```

### Post-Deployment Verification

1. **Prometheus Scraping:**
   ```bash
   # Test metrics endpoint through ALB
   curl http://<alb-dns>/api/metrics
   
   # Should return Prometheus-formatted metrics
   ```

2. **CloudWatch Container Insights:**
   ```bash
   # Verify Container Insights enabled
   aws ecs describe-clusters \
     --clusters taskflow-cluster \
     --include SETTINGS \
     --query 'clusters[0].settings'
   
   # Check available metrics
   aws cloudwatch list-metrics \
     --namespace ECS/ContainerInsights \
     --dimensions Name=ClusterName,Value=taskflow-cluster
   ```

3. **Grafana Dashboards:**
   - Access: `http://<monitoring-ip>:3000`
   - Check all datasources are green
   - Import Container Insights dashboard (AWS ID: 10566)

---

## Monitoring Dashboards

### Application Metrics (Prometheus)

**Queries:**
```promql
# Request rate
rate(taskflow_http_requests_total[5m])

# Error rate %
(rate(taskflow_http_errors_total[5m]) / rate(taskflow_http_requests_total[5m])) * 100

# P95 latency
histogram_quantile(0.95, rate(taskflow_http_request_duration_seconds_bucket[5m]))
```

### Infrastructure Metrics (CloudWatch)

**Queries:**
```sql
-- CPU Utilization
SELECT AVG(CPUUtilization) 
FROM SCHEMA("ECS/ContainerInsights", ClusterName,ServiceName)
WHERE ClusterName = 'taskflow-cluster'

-- Memory Utilization
SELECT AVG(MemoryUtilization)
FROM SCHEMA("ECS/ContainerInsights", ClusterName,ServiceName)
WHERE ServiceName = 'taskflow-backend'
```

---

## Alert Rules (Unchanged)

**File:** `monitoring/config/alert_rules.yml`

All existing alerts still work:
- ✅ `TaskflowHighErrorRate` (error rate > 5%)
- ✅ `TaskflowHighLatency` (p95 > 300ms)
- ⚠️ `TaskflowServiceDown` - Now checks ALB endpoint

---

## Advantages of Hybrid Approach

| Aspect | Benefit |
|--------|---------|
| **Application Metrics** | Custom business metrics (tasks, requests, errors) |
| **Infrastructure Metrics** | AWS-native, no configuration, automatic |
| **Cost Efficient** | Only pays for Container Insights (~$0.50/task) |
| **Scalability** | Works with auto-scaling Fargate tasks |
| **Simplicity** | No ECS service discovery, no dynamic config |
| **Completeness** | Both app and infra metrics in one place |

---

## Limitations & Considerations

### ⚠️ Single Task Scraping
**Issue:** Prometheus scrapes via ALB, which load-balances to one task  
**Impact:** Metrics represent one task, not aggregated across all tasks  
**Workaround:** CloudWatch Container Insights provides cluster-wide view

### ⚠️ No Host-Level Metrics
**Issue:** Node exporter removed (no EC2 hosts in Fargate)  
**Impact:** Can't monitor disk I/O, system load  
**Alternative:** Use CloudWatch Container Insights storage metrics

### ⚠️ Cost Awareness
**Container Insights:** $0.50/task/month  
**CloudWatch Logs:** $0.50/GB ingested  
**Total Estimated:** ~$5-10/month for this project

---

## Troubleshooting

### Prometheus Not Scraping
```bash
# Check ALB is accessible from monitoring server
curl -I http://<alb-dns>/api/metrics

# Check Prometheus targets page
curl http://<monitoring-ip>:9090/api/v1/targets
```

### CloudWatch Datasource Not Working
```bash
# Verify IAM role permissions
aws sts get-caller-identity

# Test CloudWatch API
aws cloudwatch list-metrics \
  --namespace ECS/ContainerInsights \
  --region eu-west-1
```

### Container Insights Not Showing Data
```bash
# Verify enabled at cluster level
aws ecs describe-clusters \
  --clusters taskflow-cluster \
  --include SETTINGS

# Wait 5-10 minutes for first metrics
```

---

## Future Improvements

1. **ECS Service Discovery for Prometheus**
   - Use `ec2_sd_configs` to scrape all Fargate tasks
   - Requires IAM permissions: `ecs:DescribeTasks`, `ec2:DescribeInstances`

2. **Loki Direct Shipping**
   - Deploy Promtail as sidecar in Fargate tasks
   - Skip CloudWatch Logs (cost savings)

3. **X-Ray Integration**
   - Enable AWS X-Ray for serverless tracing
   - Complements Jaeger for AWS service calls

4. **Custom CloudWatch Metrics**
   - Push business metrics from application
   - Use `PutMetricData` API

---

## References

- [AWS Container Insights Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html)
- [Prometheus Configuration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)
- [Grafana CloudWatch Datasource](https://grafana.com/docs/grafana/latest/datasources/aws-cloudwatch/)
- [OpenTelemetry Fargate Setup](https://aws-otel.github.io/docs/setup/ecs)
