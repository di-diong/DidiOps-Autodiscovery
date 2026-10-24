# 1. Security Group for Nexus Server (Ports 443, 8081, 8085)
resource "aws_security_group" "nexus_sg" {
  name        = "nexus-server-sg"
  description = "Security group for Nexus server allowing web, artifact, and docker registry traffic"
  vpc_id      = var.vpc_id

  # Inbound: HTTPS / Web UI Secure Proxy
  ingress {
    description = "HTTPS Traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound: Nexus Default Web UI / Maven Repository Port
  ingress {
    description = "Nexus UI and Maven Repository"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound: Docker Hosted Repository Port
  ingress {
    description = "Nexus Docker Registry Port"
    from_port   = 8085
    to_port     = 8085
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound: SSH access from the bastion host only
  ingress {
    description     = "SSH Access from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.bastion_sg_id]
  }

  # Outbound: Allow all outbound internet access for package updates and downloads
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nexus-server-sg"
  }
}

# 2. IAM Role for SSM Agent (Allows AWS Systems Manager management without SSH keys)
resource "aws_iam_role" "nexus_ssm_role" {
  name = "nexus_ssm_instance_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_server_policy" {
  role       = aws_iam_role.nexus_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "nexus_profile" {
  name = "nexus_instance_profile"
  role = aws_iam_role.nexus_ssm_role.name
}

# 3. Data Source to Fetch Latest Red Hat Enterprise Linux (RHEL) AMI
data "aws_ami" "rhel" {
  most_recent = true
  owners      = ["309956199498"] # Red Hat official AWS account ID

  filter {
    name   = "name"
    values = ["RHEL-9*_HVM-*-x86_64*-Hourly2-GP3"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 4. EC2 Instance Provisioning (RedHat, SSM + Nexus installation)
resource "aws_instance" "nexus" {
  ami                         = data.aws_ami.rhel.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet1_id
  key_name                    = var.key_pair_name
  vpc_security_group_ids      = [aws_security_group.nexus_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.nexus_profile.name
  user_data = templatefile("${path.module}/userdata.sh", {
    nr_key    = var.nr_key
    nr_acc_id = var.nr_acc_id
  })
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "${var.name}-nexus-server"
  }
}


# Create a resource application load balancer for nexus instance
resource "aws_lb" "nexus_alb" {
  name               = "${var.name}-nexus-alb"
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.nexus_alb_sg.id
  ]
  enable_deletion_protection = false

  subnets = [
    var.public_subnet1_id,
    var.public_subnet2_id
  ]
}

# Create a resource security group for nexus application load balancer  
resource "aws_security_group" "nexus_alb_sg" {
  name        = "${var.name}-nexus-alb-sg"
  description = "Allow HTTP access to Nexus ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
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
    Name = "${var.name}-nexus-alb-sg"
  }
}

# Create a resource target group for nexus instance
resource "aws_lb_target_group" "nexus_tg" {
  name     = "${var.name}-nexus-tg"
  port     = 8081
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  # Nexus can take several minutes to boot and occasionally answers "/" with a
  # redirect, so keep the check forgiving and don't yank the target too eagerly.
  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    matcher             = "200,302,401"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

# Create a resource target group attachment for nexus instance
resource "aws_lb_target_group_attachment" "nexus" {
  target_group_arn = aws_lb_target_group.nexus_tg.arn
  target_id        = aws_instance.nexus.id
  port             = 8081
}

# Create a resource listener for nexus application load balancer
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.nexus_alb.arn

  port     = 443
  protocol = "HTTPS"

  certificate_arn = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nexus_tg.arn
  }
}

# Create a resource listener for nexus application load balancer to redirect HTTP to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.nexus_alb.arn

  port     = 80
  protocol = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }
}

# Create a resource route53 record for nexus application load balancer
resource "aws_route53_record" "nexus" {
  zone_id = var.zone_id
  name    = "nexus"
  type    = "A"

  alias {
    name                   = aws_lb.nexus_alb.dns_name
    zone_id                = aws_lb.nexus_alb.zone_id
    evaluate_target_health = true
  }
}