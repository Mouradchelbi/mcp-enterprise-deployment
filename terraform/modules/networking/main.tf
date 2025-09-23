# NAT Gateway for private subnet outbound traffic
resource "aws_eip" "nat" {
  count = length(var.public_subnet_ids)
  domain = "vpc"
  tags = {
    Name = "${var.project_name}-nat-eip-${var.environment}-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "main" {
  count         = length(var.public_subnet_ids)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = var.public_subnet_ids[count.index]
  tags = {
    Name = "${var.project_name}-nat-${var.environment}-${count.index + 1}"
  }
}

# Add route to NAT Gateway in existing private route tables
resource "aws_route" "private_nat" {
  count                  = length(var.private_route_table_ids)
  route_table_id         = var.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[count.index % length(aws_nat_gateway.main)].id
}

# Security Group Rules
resource "aws_security_group_rule" "jenkins_to_eks" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = var.security_group_id
  source_security_group_id = var.security_group_id
  description              = "Allow Jenkins to EKS control plane"
}

resource "aws_security_group_rule" "jenkins_to_rds" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = var.security_group_id
  source_security_group_id = var.security_group_id
  description              = "Allow Jenkins to RDS"
}

resource "aws_security_group_rule" "jenkins_to_redis" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = var.security_group_id
  source_security_group_id = var.security_group_id
  description              = "Allow Jenkins to ElastiCache"
}

resource "aws_security_group_rule" "alb_to_eks" {
  type                     = "ingress"
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  security_group_id        = var.security_group_id
  source_security_group_id = var.security_group_id
  description              = "Allow ALB to EKS nodes"
}

resource "aws_security_group_rule" "http_ingress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = var.security_group_id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTP to ALB"
  
  

  lifecycle {
    ignore_changes = all
  }
}



# Add egress rules for EKS worker nodes
resource "aws_security_group_rule" "eks_worker_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = var.security_group_id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all egress for EKS worker nodes"
}

resource "aws_security_group_rule" "eks_worker_egress_cluster" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = var.security_group_id
  source_security_group_id = var.security_group_id
  description              = "Allow worker nodes to communicate with cluster"
}
# ALB
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.public_subnet_ids
  tags = {
    Name = "${var.project_name}-alb-${var.environment}"
  }
}

resource "aws_lb_target_group" "main" {
  name        = "${var.project_name}-tg-${var.environment}"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# Route 53 DNS Records
resource "aws_route53_record" "alb" {
  count   = var.route53_zone_id != "" ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "${var.alb_subdomain}.${var.environment}"
  type    = "A"
  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "jenkins" {
  count   = var.route53_zone_id != "" ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "${var.jenkins_subdomain}.${var.environment}"
  type    = "A"
  ttl     = 300
  records = [var.jenkins_public_ip]
}