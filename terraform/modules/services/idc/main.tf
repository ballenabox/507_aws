# On-Premise라고 가정한 인프라
# VPC, Subnet, 확인용 Instance, VPN Instance로 구성
# 구성 후 VPN 연결로 서울 리전의 Transit gateway와 연결

# VPC
resource "aws_vpc" "main_vpc" {
    cidr_block              = "10.2.0.0/16"
    enable_dns_support      = true
    enable_dns_hostnames    = true
    tags                    = {
        Name = "${var.cluster_name}-vpc"
    }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
    vpc_id                  = aws_vpc.main_vpc.id
    tags                    = {
        Name = "${var.cluster_name}-igw"
    }
}

# Security group
resource "aws_security_group" "main_sg" {
    name                    = "${var.cluster_name}-sg"
    description             = "SG for IDC"
    vpc_id                  = aws_vpc.main_vpc.id
}
# Security Group Rule
resource "aws_security_group_rule" "http_rule" {
    type                    = "ingress"
    from_port               = 80
    to_port                 = 80
    protocol                = "tcp"
    cidr_blocks             = ["0.0.0.0/0"]
    security_group_id       = aws_security_group.main_sg.id
}
resource "aws_security_group_rule" "ipsec_rule1" {
    type                    = "ingress"
    from_port               = 4500
    to_port                 = 4500
    protocol                = "udp"
    cidr_blocks             = ["0.0.0.0/0"]
    security_group_id       = aws_security_group.main_sg.id
}
resource "aws_security_group_rule" "ipsec_rule2" {
    type                    = "ingress"
    from_port               = 500
    to_port                 = 500
    protocol                = "udp"
    cidr_blocks             = ["0.0.0.0/0"]
    security_group_id       = aws_security_group.main_sg.id
}
resource "aws_security_group_rule" "icmp_rule" {
    type                    = "ingress"
    from_port               = 0
    to_port                 = 0
    protocol                = "icmp"
    cidr_blocks             = ["0.0.0.0/0"]
    security_group_id       = aws_security_group.main_sg.id
}
resource "aws_security_group_rule" "ssh_rule" {
    type                    = "ingress"
    from_port               = 22
    to_port                 = 22
    protocol                = "tcp"
    cidr_blocks             = ["0.0.0.0/0"]
    security_group_id       = aws_security_group.main_sg.id
}
# Terraform은 보안 그룹 생성 시 아웃바운드 규칙을 자동 생성해주지 않는다.
resource "aws_security_group_rule" "outbound" {
    type                    = "egress"
    from_port               = 0
    to_port                 = 0
    protocol                = "-1"
    cidr_blocks             = ["0.0.0.0/0"]
    security_group_id       = aws_security_group.main_sg.id
}

# Public Route Table
resource "aws_route_table" "idc_rt" {
    vpc_id                  = aws_vpc.main_vpc.id
    tags                    = {
        Name = "${var.cluster_name}-rt"
    }
}
# Route to IGW
resource "aws_route" "public_route" {
    route_table_id          = aws_route_table.idc_rt.id
    destination_cidr_block  = "0.0.0.0/0"
    gateway_id              = aws_internet_gateway.igw.id
}

# Public Subnet
resource "aws_subnet" "public_subnet" {
    vpc_id                  = aws_vpc.main_vpc.id
    cidr_block              = "10.2.0.0/24"
    availability_zone       = "ap-northeast-2a"
    map_public_ip_on_launch = true
    tags                    = {
        Name = "${var.cluster_name}-public-subnet"
    }
}

# Subnet - Route Table Association
resource "aws_route_table_association" "SNRTassoc" {
    subnet_id               = aws_subnet.public_subnet.id
    route_table_id          = aws_route_table.idc_rt.id
}

# EC2 Instance for test
resource "aws_instance" "test" {
    ami                     = var.ami_linux
    instance_type           = var.instance_type
    key_name                = "ansible"      
    network_interface {
        network_interface_id = aws_network_interface.test.id
        device_index        = 0
    }
    tags                    = {
        Name = "test"
    }
    user_data               = <<EOF
    #!/bin/bash
    hostnamectl --static set-hostname terraform
    echo "hello world" > /home/ec2-user/test.txt
    EOF
}
resource "aws_network_interface" "test" {
    subnet_id               = aws_subnet.public_subnet.id
    private_ips             = ["10.2.0.10"]
    security_groups  = [aws_security_group.main_sg.id]
    tags                    = {
        Name                = "eni-test1"
    }
}

# EC2 Instance for CGW
resource "aws_instance" "cgw" {
    ami                     = var.ami_linux
    instance_type           = var.instance_type
    key_name                = "ansible"      
    network_interface {
        network_interface_id = aws_network_interface.cgw.id
        device_index        = 0
    }
    tags                    = {
        Name = "cgw-test"
    }
    user_data               = data.template_file.cgw_data.rendered
}
resource "aws_network_interface" "cgw" {
    subnet_id               = aws_subnet.public_subnet.id
    private_ips             = ["10.2.0.30"]
    security_groups         = [aws_security_group.main_sg.id]
    source_dest_check       = false
    tags                    = {
        Name                = "eni-test3"
    }
}
data "template_file" "cgw_data" {
  template = file("${path.module}/cgw-data.sh")
}

#=================여기까지 기본 구성===================

# 여기부터는 TGW와 연동

# IDC Route Table's Route to TGW : 10.0.0.0/8 대역대는 CGW 인스턴스로 보낸다
resource "aws_route" "cgw_route" {
    route_table_id          = aws_route_table.idc_rt.id
    destination_cidr_block  = "10.0.0.0/8"
    instance_id             = aws_instance.cgw.id
}

# CGW 인스턴스를 Customer Gateway로 지정
resource "aws_customer_gateway" "cgw" {
    bgp_asn                 = 65000
    ip_address              = aws_instance.cgw.public_ip
    type                    = "ipsec.1"
    tags                    = {
        Name                = "${var.cluster_name}-cgw"
    }
}

# TGW - CGW 간 VPN Connection 생성
resource "aws_vpn_connection" "vpn_con" {
    customer_gateway_id     = aws_customer_gateway.cgw.id
    transit_gateway_id      = var.tgw_id
    type                    = aws_customer_gateway.cgw.type
    static_routes_only      = true
    tunnel1_preshared_key   = "cloudneta"
    tunnel2_preshared_key   = "cloudneta"
}


# apply 후 cgw 인스턴스에 접속
# vpnconfig.sh 실행 : CGW 인스턴스의 퍼블릭 IP와 사이트 간 VPN 연결의 Tunnel1의 외부 IP 주소 입력
# TGW Route Table에 IDC로의 경로 생성