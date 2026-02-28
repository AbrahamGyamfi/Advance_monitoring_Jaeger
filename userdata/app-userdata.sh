#!/bin/bash
set -euo pipefail

DOCKER_COMPOSE_VERSION="v2.29.7"

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -aG docker ec2-user

# Install Docker Compose
curl -fsSL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Start Docker
systemctl start docker
systemctl enable docker

# Install additional tools
yum install -y git curl wget ruby

# Install CodeDeploy agent
cd /home/ec2-user
wget https://aws-codedeploy-eu-west-1.s3.eu-west-1.amazonaws.com/latest/install
chmod +x ./install
./install auto
systemctl start codedeploy-agent
systemctl enable codedeploy-agent

echo "Application server setup completed!"
