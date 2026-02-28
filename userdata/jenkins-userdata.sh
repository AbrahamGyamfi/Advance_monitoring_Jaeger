#!/bin/bash
set -euo pipefail

DOCKER_COMPOSE_VERSION="v2.29.7"

# Update system
yum update -y

# Install Java 17 (required for Jenkins)
yum install -y java-17-amazon-corretto java-17-amazon-corretto-devel

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -aG docker ec2-user

# Install Docker Compose
curl -fsSL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Jenkins
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
yum install -y jenkins

# Add jenkins user to docker group
usermod -aG docker jenkins

# Install additional tools
yum install -y git curl wget unzip jq

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Get instance metadata
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
REGION=$(ec2-metadata --availability-zone | cut -d " " -f 2 | sed 's/[a-z]$//')
JENKINS_HOST=$(ec2-metadata --public-ipv4 | cut -d " " -f 2)

# Get Terraform outputs from tags
APP_SERVER_IP=$(aws ec2 describe-instances --region $REGION --filters "Name=tag:Name,Values=TaskFlow-App-Server" "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
APP_PRIVATE_IP=$(aws ec2 describe-instances --region $REGION --filters "Name=tag:Name,Values=TaskFlow-App-Server" "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
MONITORING_HOST=$(aws ec2 describe-instances --region $REGION --filters "Name=tag:Name,Values=TaskFlow-Monitoring-Server" "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Generate admin password
JENKINS_ADMIN_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# Get SSH private key from SSM Parameter Store (will be created by Terraform)
SSH_PRIVATE_KEY=$(aws ssm get-parameter --region $REGION --name "/taskflow/ssh-private-key" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "")

# Get AWS credentials from instance profile (already attached)
AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id || echo "")
AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key || echo "")

# Create Jenkins configuration directory
mkdir -p /var/lib/jenkins/casc_configs

# Create JCasC configuration with environment variables
cat > /var/lib/jenkins/casc_configs/jenkins.yaml <<EOF
jenkins:
  systemMessage: "TaskFlow CI/CD - Fully Automated Configuration"
  numExecutors: 2
  mode: NORMAL
  
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: "admin"
          password: "${JENKINS_ADMIN_PASSWORD}"
          
  authorizationStrategy:
    loggedInUsersCanDoAnything:
      allowAnonymousRead: false

credentials:
  system:
    domainCredentials:
      - credentials:
          - string:
              scope: GLOBAL
              id: "aws-region"
              secret: "${REGION}"
          - string:
              scope: GLOBAL
              id: "aws-account-id"
              secret: "${AWS_ACCOUNT_ID}"
          - string:
              scope: GLOBAL
              id: "app-server-ip"
              secret: "${APP_SERVER_IP}"
          - string:
              scope: GLOBAL
              id: "app-private-ip"
              secret: "${APP_PRIVATE_IP}"
          - string:
              scope: GLOBAL
              id: "monitoring-host"
              secret: "${MONITORING_HOST}"
          - string:
              scope: GLOBAL
              id: "app-name"
              secret: "taskflow"
          - string:
              scope: GLOBAL
              id: "node-version"
              secret: "18"
          - string:
              scope: GLOBAL
              id: "app-port"
              secret: "5000"
          - string:
              scope: GLOBAL
              id: "integration-test-port"
              secret: "5001"
          - string:
              scope: GLOBAL
              id: "health-check-timeout"
              secret: "60"
          - string:
              scope: GLOBAL
              id: "health-check-interval"
              secret: "5"
          - string:
              scope: GLOBAL
              id: "ec2-user"
              secret: "ec2-user"
          - aws:
              scope: GLOBAL
              id: "aws-credentials"
              accessKey: "${AWS_ACCESS_KEY_ID}"
              secretKey: "${AWS_SECRET_ACCESS_KEY}"
          - basicSSHUserPrivateKey:
              scope: GLOBAL
              id: "app-server-ssh"
              username: "ec2-user"
              privateKeySource:
                directEntry:
                  privateKey: |
$(echo "$SSH_PRIVATE_KEY" | sed 's/^/                    /')

unclassified:
  location:
    url: "http://${JENKINS_HOST}:8080/"
EOF

# Install Jenkins plugins
mkdir -p /var/lib/jenkins/plugins
cat > /var/lib/jenkins/plugins.txt <<EOF
configuration-as-code:latest
credentials:latest
credentials-binding:latest
aws-credentials:latest
git:latest
github:latest
workflow-aggregator:latest
pipeline-stage-view:latest
docker-workflow:latest
ssh-agent:latest
job-dsl:latest
timestamper:latest
ws-cleanup:latest
EOF

# Set Jenkins environment variables
cat > /etc/sysconfig/jenkins <<EOF
JENKINS_JAVA_OPTIONS="-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false -Dcasc.jenkins.config=/var/lib/jenkins/casc_configs/jenkins.yaml"
JENKINS_PORT="8080"
EOF

# Set ownership
chown -R jenkins:jenkins /var/lib/jenkins

# Start Jenkins
systemctl start jenkins
systemctl enable jenkins

# Wait for Jenkins to start
echo "Waiting for Jenkins to start..."
for i in {1..60}; do
    if curl -s http://localhost:8080 > /dev/null 2>&1; then
        echo "Jenkins started successfully"
        break
    fi
    sleep 5
done

# Install plugins using Jenkins CLI
sleep 30
wget http://localhost:8080/jnlpJars/jenkins-cli.jar -O /tmp/jenkins-cli.jar

while IFS= read -r plugin; do
    java -jar /tmp/jenkins-cli.jar -s http://localhost:8080/ -auth admin:${JENKINS_ADMIN_PASSWORD} install-plugin "$plugin" || true
done < /var/lib/jenkins/plugins.txt

# Restart Jenkins to load plugins
systemctl restart jenkins

# Save admin password to SSM Parameter Store
aws ssm put-parameter --region $REGION --name "/taskflow/jenkins-admin-password" --value "${JENKINS_ADMIN_PASSWORD}" --type "SecureString" --overwrite || true

# Save to local file as backup
echo "${JENKINS_ADMIN_PASSWORD}" > /var/lib/jenkins/secrets/admin_password
chown jenkins:jenkins /var/lib/jenkins/secrets/admin_password
chmod 600 /var/lib/jenkins/secrets/admin_password

echo "Jenkins installation completed!"
echo "Admin password saved to SSM Parameter Store: /taskflow/jenkins-admin-password"
echo "Access Jenkins at: http://${JENKINS_HOST}:8080"
echo "Username: admin"
echo "Password: ${JENKINS_ADMIN_PASSWORD}"
