resource "aws_ecs_task_definition" "backend" {
  family                   = "taskflow-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([{
    name  = "taskflow-backend"
    image = "010679547158.dkr.ecr.eu-west-1.amazonaws.com/taskflow-backend:latest"
    portMappings = [{
      containerPort = 5000
      protocol      = "tcp"
    }]
    environment = [
      {
        name  = "NODE_ENV"
        value = "production"
      },
      {
        name  = "PORT"
        value = "5000"
      },
      {
        name  = "OTEL_SERVICE_NAME"
        value = "taskflow-backend"
      },
      {
        name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
        value = "http://${var.monitoring_host}:4318"
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.backend.name
        "awslogs-region"        = "eu-west-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}
