# Outputs
output "nexus_instance_id" {
  value       = aws_instance.nexus.id
  description = "The EC2 Instance ID of the Nexus server"
}

output "nexus_public_ip" {
  value       = aws_instance.nexus.public_ip
  description = "Public IP address of the Nexus server"
}

output "nexus_private_ip" {
  value       = aws_instance.nexus.private_ip
  description = "Private IP address of the Nexus server (used by app hosts to pull images)"
}

output "nexus_url" {
  value       = "https://nexus.${var.domain_name}"
  description = "Public URL of the Nexus web UI"
}