#!/bin/bash
cd /home/ec2-user/taskflow
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 697863031884.dkr.ecr.eu-west-1.amazonaws.com
export REGISTRY_URL=697863031884.dkr.ecr.eu-west-1.amazonaws.com
export IMAGE_TAG=latest
export MONITORING_HOST=54.78.155.203
docker-compose up -d
