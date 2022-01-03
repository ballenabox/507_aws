provider "aws" {
    region          = "ap-northeast-2"
}

module "idc" {
    source          = "../../../modules/services/idc"

    cluster_name    = var.cluster_name
    ami_linux       = var.ami_linux
    ami_ubuntu      = var.ami_ubuntu
    instance_type   = var.instance_type
    tgw_id          = var.tgw_id
}