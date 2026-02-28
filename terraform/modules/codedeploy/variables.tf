variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ALB and ASG"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "key_name" {
  description = "SSH key name"
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile name"
  type        = string
}

variable "user_data" {
  description = "User data script"
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}
