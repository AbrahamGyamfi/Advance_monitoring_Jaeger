output "cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "backend_service_name" {
  description = "Backend ECS service name"
  value       = aws_ecs_service.backend.name
}

output "frontend_service_name" {
  description = "Frontend ECS service name"
  value       = aws_ecs_service.frontend.name
}

output "backend_log_group" {
  description = "Backend CloudWatch log group"
  value       = aws_cloudwatch_log_group.backend.name
}

output "frontend_log_group" {
  description = "Frontend CloudWatch log group"
  value       = aws_cloudwatch_log_group.frontend.name
}
