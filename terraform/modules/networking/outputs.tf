output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "target_group_arn" {
  value = aws_lb_target_group.main.arn
}

output "alb_dns_record" {
  value = length(aws_route53_record.alb) > 0 ? aws_route53_record.alb[0].fqdn : ""
}

output "jenkins_dns_name" {
  value = length(aws_route53_record.jenkins) > 0 ? aws_route53_record.jenkins[0].fqdn : ""
}
