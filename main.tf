locals {
  tags = {
    Project = var.project
    Stack   = "dev"
    Owner   = "devops-sd6116"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.7"

  name = "${var.project}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_nat_gateway   = false
  single_nat_gateway   = false
  enable_dns_support   = true
  enable_dns_hostnames = true

  map_public_ip_on_launch = true

  tags = merge(var.tags, { Module = "vpc" })
}

module "eks" {
  source          = "./modules/eks"
  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  # Pass VPC & subnet IDs from the VPC module
  vpc_id = module.vpc.vpc_id

  cluster_subnet_ids   = module.vpc.public_subnets
  nodegroup_subnet_ids = module.vpc.public_subnets

  capacity_type  = var.capacity_type
  instance_types = var.instance_types
  ami_type       = "AL2_x86_64"
  desired_size   = var.desired_size
  min_size       = var.min_size
  max_size       = var.max_size

  tags = local.tags
}


module "ecr" {
  source       = "./modules/ecr"
  repositories = var.ecr_repos
  tags         = local.tags
}

module "jenkins_ec2" {
  source           = "./modules/ec2-jenkins"
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnets[0]
  key_name         = var.key_name
  admin_cidr       = var.admin_cidr
  tags             = local.tags
}
