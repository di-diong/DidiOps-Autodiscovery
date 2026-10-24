locals {
  name = "autod2026"
}

# Existing Route53 Hosted Zone
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# Existing ACM Certificate (created by the jenkins/ bootstrap stack)
 data "aws_acm_certificate" "main" {
    domain      = var.domain_name
   statuses    = ["ISSUED"]
  most_recent = true
 }

module "vpc" {
  source = "./module/vpc"

  name              = var.name
  cidr_block        = var.vpc_cidr_block
  region            = var.region
  pub_subnet1_cidr  = var.pub_subnet1_cidr
  pub_subnet1_az    = var.pub_subnet1_az
  pub_subnet2_cidr  = var.pub_subnet2_cidr
  pub_subnet2_az    = var.pub_subnet2_az
  priv_subnet1_cidr = var.priv_subnet1_cidr
  priv_subnet1_az   = var.priv_subnet1_az
  priv_subnet2_cidr = var.priv_subnet2_cidr
  priv_subnet2_az   = var.priv_subnet2_az
  availability_zone = var.availability_zone
}

module "bastion" {
  source = "./module/bastion"

  name             = var.name
  instance_type    = var.instance_type
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet1_id
  key_pair_name    = module.vpc.key_pair_name
  private_key      = module.vpc.private_key
  bucket_name      = var.bucket_name
  region           = var.region
  nr_key           = var.nr_key
  nr_acc_id        = var.nr_acc_id
}

module "database" {
  source = "./module/database"

  name               = var.name
  vpc_id             = module.vpc.vpc_id
  private_subnet1_id = module.vpc.private_subnet1_id
  private_subnet2_id = module.vpc.private_subnet2_id

  vault_sg_cidr  = var.vault_sg_cidr
  vault_vpc_cidr = var.vault_vpc_cidr
}

module "nexus" {
  source = "./module/nexus"

  name = local.name
  # Nexus needs ~2.7g heap + 2.7g direct memory; t3.medium (4 GiB) OOMs, so
  # this module runs a size up regardless of the stack-wide instance_type.
  instance_type       = "t3.large"
  domain_name         = var.domain_name
  vpc_id              = module.vpc.vpc_id
  public_subnet1_id   = module.vpc.public_subnet1_id
  public_subnet2_id   = module.vpc.public_subnet2_id
  bastion_sg_id       = module.bastion.bastion_sg_id
  key_pair_name       = module.vpc.key_pair_name
  zone_id             = data.aws_route53_zone.main.zone_id
  acm_certificate_arn = "arn:aws:acm:eu-west-3:969341425810:certificate/00000000-0000-0000-0000-000000000000"
  nr_key              = var.nr_key
  nr_acc_id           = var.nr_acc_id
}

module "sonarqube" {
  source = "./module/sonarqube"

  name          = var.name
  domain_name   = var.domain_name
  instance_type = var.instance_type
  vpc_id        = module.vpc.vpc_id

  public_subnet_id  = module.vpc.public_subnet1_id
  public_subnet1_id = module.vpc.public_subnet1_id
  public_subnet2_id = module.vpc.public_subnet2_id

  bastion_sg_id = module.bastion.bastion_sg_id
  key_pair_name = module.vpc.key_pair_name

  db_host     = module.database.db_address
  db_name     = module.database.db_name
  db_user     = module.database.db_username
  db_password = module.database.db_password

  acm_certificate_arn = "arn:aws:acm:eu-west-3:969341425810:certificate/00000000-0000-0000-0000-000000000000"
  zone_id             = data.aws_route53_zone.main.zone_id
  nr_key              = var.nr_key
  nr_acc_id           = var.nr_acc_id
}

module "ansible" {
  source = "./module/ansible"

  name             = var.name
  instance_type    = var.instance_type
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet1_id
  bastion_sg_id    = module.bastion.bastion_sg_id
  key_pair_name    = module.vpc.key_pair_name
  private_key      = module.vpc.private_key
  nexus_ip         = module.nexus.nexus_private_ip
  bucket_name      = var.bucket_name
  nr_key           = var.nr_key
  nr_acc_id        = var.nr_acc_id
  nr_license_key   = var.nr_license_key
}

module "prod-docker" {
  source = "./module/prod-docker"

  name                = var.name
  instance_type       = var.instance_type
  vpc_id              = module.vpc.vpc_id
  acm_certificate_arn = "arn:aws:acm:eu-west-3:969341425810:certificate/00000000-0000-0000-0000-000000000000"
  zone_id             = data.aws_route53_zone.main.zone_id

  private_subnet1_id = module.vpc.private_subnet1_id
  private_subnet2_id = module.vpc.private_subnet2_id
  public_subnet1_id  = module.vpc.public_subnet1_id
  public_subnet2_id  = module.vpc.public_subnet2_id

  bastion_sg_id = module.bastion.bastion_sg_id
  ansible_sg_id = module.ansible.ansible_sg
  key_pair_name = module.vpc.key_pair_name
  nexus_ip      = module.nexus.nexus_private_ip

  nr_key         = var.nr_key
  nr_acc_id      = var.nr_acc_id
  nr_license_key = var.nr_license_key
}

module "stage-docker" {
  source = "./module/stage-docker"

  name                = var.name
  instance_type       = var.instance_type
  vpc_id              = module.vpc.vpc_id
  acm_certificate_arn = "arn:aws:acm:eu-west-3:969341425810:certificate/00000000-0000-0000-0000-000000000000"
  zone_id             = data.aws_route53_zone.main.zone_id

  private_subnet1_id = module.vpc.private_subnet1_id
  private_subnet2_id = module.vpc.private_subnet2_id
  public_subnet1_id  = module.vpc.public_subnet1_id
  public_subnet2_id  = module.vpc.public_subnet2_id

  bastion_sg_id = module.bastion.bastion_sg_id
  ansible_sg_id = module.ansible.ansible_sg
  key_pair_name = module.vpc.key_pair_name
  nexus_ip      = module.nexus.nexus_private_ip

  nr_key         = var.nr_key
  nr_acc_id      = var.nr_acc_id
  nr_license_key = var.nr_license_key
}