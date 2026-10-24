variable "name" {
  description = "Name of the project or environment"
  type        = string
  default     = "autod2026"
}

variable "vpc_id" {
  type        = string
  description = "The VPC ID where the RDS instance will be deployed"
}

variable "private_subnet1_id" {
  type        = string
  description = "First private subnet ID for the RDS subnet group"
}

variable "private_subnet2_id" {
  type        = string
  description = "Second private subnet ID for the RDS subnet group"
}

variable "vault_sg_cidr" {
  type        = string
  description = "CIDR block of the Vault subnet or host allowed to reach the database"
}

variable "vault_vpc_cidr" {
  type        = string
  description = "CIDR block of the VPC allowed to reach the database (app + tooling instances)"
}