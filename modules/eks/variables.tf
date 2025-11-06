# IDs the EKS module needs; must be passed from root
variable "vpc_id"               { type = string }
variable "cluster_subnet_ids"   { type = list(string) }          # subnets for the cluster (and default for nodegroups)
variable "nodegroup_subnet_ids" { 
    type = list(string) 
    default = null 
}  # optional override for MNGs

variable "cluster_name"    { type = string }
variable "cluster_version" { type = string }

# Node group knobs
variable "desired_size"    { type = number }
variable "min_size"        { type = number }
variable "max_size"        { type = number }
variable "instance_types"  { type = list(string) }
variable "ami_type"        { type = string }
variable "capacity_type"   { type = string }
variable "tags"            { type = map(string) }