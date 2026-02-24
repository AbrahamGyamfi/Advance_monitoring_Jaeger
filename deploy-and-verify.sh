#!/bin/bash
# TaskFlow Deployment and Verification Script

set -euo pipefail

echo "🚀 TaskFlow Complete Deployment & Verification"
echo "=============================================="

# Step 1: Prerequisites Check
echo ""
echo "📋 Step 1: Checking Prerequisites..."
command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform not installed"; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "❌ AWS CLI not installed"; exit 1; }
command -v ssh >/dev/null 2>&1 || { echo "❌ SSH not installed"; exit 1; }

# Check AWS credentials
aws sts get-caller-identity >/dev/null 2>&1 || { echo "❌ AWS credentials not configured"; exit 1; }

# Check SSH key
if [ ! -f ~/.ssh/id_rsa.pub ]; then
    echo "❌ SSH public key not found at ~/.ssh/id_rsa.pub"
    echo "Generate one with: ssh-keygen -t rsa -b 4096"
    exit 1
fi

echo "✅ All prerequisites met"

# Step 2: Deploy Infrastructure
echo ""
echo "🏗️  Step 2: Deploying Infrastructure with Terraform..."
cd terraform
echo "ℹ️  Ensure terraform.tfvars sets admin_cidr_blocks to trusted IP ranges (for SSH/Jenkins/Grafana/Prometheus access)."

# Initialize Terraform
terraform init

# Plan deployment
PLAN_FILE="$(mktemp /tmp/taskflow-tfplan-XXXXXX)"
terraform plan -out="$PLAN_FILE"

# Apply deployment
read -p "Deploy infrastructure? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled"
    exit 0
fi

terraform apply "$PLAN_FILE"
rm -f "$PLAN_FILE"

# Get outputs
JENKINS_IP=$(terraform output -raw jenkins_public_ip)
APP_IP=$(terraform output -raw app_public_ip)
MONITORING_IP=$(terraform output -raw monitoring_public_ip)
PROMETHEUS_URL=$(terraform output -raw prometheus_url)
GRAFANA_URL=$(terraform output -raw grafana_url)
CLOUDTRAIL_BUCKET=$(terraform output -raw cloudtrail_bucket)
GUARDDUTY_ID=$(terraform output -raw guardduty_detector_id)

cd ..

echo ""
echo "✅ Infrastructure Deployed!"
echo "   Jenkins: http://$JENKINS_IP:8080"
echo "   App: http://$APP_IP"
echo "   Prometheus: $PROMETHEUS_URL"
echo "   Grafana: $GRAFANA_URL"

# Step 3: Wait for instances to be ready
echo ""
echo "⏳ Step 3: Waiting for instances to initialize (2 minutes)..."
sleep 120

# Step 4: Verify Services
echo ""
echo "🔍 Step 4: Verifying Services..."

# Check App Health
echo "  Checking App Server..."
if curl -sf http://$APP_IP/health > /dev/null; then
    echo "  ✅ App Server is healthy"
else
    echo "  ⚠️  App Server not responding yet"
fi

# Check App Metrics
echo "  Checking App Metrics..."
if curl -sf http://$APP_IP:5000/metrics > /dev/null; then
    echo "  ✅ App metrics endpoint working"
else
    echo "  ⚠️  App metrics not available yet"
fi

# Check Prometheus
echo "  Checking Prometheus..."
if curl -sf $PROMETHEUS_URL/-/healthy > /dev/null; then
    echo "  ✅ Prometheus is running"
else
    echo "  ⚠️  Prometheus not ready yet"
fi

# Check Grafana
echo "  Checking Grafana..."
if curl -sf $GRAFANA_URL/api/health > /dev/null; then
    echo "  ✅ Grafana is running"
else
    echo "  ⚠️  Grafana not ready yet"
fi

# Step 5: Verify AWS Services
echo ""
echo "🔐 Step 5: Verifying AWS Security Services..."

# Check CloudTrail
echo "  Checking CloudTrail..."
TRAIL_STATUS=$(aws cloudtrail get-trail-status --name taskflow-trail --query 'IsLogging' --output text 2>/dev/null || echo "false")
if [ "$TRAIL_STATUS" = "True" ]; then
    echo "  ✅ CloudTrail is logging"
else
    echo "  ⚠️  CloudTrail not active"
fi

# Check GuardDuty
echo "  Checking GuardDuty..."
GD_STATUS=$(aws guardduty get-detector --detector-id $GUARDDUTY_ID --query 'Status' --output text 2>/dev/null || echo "DISABLED")
if [ "$GD_STATUS" = "ENABLED" ]; then
    echo "  ✅ GuardDuty is enabled"
else
    echo "  ⚠️  GuardDuty not enabled"
fi

# Check CloudWatch Logs
echo "  Checking CloudWatch Logs..."
if aws logs describe-log-groups --log-group-name-prefix /aws/taskflow > /dev/null 2>&1; then
    echo "  ✅ CloudWatch log group exists"
else
    echo "  ⚠️  CloudWatch log group not found"
fi

# Step 6: Generate Test Traffic
echo ""
echo "📊 Step 6: Generating Test Traffic..."
echo "  Creating test tasks..."
for i in {1..10}; do
    curl -sf -X POST http://$APP_IP:5000/api/tasks \
        -H 'Content-Type: application/json' \
        -d "{\"title\":\"Test Task $i\",\"description\":\"Generated for testing\"}" > /dev/null
done
echo "  ✅ Created 10 test tasks"

echo "  Generating some errors..."
for i in {1..5}; do
    curl -sf http://$APP_IP:5000/api/invalid > /dev/null 2>&1 || true
done
echo "  ✅ Generated error traffic"

# Step 7: Display Access Information
echo ""
echo "✅ =============================================="
echo "✅ DEPLOYMENT COMPLETE!"
echo "✅ =============================================="
echo ""
echo "📊 Access URLs:"
echo "   Jenkins:    http://$JENKINS_IP:8080"
echo "   App:        http://$APP_IP"
echo "   Prometheus: $PROMETHEUS_URL"
echo "   Grafana:    $GRAFANA_URL"
echo "   Grafana password retrieval:"
echo "     ssh -i ~/.ssh/id_rsa ec2-user@$MONITORING_IP \"cd ~/monitoring && grep GF_SECURITY_ADMIN_PASSWORD .env\""
echo ""
echo "🔐 Security:"
echo "   CloudTrail Bucket: $CLOUDTRAIL_BUCKET"
echo "   GuardDuty ID:      $GUARDDUTY_ID"
echo ""
echo "📝 Next Steps:"
echo "   1. Access Grafana and create dashboards"
echo "   2. Check Prometheus targets: $PROMETHEUS_URL/targets"
echo "   3. View metrics: http://$APP_IP:5000/metrics"
echo "   4. Check CloudWatch logs: aws logs tail /aws/taskflow/docker --follow"
echo "   5. View CloudTrail events: aws cloudtrail lookup-events --max-results 10"
echo ""
echo "🧹 Cleanup:"
echo "   Run: ./cleanup.sh"
echo ""
