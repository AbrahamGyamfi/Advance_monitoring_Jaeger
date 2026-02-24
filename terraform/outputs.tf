output "jenkins_instance_id" {
  description = "Jenkins server instance ID"
  value       = module.compute.jenkins_instance_id
}

output "jenkins_public_ip" {
  description = "Jenkins server public IP"
  value       = module.compute.jenkins_public_ip
}

output "jenkins_url" {
  description = "Jenkins web interface URL"
  value       = "http://${module.compute.jenkins_public_ip}:8080"
}

output "app_instance_id" {
  description = "Application server instance ID"
  value       = module.compute.app_instance_id
}

output "app_public_ip" {
  description = "Application server public IP"
  value       = module.compute.app_public_ip
}

output "app_url" {
  description = "Application URL"
  value       = "http://${module.compute.app_public_ip}"
}

output "security_group_id" {
  description = "Security group ID"
  value       = module.networking.security_group_id
}

output "ssh_jenkins" {
  description = "SSH command for Jenkins server"
  value       = "ssh -i ${var.key_name}.pem ec2-user@${module.compute.jenkins_public_ip}"
}

output "ssh_app" {
  description = "SSH command for application server"
  value       = "ssh -i ${var.key_name}.pem ec2-user@${module.compute.app_public_ip}"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = module.monitoring.prometheus_url
}

output "grafana_url" {
  description = "Grafana URL"
  value       = module.monitoring.grafana_url
}

output "monitoring_public_ip" {
  description = "Monitoring server public IP"
  value       = module.monitoring.monitoring_public_ip
}

output "monitoring_private_ip" {
  description = "Monitoring server private IP"
  value       = module.monitoring.monitoring_private_ip
}

output "cloudtrail_bucket" {
  description = "CloudTrail S3 bucket"
  value       = module.security.cloudtrail_bucket
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = module.security.guardduty_detector_id
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}
