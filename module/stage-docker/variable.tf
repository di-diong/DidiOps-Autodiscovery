variable "name" {
  default = "aug2026"
}
variable "vpc_id" {
  default = "./module/vpc/vpc_id"
}
variable "instance_type" {
  default = "t3.medium"
}
variable "key_pair_name" {
  default = "key-pair"
}
variable "bastion_sg_id" {
  default = "./module/vpc/bastion_sg_id"
}
variable "ansible_sg_id" {
  default = "./module/ansible/ansible_sg"
}
variable "private_subnet1_id" {
  default = "./module/vpc/private_subnet1_id"
}
variable "private_subnet2_id" {
  default = "./module/vpc/private_subnet2_id"
}
variable "public_subnet1_id" {
  default = "./module/vpc/public_subnet1_id"
}
variable "public_subnet2_id" {
  default = "./module/vpc/public_subnet2_id"
}
variable "zone_id" {
  default = "./module/vpc/zone_id"
}
variable "acm_certificate_arn" {
  default = "./module/vpc/acm_certificate_arn"
}
variable "nr_key" {
  default = "new-relic-api-key"
}
variable "nr_acc_id" {
  default = "new-relic-account-id"
}
variable "nr_license_key" {
  default = "new-relic-license-key"
}
variable "nexus_ip" {
  default = "nexus-server-ip"
}