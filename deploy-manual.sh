#!/bin/bash
set -euo pipefail

echo "🚀 Deploying TaskFlow to EC2..."

APP_IP=$(cd terraform && terraform output -raw app_public_ip)
REGISTRY=$(cd terraform && terraform output -raw aws_account_id).dkr.ecr.$(cd terraform && terraform output -raw aws_region).amazonaws.com
TAG="latest"

echo "App Server: $APP_IP"
echo "Registry: $REGISTRY"

# Copy docker-compose file
scp -o StrictHostKeyChecking=no docker-compose.prod.yml ec2-user@$APP_IP:~/taskflow/docker-compose.yml

# Deploy
ssh -o StrictHostKeyChecking=no ec2-user@$APP_IP bash -s $REGISTRY $TAG << 'ENDSSH'
set -e
cd ~/taskflow

REGISTRY="$1"
TAG="$2"

# Login to ECR
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin "$REGISTRY"

# Pull images
docker pull "$REGISTRY/taskflow-backend:$TAG"
docker pull "$REGISTRY/taskflow-frontend:$TAG"

# Deploy
export REGISTRY_URL="$REGISTRY"
export IMAGE_TAG="$TAG"
docker-compose down || true
docker-compose up -d

# Health check
for i in {1..12}; do
    if curl -fsS http://localhost:5000/health >/dev/null 2>&1; then
        echo "✅ Deployment successful!"
        exit 0
    fi
    sleep 5
done

echo "❌ Health check failed"
docker-compose logs
exit 1
ENDSSH

echo "✅ Deployment complete!"
