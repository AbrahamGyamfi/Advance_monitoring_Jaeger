output "alb_dns_name" {
  value = aws_lb.taskflow.dns_name
}

output "codedeploy_app_name" {
  value = aws_codedeploy_app.taskflow.name
}

output "deployment_group_name" {
  value = aws_codedeploy_deployment_group.taskflow.deployment_group_name
}

output "s3_bucket_name" {
  value = aws_s3_bucket.codedeploy.id
}

output "asg_name" {
  value = aws_autoscaling_group.taskflow.name
}
