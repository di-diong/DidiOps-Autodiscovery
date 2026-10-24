# Variables for the Nexus module
variable "name" {
  type        = string
  default     = "nexus"
  description = "The name prefix for resources"
}

variable "vpc_id" {
  type        = string
  description = "The VPC ID where the Nexus server will be deployed"
}

variable "instance_type" {
  type        = string
  default     = "t3.large"
  description = "EC2 instance type for the Nexus server (needs >= 8 GiB for the JVM)"
}

variable "key_pair_name" {
  type        = string
  description = "The name of the SSH key pair"
}

variable "bastion_sg_id" {
  type        = string
  description = "Security group ID of the bastion host (allowed SSH source)"
}

variable "zone_id" {
  type        = string
  description = "The Route53 Zone ID for the domain"
}

variable "domain_name" {
  type        = string
  default     = "didiops.space"
  description = "The domain name for the Nexus server"
}

variable "acm_certificate_arn" {
  type        = string
  description = "The ARN of the ACM certificate for HTTPS"
}

variable "public_subnet1_id" {
  type        = string
  description = "The ID of the first public subnet (Nexus instance + ALB)"
}

variable "public_subnet2_id" {
  type        = string
  description = "The ID of the second public subnet (ALB)"
}

variable "nr_key" {
  type        = string
  sensitive   = true
  description = "New Relic User API key"
}

variable "nr_acc_id" {
  type        = string
  sensitive   = true
  description = "New Relic account ID"
}