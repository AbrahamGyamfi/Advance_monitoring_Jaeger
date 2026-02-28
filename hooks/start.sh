#!/bin/bash
cd /home/ec2-user/taskflow
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 697863031884.dkr.ecr.eu-west-1.amazonaws.com
docker-compose up -d
