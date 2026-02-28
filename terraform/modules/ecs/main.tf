# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name    = var.cluster_name
    Project = "TaskFlow"
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/taskflow-backend"
  retention_in_days = 7

  tags = {
    Project = "TaskFlow"
  }
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/taskflow-frontend"
  retention_in_days = 7

  tags = {
    Project = "TaskFlow"
  }
}

# ECS Service for Backend
resource "aws_ecs_service" "backend" {
  name            = "taskflow-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = var.backend_task_definition_arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.backend_target_group_arn
    container_name   = "backend"
    container_port   = 5000
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count, load_balancer]
  }

  tags = {
    Project = "TaskFlow"
  }
}

# ECS Service for Frontend
resource "aws_ecs_service" "frontend" {
  name            = "taskflow-frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = var.frontend_task_definition_arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.frontend_target_group_arn
    container_name   = "frontend"
    container_port   = 80
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count, load_balancer]
  }

  tags = {
    Project = "TaskFlow"
  }
}
