#!/bin/bash
cd /home/ec2-user/taskflow

# Get monitoring server private IP from AWS
REGION=$(ec2-metadata --availability-zone | cut -d " " -f 2 | sed 's/[a-z]$//')
MONITORING_PRIVATE_IP=$(aws ec2 describe-instances --region $REGION --filters "Name=tag:Name,Values=TaskFlow-Monitoring-Server" "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)

aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 697863031884.dkr.ecr.eu-west-1.amazonaws.com
export REGISTRY_URL=697863031884.dkr.ecr.eu-west-1.amazonaws.com
export IMAGE_TAG=latest
export MONITORING_HOST=${MONITORING_PRIVATE_IP:-localhost}
docker-compose up -d
