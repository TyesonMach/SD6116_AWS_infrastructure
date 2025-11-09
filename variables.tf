variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "project_name" {
  type    = string
  default = "devops-lab"
}

variable "jenkins_instance_type" {
  type    = string
  default = "t3.small" # theo yêu cầu
}

variable "node_instance_type" {
  type    = string
  default = "t3.medium" # theo yêu cầu
}
