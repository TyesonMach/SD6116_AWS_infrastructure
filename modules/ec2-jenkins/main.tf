data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
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

resource "aws_security_group" "jenkins" {
  name        = "jenkins-"
  description = "Allow SSH (22) and Jenkins (8080)"
  vpc_id      = var.vpc_id

  ingress { 
    from_port = 22   
    to_port = 22   
    protocol = "tcp" 
    cidr_blocks = [var.admin_cidr] 
    }
  # Jenkins UI
  ingress { 
    from_port = 8080 
    to_port = 8080 
    protocol = "tcp" 
    cidr_blocks = [var.admin_cidr] 
    }

  # Outbound to the Internet (for yum/docker pull, etc.)
  egress  { 
    from_port = 0 
    to_port = 0 
    protocol = "-1" 
    cidr_blocks = ["0.0.0.0/0"] 
    }

  tags = merge(var.tags, { Name = "jenkins-sg" })
}

resource "aws_iam_role" "ssm_role" {
  name               = "ec2-jenkins-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name = "ec2-jenkins-ssm-profile"
  role = aws_iam_role.ssm_role.name
}

locals {
  user_data = <<-EOF
    #!/bin/bash
    set -eux
    dnf -y update
    dnf -y install docker git
    systemctl enable --now docker
    usermod -aG docker ec2-user

    docker volume create jenkins_home
    docker run -d --name jenkins \
      -p 8080:8080 -p 50000:50000 \
      -v jenkins_home:/var/jenkins_home \
      jenkins/jenkins:lts-jdk17
  EOF
}

resource "aws_instance" "jenkins" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  iam_instance_profile        = aws_iam_instance_profile.this.name
  key_name                    = var.key_name
  user_data                   = local.user_data

  tags = merge(var.tags, { Name = "jenkins-ec2" })
}
