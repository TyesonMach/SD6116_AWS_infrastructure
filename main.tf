########################
# VPC: chỉ public subnet (tiết kiệm, không NAT)
########################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name = var.project_name
  cidr = "10.0.0.0/16"

  azs            = ["${var.region}a", "${var.region}b"]
  public_subnets = ["10.0.0.0/24", "10.0.1.0/24"]

  enable_nat_gateway   = false
  enable_dns_support   = true
  enable_dns_hostnames = true

  # Bật tự gán public IP cho public subnets (fix lỗi EKS node group)
  map_public_ip_on_launch = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
}

########################
# AMI Amazon Linux 2023
########################
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter { 
    name = "name"          
    values = ["al2023-ami-*-x86_64"] 
    }
  filter { 
    name = "architecture"  
    values = ["x86_64"] 
    }
  filter { 
    name = "state"         
    values = ["available"] 
    }
}

# data "aws_ssm_parameter" "al2023" {
#   name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
# }

########################
# KeyPair cho SSH
########################
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.this.public_key_openssh
}

resource "local_file" "pem" {
  filename = "${path.module}/jenkins-key.pem"
  content  = tls_private_key.this.private_key_pem
}

########################
# IAM: Jenkins = Admin
########################
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    effect = "Allow"
    principals { 
        type = "Service" 
        identifiers = ["ec2.amazonaws.com"] 
        }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "jenkins" {
  name               = "${var.project_name}-jenkins-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "jenkins_admin" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.project_name}-jenkins-profile"
  role = aws_iam_role.jenkins.name
}

########################
# SG mở hết cho Jenkins
########################
resource "aws_security_group" "jenkins" {
  name        = "${var.project_name}-jenkins-sg"
  description = "Allow ALL (lab only)"
  vpc_id      = module.vpc.vpc_id

  ingress { 
    from_port = 0 
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"] 
    }
  egress  { 
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"] 
    }
}

########################
# EC2 Jenkins: cài Docker, build image Jenkins + awscli + kubectl, run trên port 80
########################
resource "aws_instance" "jenkins" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.jenkins_instance_type
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.this.key_name
  iam_instance_profile        = aws_iam_instance_profile.jenkins.name

  # để EC2 được thay mới khi user_data/AMI đổi
  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    dnf -y update
    dnf -y install docker git
    systemctl enable --now docker
    usermod -aG docker ec2-user

    # ---- Jenkins (Docker) ----
    docker volume create jenkins_home || true
    docker run -d --name jenkins \
      -p 8080:8080 -p 50000:50000 \
      -v jenkins_home:/var/jenkins_home \
      --restart always \
      jenkins/jenkins:lts-jdk17

    # Đợi container sẵn sàng
    sleep 10

    # ---- Cài AWS CLI + kubectl TRONG CONTAINER Jenkins ----
    docker exec -u root jenkins bash -lc '
      set -eux
      apt-get update
      apt-get install -y curl unzip git groff less
      # AWS CLI v2
      curl -L "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
      unzip -q /tmp/awscliv2.zip -d /tmp
      /tmp/aws/install
      # kubectl (stable)
      KVER="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
      curl -L -o /usr/local/bin/kubectl "https://dl.k8s.io/release/$KVER/bin/linux/amd64/kubectl"
      chmod +x /usr/local/bin/kubectl
    '

    # ---- (Tuỳ chọn) Cài AWS CLI + kubectl TRÊN HOST EC2 ----
    curl -L "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install

    KVER="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
    curl -L -o /usr/local/bin/kubectl "https://dl.k8s.io/release/$KVER/bin/linux/amd64/kubectl"
    chmod +x /usr/local/bin/kubectl

    # Lưu password Jenkins lần đầu cho tiện
    docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword \
      > /root/jenkins-initial-admin-password.txt || true
  EOF

  tags = { Name = "${var.project_name}-jenkins" }
}


########################
# ECR demo (tùy chọn để đẩy image)
########################
resource "aws_ecr_repository" "demo" {
  name                 = "${var.project_name}-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

########################
# EKS tối giản: public endpoint, 1 node t3.medium (SPOT để rẻ)
########################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.24.0"

  cluster_name    = "${var.project_name}-eks"
  cluster_version = "1.30"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  # Quan trọng: dùng public endpoint, tắt private
  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = false
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  enable_cluster_creator_admin_permissions = true

  # (Khuyên) cấp quyền cho IAM local của bạn để khỏi bị 403 sau khi kết nối được:
  access_entries = {
    local_admin = {
      principal_arn = "arn:aws:iam::074905224053:user/tyeson"
      policy_associations = {
        admin = {
          policy_arn  = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  eks_managed_node_groups = {
    default = {
      name           = "ng-default"
      instance_types = [var.node_instance_type]
      capacity_type  = "SPOT"
      min_size       = 1
      max_size       = 1
      desired_size   = 1
      subnet_ids     = module.vpc.public_subnets
    }
  }

  enable_irsa = true

  cluster_addons = {
    coredns    = { most_recent = true }
    vpc-cni    = { most_recent = true }
    kube-proxy = { most_recent = true }
    aws-ebs-csi-driver = {
      most_recent = true
      service_account_role_arn = aws_iam_role.ebs_csi.arn
    }
  }
}

data "aws_iam_policy_document" "ebs_sa_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.project_name}-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_sa_assume.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}