terraform {
  required_version = ">= 1.0"
  backend "s3" {
    bucket         = "mcp-server-terraform-state-dev"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "mcp-server-terraform-locks-dev"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      Owner       = var.owner
      ManagedBy   = "terraform"
    }
  }
}

# Data sources for existing infrastructure
data "aws_vpc" "existing" {
  id = "vpc-07f7af107dca845ac"
}

data "aws_security_group" "existing" {
  id = "sg-0174a494e2ae5db05"
}

data "aws_instance" "jenkins" {
  instance_id = "i-0f42ea74f084b917b"
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
  filter {
    name   = "tag:Type"
    values = ["Public"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
  filter {
    name   = "tag:Type"
    values = ["Private"]
  }
}

# Networking module (ALB, NAT Gateway, Route 53)
module "networking" {
  source            = "../../modules/networking"
  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = data.aws_vpc.existing.id
  public_subnet_ids = data.aws_subnets.public.ids
  private_subnet_ids = data.aws_subnets.private.ids
  security_group_id = data.aws_security_group.existing.id
  azs               = data.aws_availability_zones.available.names
  route53_zone_id   = var.route53_zone_id
  alb_subdomain     = var.alb_subdomain
  jenkins_subdomain = var.jenkins_subdomain
  jenkins_public_ip = data.aws_instance.jenkins.public_ip
}

# Compute module (EKS)
module "compute" {
  source               = "../../modules/compute"
  project_name         = var.project_name
  environment          = var.environment
  deployment_target    = var.deployment_target
  vpc_id               = data.aws_vpc.existing.id
  private_subnet_ids   = data.aws_subnets.private.ids
  public_subnet_ids    = data.aws_subnets.public.ids
  security_group_id    = data.aws_security_group.existing.id
  jenkins_instance_id  = data.aws_instance.jenkins.instance_id
  alb_target_group_arn = module.networking.target_group_arn
}

# Database module (RDS PostgreSQL)
module "database" {
  source               = "../../modules/database"
  project_name         = var.project_name
  environment          = var.environment
  vpc_id               = data.aws_vpc.existing.id
  private_subnet_ids   = data.aws_subnets.private.ids
  security_group_id    = data.aws_security_group.existing.id
}

# Cache module (ElastiCache Redis)
module "cache" {
  source               = "../../modules/cache"
  project_name         = var.project_name
  environment          = var.environment
  vpc_id               = data.aws_vpc.existing.id
  private_subnet_ids   = data.aws_subnets.private.ids
  security_group_id    = data.aws_security_group.existing.id
}

# ECR Repository
resource "aws_ecr_repository" "mcp_server" {
  name                 = "${var.project_name}-${var.environment}"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

# Secrets Manager for DB credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "mcp-server-jenkins-ansible-key-${var.environment}"
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = module.database.db_username
    password = module.database.db_password
  })
}
