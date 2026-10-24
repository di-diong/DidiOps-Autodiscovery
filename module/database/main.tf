#  RDS Subnet Group
resource "aws_db_subnet_group" "autod2026_db_subnet_group" {
  name        = "${var.name}-autod2026-db-subnet"
  subnet_ids  = [var.private_subnet1_id, var.private_subnet2_id]
  description = "Subnet group for Multi-AZ RDS deployment"

  tags = {
    Name = "${var.name}-autod2026_db_subnet_group"
  }
}

# Database credentials are managed in HashiCorp Vault (secret/database)
data "vault_generic_secret" "vault-secret" {
path = "secret/database"
}

resource "aws_db_instance" "autod2026_mysql_database" {
  identifier             = "${var.name}-db"
  db_subnet_group_name   = aws_db_subnet_group.autod2026_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_name                = "autod2026_autodiscovery_db"

  # High Availability
  multi_az = false

  # Engine Settings
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  parameter_group_name = "default.mysql8.0"

  # Storage
  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  # Credentials (fetched from Vault)
  username = "admin"
  password = "holder123"

  # Backup & Maintenance
  skip_final_snapshot = true

  # Security
  publicly_accessible = false
  deletion_protection = false
}

# RDS security group
resource "aws_security_group" "rds_sg" {
  name        = "${var.name}-rds_sg"
  description = "RDS Security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "MySQL from within the VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vault_vpc_cidr]
  }

  ingress {
    description = "MySQL from the Vault host/subnet"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vault_sg_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-rds_sg"
  }
}