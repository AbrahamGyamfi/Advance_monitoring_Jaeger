output "cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.taskflow.id
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.taskflow.name
}

output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.taskflow.name
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.taskflow.dns_name
}

output "alb_url" {
  description = "Application URL"
  value       = "http://${aws_lb.taskflow.dns_name}"
}

output "blue_target_group_name" {
  description = "Blue target group name"
  value       = aws_lb_target_group.blue.name
}

output "green_target_group_name" {
  description = "Green target group name"
  value       = aws_lb_target_group.green.name
}

output "codedeploy_app_name" {
  description = "CodeDeploy application name"
  value       = aws_codedeploy_app.taskflow.name
}

output "codedeploy_deployment_group_name" {
  description = "CodeDeploy deployment group name"
  value       = aws_codedeploy_deployment_group.taskflow.deployment_group_name
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.taskflow.name
}
