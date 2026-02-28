output "jenkins_public_ip" {
  value = module.compute.jenkins_public_ip
}

output "app_public_ip" {
  value = module.compute.app_public_ip
}

output "monitoring_public_ip" {
  value = module.monitoring.monitoring_public_ip
}

output "prometheus_url" {
  value = "http://${module.monitoring.monitoring_public_ip}:9090"
}

output "grafana_url" {
  value = "http://${module.monitoring.monitoring_public_ip}:3000"
}

output "cloudtrail_bucket" {
  value = module.security.cloudtrail_bucket
}

output "guardduty_detector_id" {
  value = module.security.guardduty_detector_id
}

output "aws_region" {
  value = var.aws_region
}

# CodeDeploy outputs (conditional)
output "alb_dns_name" {
  value = try(module.codedeploy[0].alb_dns_name, "")
}

output "codedeploy_app_name" {
  value = try(module.codedeploy[0].codedeploy_app_name, "")
}

output "deployment_group_name" {
  value = try(module.codedeploy[0].deployment_group_name, "")
}

output "alb_url" {
  description = "Application Load Balancer URL"
  value       = module.ecs.alb_url
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.ecs.alb_dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs.service_name
}

output "codedeploy_app_name" {
  description = "CodeDeploy application name"
  value       = module.ecs.codedeploy_app_name
}

output "codedeploy_deployment_group" {
  description = "CodeDeploy deployment group name"
  value       = module.ecs.codedeploy_deployment_group_name
}
