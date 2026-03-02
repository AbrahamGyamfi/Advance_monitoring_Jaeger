#!/bin/bash
set -e
cd /home/ec2-user/taskflow

# Use hardcoded monitoring server private IP (from terraform output)
MONITORING_PRIVATE_IP="172.31.20.106"

aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 697863031884.dkr.ecr.eu-west-1.amazonaws.com
export REGISTRY_URL=697863031884.dkr.ecr.eu-west-1.amazonaws.com
export IMAGE_TAG=latest
export MONITORING_HOST=$MONITORING_PRIVATE_IP
echo "Using monitoring host: $MONITORING_HOST"
docker-compose up -d
