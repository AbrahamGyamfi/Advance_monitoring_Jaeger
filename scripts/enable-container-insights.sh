#!/bin/bash
set -euo pipefail

# Enable CloudWatch Container Insights for ECS Fargate
# This provides automatic infrastructure metrics for Fargate tasks

REGION="${AWS_REGION:-eu-west-1}"
CLUSTER_NAME="${CLUSTER_NAME:-taskflow-cluster}"

echo "================================================"
echo "Enabling CloudWatch Container Insights"
echo "================================================"
echo "Region: $REGION"
echo "Cluster: $CLUSTER_NAME"
echo ""

# Enable Container Insights at account level (one-time setup)
echo "1. Enabling Container Insights at account level..."
aws ecs put-account-setting \
  --name "containerInsights" \
  --value "enabled" \
  --region "$REGION" 2>/dev/null || echo "   (Already enabled at account level)"

# Enable Container Insights for the specific cluster
echo "2. Enabling Container Insights for cluster: $CLUSTER_NAME..."
aws ecs update-cluster-settings \
  --cluster "$CLUSTER_NAME" \
  --settings name=containerInsights,value=enabled \
  --region "$REGION"

# Verify the setting
echo "3. Verifying Container Insights status..."
INSIGHTS_STATUS=$(aws ecs describe-clusters \
  --clusters "$CLUSTER_NAME" \
  --region "$REGION" \
  --include SETTINGS \
  --query 'clusters[0].settings[?name==`containerInsights`].value' \
  --output text)

if [ "$INSIGHTS_STATUS" = "enabled" ]; then
  echo "   ✅ Container Insights successfully enabled!"
else
  echo "   ❌ Container Insights is not enabled. Status: $INSIGHTS_STATUS"
  exit 1
fi

echo ""
echo "================================================"
echo "Container Insights Setup Complete"
echo "================================================"
echo ""
echo "Available Metrics (CloudWatch Namespace: ECS/ContainerInsights):"
echo "  - CPUUtilization"
echo "  - MemoryUtilization"
echo "  - NetworkRxBytes / NetworkTxBytes"
echo "  - StorageReadBytes / StorageWriteBytes"
echo "  - TaskCount"
echo ""
echo "View metrics in:"
echo "  - AWS Console: CloudWatch > Container Insights > ECS > $CLUSTER_NAME"
echo "  - Grafana: Use CloudWatch datasource with namespace 'ECS/ContainerInsights'"
echo ""
echo "Estimated Cost: ~$0.50/task/month for Container Insights"
