# Global
variable "region" { type = string }
variable "project" { type = string }
variable "cluster_name" { type = string }

# You may put either IAM user ARNs or IAM role ARNs here.
# We will automatically map ':role/' to map_roles and ':user/' to map_users.
variable "admin_iam_arns" {
  type    = list(string)
  default = []
}

# VPC
variable "vpc_cidr" { type = string }
variable "azs" { type = list(string) }
variable "public_subnets" { type = list(string) }
variable "private_subnets" { type = list(string) }
variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

# EKS node group
variable "instance_types" { type = list(string) }
variable "desired_size" { type = number }
variable "min_size" { type = number }
variable "max_size" { type = number }
variable "capacity_type" {
  type    = string
  default = "ON_DEMAND"
}

# ECR repositories
variable "ecr_repos" { type = list(string) }

# variables.tf
variable "key_name" {
  type    = string
  default = null
}
variable "admin_cidr" {
  type    = string
  default = "0.0.0.0/0"
}


