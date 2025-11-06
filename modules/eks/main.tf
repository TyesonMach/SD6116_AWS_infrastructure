resource "aws_launch_template" "mng_public" {
  name_prefix = "${var.cluster_name}-mng-public-"

  # EKS Managed Node Group bỏ qua associate_public_ip ở LT,
  # public IP thực tế phụ thuộc vào subnet MapPublicIpOnLaunch.
  network_interfaces {
    associate_public_ip_address = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.cluster_name}-mng-public"
    }
  }
}

locals {
  # coalesce coi [] là "non-null" => dễ bị chọn list rỗng.
  # Dùng length check an toàn hơn:
  ng_subnets = length(var.nodegroup_subnet_ids) > 0 ? var.nodegroup_subnet_ids : var.cluster_subnet_ids
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.cluster_subnet_ids  # nơi đặt ENI control plane

  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    default = {
      desired_size   = var.desired_size
      min_size       = var.min_size
      max_size       = var.max_size
      instance_types = ["t3.micro"]
      ami_type       = "AL2_x86_64"
      capacity_type  = "ON_DEMAND"

      subnet_ids = local.ng_subnets

      disk_size  = 20

      launch_template = {
        id      = aws_launch_template.mng_public.id
        version = "$Latest"
      }
    }
  }

  tags = var.tags
}
