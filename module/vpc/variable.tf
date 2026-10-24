variable "name" {
  default = "pet-adoption"
}
variable "cidr_block" {
  default = "10.0.0.0/16"
}
variable "pub_subnet1_cidr" {
  default = "10.0.1.0/24"
}
variable "pub_subnet1_az" {
  default = "eu-west-3a"
}
variable "pub_subnet2_cidr" {
  default = "10.0.2.0/24"
}
variable "pub_subnet2_az" {
  default = "eu-west-3b"
}
variable "priv_subnet1_cidr" {
  default = "10.0.3.0/24"
}
variable "priv_subnet1_az" {
  default = "eu-west-3a"
}
variable "priv_subnet2_cidr" {
  default = "10.0.4.0/24"
}
variable "priv_subnet2_az" {
  default = "eu-west-3b"
}
variable "availability_zone" {
  default = "eu-west-3a"
}
variable "region" {
  default = "eu-west-3"
}