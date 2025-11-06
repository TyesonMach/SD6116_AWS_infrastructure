variable "vpc_id"               { type = string }
variable "public_subnet_id"     { type = string }
variable "instance_type"        { 
    type = string  
    default = "t3.small" 
}
variable "key_name"             { 
    type = string  
    default = null 
} # optional SSH key
variable "admin_cidr"           { 
    type = string  
    default = "0.0.0.0/0" 
} # tighten to your IP
variable "tags"                 { 
    type = map(string) 
    default = {} 
}
