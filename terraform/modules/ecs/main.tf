# ECS Cluster
resource "aws_ecs_cluster" "taskflow" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Application Load Balancer
resource "aws_lb" "taskflow" {
  name               = "${var.cluster_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.subnet_ids

  enable_deletion_protection = false
}

# Target Group - Blue
resource "aws_lb_target_group" "blue" {
  name        = "${var.service_name}-blue"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "5000"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  deregistration_delay = 30
}

# Target Group - Green
resource "aws_lb_target_group" "green" {
  name        = "${var.service_name}-green"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "5000"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  deregistration_delay = 30
}

# ALB Listener - Production
resource "aws_lb_listener" "production" {
  load_balancer_arn = aws_lb.taskflow.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }

  lifecycle {
    ignore_changes = [default_action]
  }
}

# ALB Listener - Test (for Blue/Green validation)
resource "aws_lb_listener" "test" {
  load_balancer_arn = aws_lb.taskflow.arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green.arn
  }

  lifecycle {
    ignore_changes = [default_action]
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "taskflow" {
  name              = "/ecs/${var.cluster_name}"
  retention_in_days = 7
}

# ECS Task Definition
resource "aws_ecs_task_definition" "taskflow" {
  family                   = var.task_family
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = var.backend_image
      essential = true
      portMappings = [
        {
          containerPort = 5000
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "PORT", value = "5000" },
        { name = "OTEL_SERVICE_NAME", value = "taskflow-backend" },
        { name = "OTEL_TRACES_EXPORTER", value = "otlp" },
        { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://${var.monitoring_host}:4318" }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "wget -q --spider http://localhost:5000/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 40
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.taskflow.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "backend"
        }
      }
    },
    {
      name      = "frontend"
      image     = var.frontend_image
      essential = true
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
      dependsOn = [
        {
          containerName = "backend"
          condition     = "HEALTHY"
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "wget -q --spider http://localhost:80/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.taskflow.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "frontend"
        }
      }
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "taskflow" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.taskflow.id
  task_definition = aws_ecs_task_definition.taskflow.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.blue.arn
    container_name   = "frontend"
    container_port   = 80
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  lifecycle {
    ignore_changes = [task_definition, load_balancer]
  }
}

# CodeDeploy Application
resource "aws_codedeploy_app" "taskflow" {
  compute_platform = "ECS"
  name             = var.cluster_name
}

# CodeDeploy Deployment Group
resource "aws_codedeploy_deployment_group" "taskflow" {
  app_name               = aws_codedeploy_app.taskflow.name
  deployment_group_name  = "${var.service_name}-dg"
  service_role_arn       = var.execution_role_arn
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.taskflow.name
    service_name = aws_ecs_service.taskflow.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.production.arn]
      }

      test_traffic_route {
        listener_arns = [aws_lb_listener.test.arn]
      }

      target_group {
        name = aws_lb_target_group.blue.name
      }

      target_group {
        name = aws_lb_target_group.green.name
      }
    }
  }
}
