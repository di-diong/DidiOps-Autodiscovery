variable "name" {

  description = "Name of the project or environment"
  type        = string
  default     = "autod2026"
}

variable "domain" {
  description = "Domain name for the project"
  type        = string
  default     = "didiops.space"
}

variable "region" {
  default = "eu-west-3"
}

variable "nr_key" {
  sensitive   = true
  description = "New Relic User API key (NRAK-...). Set via terraform.tfvars / TF_VAR_nr_key, never hardcode."
}

variable "nr_acc_id" {
  sensitive   = true
  description = "New Relic account ID. Set via terraform.tfvars / TF_VAR_nr_acc_id."
}