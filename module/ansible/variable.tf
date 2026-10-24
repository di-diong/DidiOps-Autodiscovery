variable "name" {
  type        = string
  default     = "aug2026"
  description = "Name prefix for Ansible resources"
}

variable "instance_type" {
  type        = string
  default     = "t3.small"
  description = "EC2 instance type for the Ansible control node"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the Ansible server is deployed"
}

variable "public_subnet_id" {
  type        = string
  description = "Public subnet ID for the Ansible server"
}

variable "bastion_sg_id" {
  type        = string
  description = "Security group ID of the bastion host (allowed SSH source)"
}

variable "key_pair_name" {
  type        = string
  description = "Name of the SSH key pair"
}

variable "nexus_ip" {
  type        = string
  description = "Private IP of the Nexus server"
}

variable "bucket_name" {
  type        = string
  description = "S3 bucket holding the Ansible scripts (ansible-script/ prefix)"
}

variable "private_key" {
  type        = string
  sensitive   = true
  description = "Private SSH key used by Ansible to reach managed hosts"
}

variable "nr_key" {
  type        = string
  sensitive   = true
  description = "New Relic API key"
}

variable "nr_acc_id" {
  type        = string
  sensitive   = true
  description = "New Relic account ID"
}

variable "nr_license_key" {
  type        = string
  sensitive   = true
  description = "New Relic ingest license key, passed to the app container for APM"
}