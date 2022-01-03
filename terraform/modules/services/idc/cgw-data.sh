#!/bin/bash


hostnamectl --static set-hostname IDC-CGW
yum -y install tcpdump openswan
cat >> /etc/sysctl.conf <<EOF
net.ipv4.ip_forward=1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.eth0.send_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.eth0.accept_redirects = 0
net.ipv4.conf.ip_vti0.rp_filter = 0
net.ipv4.conf.eth0.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.accept_source_route = 0
EOF

sysctl -p /etc/sysctl.conf
curl -o /etc/ipsec.d/vpnconfig.sh https://cloudneta-book.s3.ap-northeast-2.amazonaws.com/chapter8/8_lab_vpnconfig_seoul.sh
chmod +x /etc/ipsec.d/vpnconfig.sh
