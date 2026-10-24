output "vpc_id" {
  value = aws_vpc.autod2026_vpc.id
}

output "vault_address" {
  value = aws_instance.vault_server.public_ip
}