variable "project_name" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
variable "security_group_id" { type = string }
variable "azs" { type = list(string) }
variable "route53_zone_id" { type = string }
variable "alb_subdomain" { type = string }
variable "jenkins_subdomain" { type = string }
variable "jenkins_public_ip" { type = string }
variable "private_route_table_ids" {
  description = "Route table IDs for private subnets"
  type        = list(string)
}
