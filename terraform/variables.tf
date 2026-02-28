variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "jenkins_instance_type" {
  description = "Instance type for Jenkins server"
  type        = string
  default     = "t3.medium"
}

variable "app_instance_type" {
  description = "Instance type for application server"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = "taskflow-key"
}

variable "public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "private_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "admin_cidr_blocks" {
  description = "Allowed CIDR blocks for administrative endpoints (SSH, Jenkins, Grafana, Prometheus)"
  type        = list(string)
}

variable "docker_registry" {
  description = "Docker registry URL"
  type        = string
  default     = "697863031884.dkr.ecr.eu-west-1.amazonaws.com"
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "1.0.0"
}

variable "cloudtrail_bucket_name" {
  description = "S3 bucket name for CloudTrail logs"
  type        = string
  default     = "taskflow-cloudtrail-logs"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}
