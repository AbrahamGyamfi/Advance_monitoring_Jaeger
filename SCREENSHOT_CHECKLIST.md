# TaskFlow Screenshot Checklist

## 📸 Screenshots to Capture

### 1. Application Frontend
**URL**: http://54.229.200.238  
**Screenshot**: Main task management interface  
**Actions**:
- Show the task list with the 2 tasks we created
- Capture the UI with tasks visible
- Save as: `Screenshots/frontend-taskflow-ui.png`

---

### 2. Jenkins Pipeline
**URL**: http://54.246.252.212:8080  
**Credentials**: Admin / Solution/17  
**Screenshots**:
- **Pipeline Overview**: Build #9 success status
  - Save as: `Screenshots/jenkins-pipeline-success.png`
- **Pipeline Stages**: All 8 stages with green checkmarks
  - Save as: `Screenshots/jenkins-pipeline-stages.png`
- **Console Output**: Final success message
  - Save as: `Screenshots/jenkins-console-output.png`

---

### 3. Grafana Dashboards
**URL**: http://54.73.185.215:3000  
**Credentials**: admin / g+F2D4jSpJy+vqrd4T7WZ5NFmbIEtCo/XXVM9b3Z2ug  
**Screenshots**:
- **Login Page** (optional)
- **TaskFlow Observability Dashboard**:
  - Full dashboard view showing all panels
  - Save as: `Screenshots/grafana-dashboard-overview.png`
- **RED Metrics Panel**: Request rate, error rate, latency
  - Save as: `Screenshots/grafana-red-metrics.png`
- **Infrastructure Metrics**: CPU, Memory usage
  - Save as: `Screenshots/grafana-infrastructure-metrics.png`
- **Data Sources**: Show Prometheus, Loki, Jaeger configured
  - Navigate to: Configuration → Data Sources
  - Save as: `Screenshots/grafana-datasources.png`

---

### 4. Prometheus
**URL**: http://54.73.185.215:9090  
**Screenshots**:
- **Targets Page**: Status → Targets
  - Show all 3 targets UP (taskflow-backend, node-exporter, prometheus)
  - Save as: `Screenshots/prometheus-targets.png`
- **Metrics Query**: Graph view
  - Query: `rate(taskflow_http_requests_total[5m])`
  - Save as: `Screenshots/prometheus-metrics-query.png`
- **Alerts Page**: Alerts → Show configured alert rules
  - Save as: `Screenshots/prometheus-alert-rules.png`

---

### 5. Jaeger Tracing
**URL**: http://54.73.185.215:16686  
**Screenshots**:
- **Service Selection**: Show "taskflow-backend" service
  - Save as: `Screenshots/jaeger-service-list.png`
- **Trace View**: Select a trace from /api/system/overview
  - Show the distributed trace with spans
  - Save as: `Screenshots/jaeger-trace-details.png`
- **Trace Timeline**: Expanded view showing HTTP spans
  - Save as: `Screenshots/jaeger-trace-timeline.png`

---

### 6. Alertmanager
**URL**: http://54.73.185.215:9093  
**Screenshots**:
- **Alerts Page**: Show configured alerts (even if no active alerts)
  - Save as: `Screenshots/alertmanager-dashboard.png`
- **Silences**: Show silences page
  - Save as: `Screenshots/alertmanager-silences.png` (optional)

---

### 7. AWS CloudWatch Logs
**AWS Console**: https://eu-west-1.console.aws.amazon.com/cloudwatch/home?region=eu-west-1#logsV2:log-groups  
**Screenshots**:
- **Log Groups**: Show /aws/taskflow/docker log group
  - Save as: `Screenshots/cloudwatch-log-groups.png`
- **Log Streams**: Show taskflow-backend-prod and taskflow-frontend-prod
  - Save as: `Screenshots/cloudwatch-log-streams.png`
- **Log Events**: Show recent log entries with timestamps
  - Save as: `Screenshots/cloudwatch-log-events.png`

---

### 8. AWS CloudTrail
**AWS Console**: https://eu-west-1.console.aws.amazon.com/cloudtrail/home?region=eu-west-1#/events  
**Screenshots**:
- **Event History**: Show recent API calls
  - Save as: `Screenshots/cloudtrail-events.png`
- **Trail Details**: Show taskflow-trail configuration
  - Navigate to: Trails → taskflow-trail
  - Save as: `Screenshots/cloudtrail-trail-config.png`

---

### 9. AWS GuardDuty
**AWS Console**: https://eu-west-1.console.aws.amazon.com/guardduty/home?region=eu-west-1#/findings  
**Screenshots**:
- **Dashboard**: Show GuardDuty enabled status
  - Save as: `Screenshots/guardduty-dashboard.png`
- **Findings**: Show findings page (even if empty)
  - Save as: `Screenshots/guardduty-findings.png`

---

### 10. AWS ECR
**AWS Console**: https://eu-west-1.console.aws.amazon.com/ecr/repositories?region=eu-west-1  
**Screenshots**:
- **Repositories**: Show taskflow-backend and taskflow-frontend repos
  - Save as: `Screenshots/ecr-repositories.png`
- **Images**: Click on taskflow-backend, show image tags (9, latest)
  - Save as: `Screenshots/ecr-backend-images.png`

---

### 11. Terraform Outputs (Terminal)
**Command**: 
```bash
cd "/home/ab/ Advanced Observability/terraform"
terraform output
```
**Screenshot**: Terminal showing all outputs
- Save as: `Screenshots/terraform-outputs.png`

---

### 12. Application Metrics Endpoint (Terminal)
**Command**:
```bash
ssh -i ~/.ssh/id_rsa ec2-user@54.229.200.238 'curl -s http://localhost:5000/metrics | head -50'
```
**Screenshot**: Terminal showing Prometheus metrics
- Save as: `Screenshots/metrics-endpoint.png`

---

### 13. Docker Containers (Terminal)
**Commands**:
```bash
# App Server
ssh -i ~/.ssh/id_rsa ec2-user@54.229.200.238 'docker ps'

# Monitoring Server
ssh -i ~/.ssh/id_rsa ec2-user@54.73.185.215 'cd ~/monitoring && docker-compose ps'
```
**Screenshots**: 
- Save as: `Screenshots/docker-containers-app.png`
- Save as: `Screenshots/docker-containers-monitoring.png`

---

## 📋 Quick Access URLs

Copy these to your browser:

```
Frontend:        http://54.229.200.238
Jenkins:         http://54.246.252.212:8080
Grafana:         http://54.73.185.215:3000
Prometheus:      http://54.73.185.215:9090
Jaeger:          http://54.73.185.215:16686
Alertmanager:    http://54.73.185.215:9093
```

## 🔐 Credentials Quick Reference

```
Jenkins:    Admin / Solution/17
Grafana:    admin / g+F2D4jSpJy+vqrd4T7WZ5NFmbIEtCo/XXVM9b3Z2ug
AWS:        (Your AWS Console credentials)
```

## ✅ Screenshot Checklist Progress

- [ ] 1. Application Frontend
- [ ] 2. Jenkins Pipeline (3 screenshots)
- [ ] 3. Grafana Dashboards (4 screenshots)
- [ ] 4. Prometheus (3 screenshots)
- [ ] 5. Jaeger Tracing (3 screenshots)
- [ ] 6. Alertmanager (1-2 screenshots)
- [ ] 7. CloudWatch Logs (3 screenshots)
- [ ] 8. CloudTrail (2 screenshots)
- [ ] 9. GuardDuty (2 screenshots)
- [ ] 10. ECR (2 screenshots)
- [ ] 11. Terraform Outputs (1 screenshot)
- [ ] 12. Metrics Endpoint (1 screenshot)
- [ ] 13. Docker Containers (2 screenshots)

**Total**: ~25-27 screenshots

---

## 💡 Tips

1. **Use Full Screen**: Maximize browser windows for cleaner screenshots
2. **Hide Sensitive Data**: Be careful with AWS account IDs if sharing publicly
3. **Consistent Naming**: Follow the naming convention above
4. **High Resolution**: Use high-quality screenshots for documentation
5. **Annotations**: Consider adding arrows/highlights to important areas

---

## 🚀 After Screenshots

Once you have all screenshots:
1. Review each one for clarity
2. Update README.md with new screenshot references
3. Commit everything to Git
4. Proceed with Option 2 & 3 enhancements
