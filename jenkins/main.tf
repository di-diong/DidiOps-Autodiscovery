locals {
  name = "autod2026"
}

#creating the vpc
resource "aws_vpc" "autod2026_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"


  tags = {
    Name = "${local.name}-vpc"
  }
}

#creating public subnets
resource "aws_subnet" "autod2026_public_subnet_1" {
  vpc_id     = aws_vpc.autod2026_vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "${local.name}-public_subnet_1"
  }
}

resource "aws_subnet" "autod2026_public_subnet_2" {
  vpc_id     = aws_vpc.autod2026_vpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "${local.name}-public_subnet_2"
  }
}

#creating private subnets
resource "aws_subnet" "autod2026_private_subnet_1" {
  vpc_id            = aws_vpc.autod2026_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-west-3a"


  tags = {
    Name = "${local.name}-private_subnet_1"
  }
}

resource "aws_subnet" "autod2026_private_subnet_2" {
  vpc_id            = aws_vpc.autod2026_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "eu-west-3b"

  tags = {
    Name = "${local.name}-private_subnet_2"
  }
}

#create route table for public subnets
resource "aws_route_table" "autod2026_public_rt" {
  vpc_id = aws_vpc.autod2026_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.autod2026_igw.id
  }
}

#route table association for public subnets
resource "aws_route_table_association" "autod2026_public_rt_assoc1" {
  subnet_id      = aws_subnet.autod2026_public_subnet_1.id
  route_table_id = aws_route_table.autod2026_public_rt.id
}

#creating the internet gateway
resource "aws_internet_gateway" "autod2026_igw" {
  vpc_id = aws_vpc.autod2026_vpc.id
}

# Create a resource key pair
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.key.private_key_pem
  filename        = "${local.name}-key.pem"
  file_permission = "400"
}

resource "aws_key_pair" "public_key" {
  key_name   = "${local.name}-key"
  public_key = tls_private_key.key.public_key_openssh
}


# Create ACM certificate with DNS validation
resource "aws_acm_certificate" "autod2026_acm_cert" {
  domain_name               = var.domain
  subject_alternative_names = ["*.${var.domain}"]
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name}-acm_cert"
  }
}

data "aws_route53_zone" "autod2026_acm_zone" {
  name         = var.domain
  private_zone = false
}

# Fetch DNS Validation Records for ACM Certificate
resource "aws_route53_record" "acm_validation_record" {
  for_each = {
    for dvo in aws_acm_certificate.autod2026_acm_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  # Create DNS Validation Record for ACM Certificate
  zone_id         = data.aws_route53_zone.autod2026_acm_zone.zone_id
  allow_overwrite = true
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
  depends_on      = [aws_acm_certificate.autod2026_acm_cert]
}

# Validate the ACM Certificate after DNS Record Creation
resource "aws_acm_certificate_validation" "autod2026_cert_validation" {
  certificate_arn         = aws_acm_certificate.autod2026_acm_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation_record : record.fqdn]
  depends_on              = [aws_acm_certificate.autod2026_acm_cert]
}


#creating security group for jenkins
resource "aws_security_group" "jenkins_sg" {
  name        = "${local.name}-jenkins-sg"
  description = "Allow SSH and HTTPS"
  vpc_id      = aws_vpc.autod2026_vpc.id
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # security_groups = [aws_security_group.jenkins_elb_sg.id]
  }

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-jenkins-sg"
  }
}

#creating ELB for Jenkins
resource "aws_elb" "elb_jenkins" {
  name            = "elb-jenkins"
  security_groups = [aws_security_group.jenkins_elb_sg.id]
  subnets         = [aws_subnet.autod2026_public_subnet_1.id]

  listener {
    instance_port      = 8080
    instance_protocol  = "HTTP"
    lb_port            = 443
    lb_protocol        = "HTTPS"
    ssl_certificate_id = aws_acm_certificate.autod2026_acm_cert.arn
  }
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    target              = "TCP:8080"
  }
  instances                   = [aws_instance.jenkins-server.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  tags = {
    Name = "${local.name}-jenkins-server"
  }
}

# Create Security group for the jenkins elb
resource "aws_security_group" "jenkins_elb_sg" {
  name        = "${local.name}-jenkins-elb-sg"
  description = "Allow HTTPS"
  vpc_id      = aws_vpc.autod2026_vpc.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-jenkins-elb-sg"
  }
}

data "aws_ami" "redhat" {
  most_recent = true
  owners      = ["309956199498"] # Red Hat official AWS account

  filter {
    name   = "name"
    values = ["RHEL-9.*_HVM-*-x86_64-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

#creating the jenkins server
resource "aws_instance" "jenkins-server" {
  ami                         = data.aws_ami.redhat.id
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.public_key.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name
  subnet_id                   = aws_subnet.autod2026_public_subnet_1.id
  root_block_device {
    volume_size = 20    # Size in GB
    volume_type = "gp3" # General Purpose SSD (recommended)
    encrypted   = true  # Enable encryption (best practice)
  }
  user_data = templatefile("./jenkins_userdata.sh", {
    nr_key    = var.nr_key
    nr_acc_id = var.nr_acc_id
  })
  user_data_replace_on_change = true
  metadata_options {
    http_tokens = "required"

  }

  tags = {
    Name = "${local.name}-jenkins-server"
  }
}

# Create IAM role for Jenkins server to assume  SSM role
resource "aws_iam_role" "ssm-jenkins-role" {
  name = "${local.name}-ssm-jenkins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach  AmazonSSMManaged policy to JENKIN IAM role
resource "aws_iam_role_policy_attachment" "jenkins_ssm_managed_instance_core" {
  role       = aws_iam_role.ssm-jenkins-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
# Attach ADMINISTRATOR ACCESS policy to the role
resource "aws_iam_role_policy_attachment" "jenkins-admin-role-attachment" {
  role       = aws_iam_role.ssm-jenkins-role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
# CREATE INSTANCE PROFILE FOR JENKINS SERVER
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "${local.name}-ssm-jenkins-profile"
  role = aws_iam_role.ssm-jenkins-role.name
}


# creating Security Group for Vault Server
resource "aws_security_group" "vault_sg" {
  name        = "vault-sg"
  description = "Security group for Vault and Jenkins servers allowing administrative and service ports"
  vpc_id      = aws_vpc.autod2026_vpc.id

  ingress {
    description = "Allow Vault Traffic"
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow ssh "
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow HTTP traffic for Jenkins"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP traffic for Jenkins"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    description     = "Allow all outbound traffic"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vault_sg"
  }
}

# Create a load balancer for vault server
resource "aws_elb" "vault_elb" {
  name            = "${local.name}-vault-elb"
  subnets         = [aws_subnet.autod2026_public_subnet_1.id]
  security_groups = [aws_security_group.vault_elb_sg.id]
  listener {
    instance_port      = 8200
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = aws_acm_certificate.autod2026_acm_cert.arn
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:8200"
    interval            = 30
  }
  instances                   = [aws_instance.vault_server.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  tags = {
    Name = "${local.name}-vault-elb"
  }
}


# Security Group for ELB to allow HTTPS traffic
resource "aws_security_group" "vault_elb_sg" {
  name        = "${local.name}-vault-elb-sg"
  description = "Allow HTTPS traffic to server"
  vpc_id      = aws_vpc.autod2026_vpc.id
  # Inbound: HTTP on port 80
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Outbound: Allow all traffic (to EC2)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.name}-vault-elb-sg"
  }
}

# Data source to get the latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

#creating vault server
resource "aws_instance" "vault_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.medium"
  subnet_id                   = aws_subnet.autod2026_public_subnet_1.id
  key_name                    = aws_key_pair.public_key.key_name
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.vault_ssm_profile.name
  vpc_security_group_ids      = [aws_security_group.vault_sg.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("./vault_userdata.sh", {
    region        = "eu-west-3",
    VAULT_VERSION = "1.18.3",
    key           = aws_kms_key.vault-kms-key.id,
    nr_key        = var.nr_key,
    nr_acc_id     = var.nr_acc_id
  })
  metadata_options {
    http_tokens = "required"
  }
  # Tag the instance for easy identification
  tags = {
    Name = "${local.name}-vault_server"
  }
}

# create KMS key to manage vault unseal keys
resource "aws_kms_key" "vault-kms-key" {
  description             = "An example symmetric encryption KMS key"
  enable_key_rotation     = true
  deletion_window_in_days = 20
  tags = {
    Name = "${local.name}-vault-kms-key"
  }
}
#creating and attaching an IAM role with SSM permissions to the vault instance.
resource "aws_iam_role" "vault_ssm_role" {
  name = "${local.name}-ssm-vault-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# create iam role policy to give permission to the kms role
resource "aws_iam_role_policy" "kms_policy" {
  name = "${local.name}-kms-policy"
  role = aws_iam_role.vault_ssm_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDatakey*",
          "kms:DescribeKey"
        ],
        Effect   = "Allow"
        Resource = "${aws_kms_key.vault-kms-key.arn}"
      }
    ]
  })
}

#Attach the AmazonSSMManagedInstanceCore policy
# — required for Session Manager and SSM Agent functionality.
resource "aws_iam_role_policy_attachment" "vault_ssm_attachment" {
  role       = aws_iam_role.vault_ssm_role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
# create instance profile for vault
resource "aws_iam_instance_profile" "vault_ssm_profile" {
  name = "${local.name}-ssm-vault-instance-profile"
  role = aws_iam_role.vault_ssm_role.id
}

# Create Route 53 record for vault server
resource "aws_route53_record" "vault-record" {
  zone_id = data.aws_route53_zone.autod2026_acm_zone.id
  name    = "vault.${var.domain}"
  type    = "A"
  alias {
    name                   = aws_elb.vault_elb.dns_name
    zone_id                = aws_elb.vault_elb.zone_id
    evaluate_target_health = true
  }
}

# Create Route 53 record for jenkins server
resource "aws_route53_record" "jenkins-record" {
  zone_id = data.aws_route53_zone.autod2026_acm_zone.id
  name    = "jenkins.${var.domain}"
  type    = "A"
  alias {
    name                   = aws_elb.elb_jenkins.dns_name
    zone_id                = aws_elb.elb_jenkins.zone_id
    evaluate_target_health = true
  }
}