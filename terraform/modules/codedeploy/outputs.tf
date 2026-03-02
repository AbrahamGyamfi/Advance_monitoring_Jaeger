output "alb_dns_name" {
  value = aws_lb.taskflow.dns_name
}

output "alb_listener_arn" {
  value = aws_lb_listener.taskflow.arn
}

output "blue_target_group_arn" {
  value = aws_lb_target_group.blue.arn
}

output "blue_target_group_name" {
  value = aws_lb_target_group.blue.name
}

output "green_target_group_name" {
  value = aws_lb_target_group.green.name
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
