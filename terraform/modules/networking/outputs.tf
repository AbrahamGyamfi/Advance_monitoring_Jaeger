output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.taskflow.id
}

output "security_group_name" {
  description = "Security group name"
  value       = aws_security_group.taskflow.name
}

output "key_name" {
  description = "SSH key pair name"
  value       = aws_key_pair.taskflow.key_name
}
