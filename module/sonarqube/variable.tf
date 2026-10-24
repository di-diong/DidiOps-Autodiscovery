variable "name" {
  type        = string
  default     = "aug2026"
  description = "Name of the SonarQube project or environment"

}
variable "vpc_id" {
  type        = string
  default     = "./module/vpc/vpc_id"
  description = "The VPC ID where the SonarQube instance will be deployed"
}

variable "subnet_id" {
  type        = string
  default     = "./module/vpc/public_subnet1_id"
  description = "The Subnet ID for the SonarQube EC2 instance"
}

variable "key_pair_name" {
  type        = string
  default     = "key-pair"
  description = "The name of the SSH key pair"
}

variable "zone_id" {
  type        = string
  default     = "available-zone-id"
  description = "The Route53 Zone ID for the domain"

}

variable "domain_name" {
  type        = string
  default     = "didiops.space"
  description = "The domain name for the SonarQube server"
}

variable "acm_certificate_arn" {
  type        = string
  default     = "acm-certificate-arn"
  description = "The ARN of the ACM certificate for HTTPS"
}

variable "bastion_sg" {
  type        = string
  default     = "./module/vpc/bastion_sg_id"
  description = "The security group ID for the Bastion host"

}

variable "instance_type" {
  type        = string
  default     = "t3.medium"
  description = "The EC2 instance type for the SonarQube server"
}

variable "public_subnet_id" {
  type        = string
  default     = "./module/vpc/public_subnet_id"
  description = "The ID of the first public subnet"
}

variable "db_host" {
  type        = string
  default     = "./module/database/db_endpoint"
  description = "The database endpoint for SonarQube"
}

variable "db_name" {
  type        = string
  default     = "./module/database/db_name"
  description = "The database name for SonarQube"
}

variable "db_user" {
  type        = string
  default     = "./module/database/db_username"
  description = "The database username for SonarQube"
}

variable "db_password" {
  type        = string
  default     = "./module/database/db_password"
  description = "The database password for SonarQube"
  sensitive   = true
}

variable "public_subnet1_id" {
  type        = string
  default     = "./module/vpc/public_subnet1_id"
  description = "The ID of the first public subnet"
}

variable "public_subnet2_id" {
  type        = string
  default     = "./module/vpc/public_subnet2_id"
  description = "The ID of the second public subnet"
}

variable "bastion_sg_id" {
  type        = string
  default     = "./module/vpc/bastion_sg_id"
  description = "The security group ID for the Bastion host"
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