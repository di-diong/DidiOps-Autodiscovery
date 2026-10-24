output "public_ip" {
  value       = aws_instance.ansible_server.public_ip
  description = "Public IP address of the Ansible control node"
}

output "private_ip" {
  value       = aws_instance.ansible_server.private_ip
  description = "Private IP address of the Ansible control node"
}

output "ansible_sg" {
  value       = aws_security_group.ansible_sg.id
  description = "Security group ID of the Ansible control node"
}