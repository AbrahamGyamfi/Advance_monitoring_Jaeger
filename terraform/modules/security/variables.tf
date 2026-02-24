variable "cloudtrail_bucket_name" {
  description = "S3 bucket name for CloudTrail logs"
  type        = string
}

variable "cloudtrail_name" {
  description = "CloudTrail name"
  type        = string
  default     = "taskflow-trail"
}

variable "cloudwatch_role_name" {
  description = "IAM role name for CloudWatch"
  type        = string
  default     = "taskflow-cloudwatch-role"
}
