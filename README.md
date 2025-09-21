# MCP Server Enterprise Deployment (EKS)

This project deploys the MCP Server on AWS EKS in private subnets, reusing an existing VPC (`vpc-07xxxxxxxxac`) and Jenkins server (`xx.xx.xx.xx:8080`) in a public subnet for CI/CD and Ansible connections. It includes ALB (public subnets), RDS (PostgreSQL, private subnets), ElastiCache (Redis, private subnets), Secrets Manager for credentials, and Route 53 DNS records.

## Existing Infrastructure
- **VPC**: `vpc-07f7af107dca845ac` (multi-AZ, public/private subnets).
- **Security Group**: `sg-0174xxxxxxxx` (updated for Jenkins communication).
- **Jenkins Server**: `xx.xx.xx.xx` (instance ID: `i-0f42xxxxxxxxxxx`, user: `ec2-user`, type: t3.large) in public subnet.
- **IAM User**: `arn:aws:iam::685939060042:user/mcp-server-cpm-user-dev` for Terraform operations.

## Prerequisites
- AWS credentials (`aws-moudevops-access-key`) in Jenkins with IAM user permissions.
- Jenkins server at `http://xx.xx.xx.xx:8080` with Ansible, AWS CLI, `kubectl`.
- SSH access to Jenkins for Ansible (update key in `ansible/inventories/`).
- Actual public/private subnet IDs in `terraform/environments/*/variables.tf`.
- Route 53 hosted zone ID for DNS records.

## Setup
1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd mcp-enterprise-deployment
   ```
2. Update subnet IDs and Route 53 zone ID in `terraform/environments/dev/variables.tf`:
   ```hcl
   public_subnet_ids = ["subnet-xxx", "subnet-yyy"]
   private_subnet_ids = ["subnet-aaa", "subnet-bbb"]
   route53_zone_id = "ZXXXXXXXXXXXXX"
   ```
3. Configure Jenkins credentials and pipeline (`jenkins/Jenkinsfile`).
4. Run the pipeline with `ENVIRONMENT=dev` and `DEPLOYMENT_TARGET=eks`.

## Manual Testing
```bash
cd application
docker-compose up -d
pytest tests/unit/
docker-compose down
```

## Deployment
- The pipeline deploys EKS, RDS, ElastiCache, ALB, and the application using Terraform and Ansible.
- Secrets Manager stores DB credentials (`mcp-server-jenkins-ansible-key-dev`).
- Route 53 creates DNS records for ALB (`mcp-server.<domain>`) and Jenkins (`jenkins.<domain>`).

## Environment Summary
Example output for `dev`:
```hcl
environment_summary = {
  aws_region = "us-east-1"
  environment = "dev"
  instance_id = "i-0f42xxxxxxxxxxx"
  instance_type = "t3.large"
  jenkins_url = "http://xx.xx.xx.xx:8080"
  project_name = "mcp-server"
  public_ip = "xx.xx.xx.xx"
  security_group_id = "sg-017xxxxxxxxxxxx"
  vpc_id = "vpc-07f7af107dca845ac"
  eks_cluster_endpoint = "https://..."
  rds_endpoint = "..."
  redis_endpoint = "..."
  alb_dns_name = "..."
  route53_alb_fqdn = "mcp-server.<domain>"
}
```
