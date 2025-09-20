resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project_name}-cache-subnet-${var.environment}"
  subnet_ids = var.private_subnet_ids
  tags = {
    Name = "${var.project_name}-cache-subnet-${var.environment}"
  }
}

resource "aws_elasticache_cluster" "main" {
  cluster_id           = "${var.project_name}-redis-${var.environment}"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [var.security_group_id]
}
