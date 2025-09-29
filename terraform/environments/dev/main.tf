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

# provider "kubernetes" {
#   host                   = module.compute.cluster_endpoint
#   cluster_ca_certificate = base64decode(module.compute.cluster_ca_certificate)
#   exec {
#     api_version = "client.authentication.k8s.io/v1beta1"
#     command     = "aws"
#     args        = ["eks", "get-token", "--cluster-name", module.compute.cluster_name]
#   }
# }

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

# Create Private Subnets
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = data.aws_vpc.existing.id
  cidr_block        = "10.0.${count.index + 20}.0/24"  # Using 10.0.20.0/24, 10.0.21.0/24
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "mcp-server-private-subnet-${count.index + 1}-${var.environment}"
    Type        = "Private"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    Purpose     = "Application-Infrastructure"
    Owner       = var.owner
  }
}

# Create Route Tables for Private Subnets
resource "aws_route_table" "private" {
  count  = 2
  vpc_id = data.aws_vpc.existing.id

  tags = {
    Name        = "mcp-server-private-rt-${count.index + 1}-${var.environment}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# Associate Private Subnets with Route Tables
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Networking module (ALB, NAT Gateway, Route 53)
module "networking" {
  source            = "../../modules/networking"
  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = data.aws_vpc.existing.id
  public_subnet_ids = data.aws_subnets.public.ids
  private_subnet_ids = aws_subnet.private[*].id  # Use created private subnets
  security_group_id = data.aws_security_group.existing.id
  azs               = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]  # Limit to 2 AZs
  route53_zone_id   = var.route53_zone_id
  alb_subdomain     = var.alb_subdomain
  jenkins_subdomain = var.jenkins_subdomain
  jenkins_public_ip = data.aws_instance.jenkins.public_ip
  private_route_table_ids = aws_route_table.private[*].id  # Pass route table IDs
}

# Compute module (EKS)
module "compute" {
  source               = "../../modules/compute"
  project_name         = var.project_name
  environment          = var.environment
  deployment_target    = var.deployment_target
  aws_region           = var.aws_region
  vpc_id               = data.aws_vpc.existing.id
  private_subnet_ids   = aws_subnet.private[*].id  # Use created private subnets
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
  private_subnet_ids   = aws_subnet.private[*].id  # Use created private subnets
  security_group_id    = data.aws_security_group.existing.id
}

# Cache module (ElastiCache Redis)
module "cache" {
  source               = "../../modules/cache"
  project_name         = var.project_name
  environment          = var.environment
  vpc_id               = data.aws_vpc.existing.id
  private_subnet_ids   = aws_subnet.private[*].id  # Use created private subnets
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