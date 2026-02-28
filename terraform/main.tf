terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "networking" {
  source = "./modules/networking"

  security_group_name = "taskflow-sg"
  key_name            = var.key_name
  public_key_path     = var.public_key_path
  admin_cidr_blocks   = var.admin_cidr_blocks
}

module "compute" {
  source = "./modules/compute"

  jenkins_instance_type    = var.jenkins_instance_type
  app_instance_type        = var.app_instance_type
  key_name                 = module.networking.key_name
  security_group_name      = module.networking.security_group_name
  app_iam_instance_profile = module.security.iam_instance_profile
}

module "security" {
  source = "./modules/security"

  cloudtrail_bucket_name = var.cloudtrail_bucket_name
}

module "monitoring" {
  source = "./modules/monitoring"

  ami_id               = module.compute.ami_id
  key_name             = module.networking.key_name
  security_group_name  = module.networking.security_group_name
  iam_instance_profile = module.security.iam_instance_profile
  aws_region           = var.aws_region
  app_public_ip        = module.compute.app_public_ip
  app_private_ip       = module.compute.app_private_ip
  private_key_path     = var.private_key_path
}

module "ecs" {
  source = "./modules/ecs"

  cluster_name         = "taskflow-cluster"
  service_name         = "taskflow-service"
  task_family          = "taskflow-task"
  backend_image        = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/taskflow-backend:latest"
  frontend_image       = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/taskflow-frontend:latest"
  vpc_id               = module.networking.vpc_id
  subnet_ids           = module.networking.subnet_ids
  security_group_id    = module.networking.security_group_id
  execution_role_arn   = module.security.ecs_task_execution_role_arn
  task_role_arn        = module.security.ecs_task_role_arn
  monitoring_host      = module.monitoring.monitoring_private_ip
  aws_region           = var.aws_region
}
