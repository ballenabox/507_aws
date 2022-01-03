variable "ami_linux" {
    description     = "amazon linux Image ID"
    type            = string
    default     = "ami-0eb14fe5735c13eb5"
}

variable "ami_ubuntu" {
    description     = "ubuntu Image ID"
    type            = string
    default     = "ami-04876f29fd3a5e8ba"
}

variable "instance_type" {
  description = "The type of EC2 Instances to run (e.g. t2.micro)"
  type        = string
  default     = "t2.micro"
}

variable "cluster_name" {
  description = "The name to use for all the cluster resources"
  type        = string
  default     = "test"
}

variable "tgw_id" {
  description = "AWS TGW's ID"
  type        = string
  default     = "tgw-049ed61772c87047f"
}