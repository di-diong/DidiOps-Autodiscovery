variable "region" {
  default = "eu-west-3"
}

variable "name" {
  type    = string
  default = "autod2026"
}

variable "domain_name" {
  type    = string
  default = "didiops.space"
}

variable "instance_type" {
  default = "t3.medium"
}

variable "nr_key" {
  sensitive   = true
  description = "New Relic User API key (NRAK-...). Set via terraform.tfvars / TF_VAR_nr_key, never hardcode."
}

variable "nr_acc_id" {
  sensitive   = true
  description = "New Relic account ID. Set via terraform.tfvars / TF_VAR_nr_acc_id."
}

variable "nr_license_key" {
  sensitive   = true
  description = "New Relic ingest license key, used by the APM agent inside the app container. Set via terraform.tfvars / TF_VAR_nr_license_key."
}

variable "pub_subnet1_cidr" {
  type    = string
  default = "10.10.1.0/24"
}

variable "pub_subnet2_cidr" {
  type    = string
  default = "10.10.2.0/24"
}

variable "priv_subnet1_cidr" {
  type    = string
  default = "10.10.3.0/24"
}

variable "priv_subnet2_cidr" {
  type    = string
  default = "10.10.4.0/24"
}

variable "pub_subnet1_az" {
  type    = string
  default = "eu-west-3a"
}

variable "pub_subnet2_az" {
  type    = string
  default = "eu-west-3b"
}

variable "priv_subnet1_az" {
  type    = string
  default = "eu-west-3c"
}

variable "priv_subnet2_az" {
  type    = string
  default = "eu-west-3d"
}

variable "vpc_cidr_block" {
  type    = string
  default = "10.10.0.0/16"
}

variable "availability_zone" {
  type    = string
  default = "eu-west-3a"
}

variable "bucket_name" {
  type    = string
  default = "autod-state-bucket"
}

variable "vault_sg_cidr" {
  description = "CIDR block of the Vault subnet or host"
  type        = string
  default     = "0.0.0.0/0"
}

variable "vault_vpc_cidr" {
  description = "CIDR block of the Vault VPC"
  type        = string
  default     = "10.10.0.0/16"
}