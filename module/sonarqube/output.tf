output "sonarqube_instance_id" {
  value       = aws_instance.sonarqube.id
  description = "EC2 instance ID of the SonarQube server"
}

output "sonarqube_private_ip" {
  value       = aws_instance.sonarqube.private_ip
  description = "Private IP address of the SonarQube server"
}

output "sonarqube_alb_dns" {
  value       = aws_lb.sonarqube_alb.dns_name
  description = "DNS name of the SonarQube ALB"
}

output "sonarqube_url" {
  value       = "https://sonarqube.${var.domain_name}"
  description = "Public URL of the SonarQube web UI"
}