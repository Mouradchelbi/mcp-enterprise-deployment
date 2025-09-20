output "jenkins_instance_id" {
  value = var.jenkins_instance_id
}

output "jenkins_instance_type" {
  value = data.aws_instance.jenkins.instance_type
}

output "jenkins_public_ip" {
  value = data.aws_instance.jenkins.public_ip
}

output "jenkins_url" {
  value = "http://44.195.143.19:8080"
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "eks_cluster_name" {
  value = aws_eks_cluster.main.name
}

output "eks_node_group_name" {
  value = aws_eks_node_group.main.node_group_name
}
