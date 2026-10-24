# Upload the Ansible scripts and playbook to S3 so the control node's
# userdata (ansible-script.tf) can pull them from the ansible-script/ prefix.
resource "aws_s3_object" "prod_bashscript" {
  bucket = var.bucket_name
  key    = "ansible-script/prod-bashscript.sh"
  source = "${path.module}/scripts/prod-bashscript.sh"
  etag   = filemd5("${path.module}/scripts/prod-bashscript.sh")
}

resource "aws_s3_object" "stage_bashscript" {
  bucket = var.bucket_name
  key    = "ansible-script/stage-bashscript.sh"
  source = "${path.module}/scripts/stage-bashscript.sh"
  etag   = filemd5("${path.module}/scripts/stage-bashscript.sh")
}

resource "aws_s3_object" "deployment_yml" {
  bucket = var.bucket_name
  key    = "ansible-script/deployment.yml"
  source = "${path.module}/scripts/deployment.yml"
  etag   = filemd5("${path.module}/scripts/deployment.yml")
}

# Get the latest Red Hat Enterprise Linux 9 AMI
data "aws_ami" "redhat" {
  most_recent = true

  owners = ["309956199498"]

  filter {
    name   = "name"
    values = ["RHEL-9.*_HVM-*-x86_64-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Security Group for Ansible Server
resource "aws_security_group" "ansible_sg" {
  name        = "${var.name}-ansible-sg"
  description = "Security group for Ansible server"
  vpc_id      = var.vpc_id


  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.bastion_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name}-ansible-sg"
  }
}


# IAM Role for Ansible Server
resource "aws_iam_role" "ansible_role" {
  name = "${var.name}-ansible-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach the EC2 full access policy to the role
resource "aws_iam_role_policy_attachment" "ec2_policy" {
  role       = aws_iam_role.ansible_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}
# Attach S3 full access policy to the role
resource "aws_iam_role_policy_attachment" "s3_policy" {
  role       = aws_iam_role.ansible_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
# Create IAM instance profile for ansible
resource "aws_iam_instance_profile" "ansible-profile" {
  name = "ansible-discovery-profile"
  role = aws_iam_role.ansible_role.name
}

# Create Ansible Server
resource "aws_instance" "ansible_server" {
  ami                    = data.aws_ami.redhat.id # RHEL 9
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.ansible-profile.name
  vpc_security_group_ids = [aws_security_group.ansible_sg.id]
  key_name               = var.key_pair_name
  subnet_id              = var.public_subnet_id
  user_data              = local.ansible_userdata
  # Recreate the instance (and rerun cloud-init) whenever the userdata
  # changes, e.g. when the hash embedded in it picks up a script/playbook
  # edit - otherwise an already-booted instance never re-pulls the S3 files.
  user_data_replace_on_change = true
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }
  metadata_options {
    http_tokens = "required"
  }
  tags = {
    Name = "${var.name}-ansible-server"
  }

  # Userdata pulls these objects from S3 at boot, so they must exist first.
  depends_on = [
    aws_s3_object.prod_bashscript,
    aws_s3_object.stage_bashscript,
    aws_s3_object.deployment_yml,
  ]
}