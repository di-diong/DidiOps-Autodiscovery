output "db_endpoint" {
  description = "RDS instance connection endpoint (address:port)"
  value       = aws_db_instance.autod2026_mysql_database.endpoint
}

output "db_address" {
  description = "RDS instance hostname"
  value       = aws_db_instance.autod2026_mysql_database.address
}

output "db_name" {
  description = "Initial database name"
  value       = aws_db_instance.autod2026_mysql_database.db_name
}

output "db_username" {
  description = "Master username (sourced from Vault)"
  value       = aws_db_instance.autod2026_mysql_database.username
  sensitive   = true
}

output "db_password" {
 description = "Master password (sourced from Vault)"
value       = data.vault_generic_secret.vault-secret.data["password"]
sensitive   = true
}

output "db_password" {
  value       = "holder123"
  sensitive   = true
}

output "rds_sg_id" {
  description = "Security group ID attached to the RDS instance"
  value       = aws_security_group.rds_sg.id
}