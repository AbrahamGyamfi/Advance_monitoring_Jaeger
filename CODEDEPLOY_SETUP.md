# AWS CodeDeploy Blue-Green Deployment Setup

## Overview
This setup adds AWS CodeDeploy with Blue-Green deployment to TaskFlow, replacing direct SSH deployment with automated, zero-downtime deployments.

## Architecture Changes

### Before (Direct SSH)
```
Jenkins → SSH → EC2 → Docker Compose
```

### After (Blue-Green)
```
Jenkins → CodeDeploy → ALB → ASG (Blue/Green) → EC2 Instances
```

## Components Added

1. **Application Load Balancer (ALB)** - Routes traffic between Blue/Green environments
2. **Auto Scaling Group (ASG)** - Manages EC2 instances
3. **Target Groups** - Blue and Green target groups for ALB
4. **CodeDeploy Application** - Manages deployments
5. **S3 Bucket** - Stores deployment artifacts

## Deployment Flow

1. Jenkins builds and tests Docker images
2. Images pushed to ECR
3. Jenkins creates deployment bundle (docker-compose.yml + appspec.yml)
4. Bundle uploaded to S3
5. CodeDeploy triggered:
   - Creates new Green ASG (copy of Blue)
   - Deploys application to Green instances
   - Runs health checks
   - Switches ALB traffic from Blue to Green
   - Keeps Blue instances for 5 minutes (rollback capability)

## Setup Instructions

### 1. Get Default VPC and Subnets
```bash
# Get default VPC ID
aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text

# Get subnet IDs
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<VPC_ID>" --query "Subnets[*].SubnetId" --output text
```

### 2. Update terraform/variables.tf
Add these variables:
```hcl
variable "vpc_id" {
  description = "VPC ID for ALB and ASG"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ALB and ASG"
  type        = list(string)
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}
```

### 3. Update terraform/main.tf
Add CodeDeploy module:
```hcl
module "codedeploy" {
  source = "./modules/codedeploy"

  vpc_id                = var.vpc_id
  subnet_ids            = var.subnet_ids
  security_group_id     = module.networking.security_group_id
  ami_id                = module.compute.ami_id
  key_name              = module.networking.key_name
  instance_profile_name = module.security.iam_instance_profile
  user_data             = file("${path.module}/../userdata/app-userdata.sh")
  aws_account_id        = var.aws_account_id
}
```

### 4. Update terraform.tfvars
```hcl
vpc_id         = "vpc-xxxxxxxxx"
subnet_ids     = ["subnet-xxxxxxxx", "subnet-yyyyyyyy"]
aws_account_id = "123456789012"
```

### 5. Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 6. Configure Jenkins Credentials
No additional credentials needed - uses existing AWS credentials.

### 7. Run Pipeline
The updated Jenkinsfile will automatically use CodeDeploy for deployments.

## Verification

### Check ALB
```bash
aws elbv2 describe-load-balancers --names taskflow-alb
```

### Check ASG
```bash
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names taskflow-asg
```

### Check CodeDeploy
```bash
aws deploy list-applications
aws deploy list-deployment-groups --application-name taskflow-app
```

### Access Application
```bash
# Get ALB DNS name
terraform output alb_dns_name

# Test application
curl http://<ALB_DNS>/health
```

## Rollback

If deployment fails, CodeDeploy automatically rolls back to Blue environment.

Manual rollback:
```bash
aws deploy stop-deployment --deployment-id <DEPLOYMENT_ID> --auto-rollback-enabled
```

## Cost Impact

Additional monthly costs:
- ALB: ~$16/month
- Additional EC2 during deployment: ~$0.01/hour (5 minutes = $0.001)
- S3 storage: <$1/month

**New Total**: ~$55/month (was $39/month)

## Benefits

1. **Zero Downtime** - Traffic switches only after health checks pass
2. **Automatic Rollback** - Failed deployments automatically revert
3. **Blue/Green Strategy** - Old version kept alive for quick rollback
4. **Health Validation** - ALB health checks ensure application readiness
5. **Scalability** - ASG enables auto-scaling if needed

## Monitoring

Prometheus will automatically discover new instances via ALB target groups.
Update `monitoring/config/prometheus.yml` if needed:

```yaml
scrape_configs:
  - job_name: 'taskflow-backend'
    ec2_sd_configs:
      - region: eu-west-1
        port: 5000
        filters:
          - name: tag:Name
            values: ['taskflow-app']
```
