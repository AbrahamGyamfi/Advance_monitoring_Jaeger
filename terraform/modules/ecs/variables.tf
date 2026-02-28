variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
  default     = "taskflow-cluster"
}

variable "subnet_ids" {
  description = "Subnet IDs for ECS tasks"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "backend_task_definition_arn" {
  description = "Backend task definition ARN"
  type        = string
}

variable "frontend_task_definition_arn" {
  description = "Frontend task definition ARN"
  type        = string
}

variable "backend_target_group_arn" {
  description = "Backend ALB target group ARN"
  type        = string
}

variable "frontend_target_group_arn" {
  description = "Frontend ALB target group ARN"
  type        = string
}
