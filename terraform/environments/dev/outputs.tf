output "environment_summary" {
  description = "Detailed summary of the deployed environment"
  value = {
    aws_region          = var.aws_region
    environment         = var.environment
    project_name        = var.project_name
    vpc_id              = data.aws_vpc.existing.id
    public_subnet_ids   = data.aws_subnets.public.ids
    private_subnet_ids  = aws_subnet.private[*].id
    security_group_id   = var.security_group_id
    jenkins = {
      instance_id   = var.jenkins_instance_id
      instance_type = module.compute.jenkins_instance_type
      public_ip     = module.compute.jenkins_public_ip
      url           = module.compute.jenkins_url
      dns_name      = module.networking.jenkins_dns_name
    }
    eks = {
      cluster_endpoint = module.compute.eks_cluster_endpoint
      cluster_name     = module.compute.eks_cluster_name
      node_group_name  = module.compute.eks_node_group_name
    }
    alb = {
      dns_name    = module.networking.alb_dns_name
      dns_record  = module.networking.alb_dns_name
    }
    rds = {
      endpoint = module.database.rds_endpoint
    }
    redis = {
      endpoint = module.cache.redis_endpoint
    }
    ecr = {
      repository_url = aws_ecr_repository.mcp_server.repository_url
    }
    secrets_manager = {
      db_credentials_arn = aws_secretsmanager_secret.db_credentials.arn
    }
  }
}
