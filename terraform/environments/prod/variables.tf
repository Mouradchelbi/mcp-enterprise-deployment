variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "mcp-server"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "prodops-team"
}

variable "vpc_id" {
  description = "Existing VPC ID"
  type        = string
  default     = "vpc-07f7af107dca845ac"
}

variable "security_group_id" {
  description = "Existing security group ID"
  type        = string
  default     = "sg-0174a494e2ae5db05"
}

variable "jenkins_instance_id" {
  description = "Existing Jenkins instance ID"
  type        = string
  default     = "i-0f42ea74f084b917b"
}

variable "deployment_target" {
  description = "Deployment target (eks)"
  type        = string
  default     = "eks"
}

variable "route53_zone_id" {
  description = "Route 53 Hosted Zone ID"
  type        = string
  default     = ""
}

variable "alb_subdomain" {
  description = "Subdomain for ALB DNS record"
  type        = string
  default     = "mcp-server"
}

variable "jenkins_subdomain" {
  description = "Subdomain for Jenkins DNS record"
  type        = string
  default     = "jenkins"
}
