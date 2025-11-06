# Reusable VPC (public/private subnets + single NAT for cost-effectiveness)
terraform {
  required_providers { aws = { source = "hashicorp/aws" } }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.7"

  name = "${var.project}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_nat_gateway  = false
  single_nat_gateway  = false
  enable_dns_support   = true
  enable_dns_hostnames = true

  map_public_ip_on_launch = true
  tags = merge(var.tags, { Module = "vpc" })
}