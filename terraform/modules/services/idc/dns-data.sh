#!/bin/bash
          hostnamectl --static set-hostname Seoul-IDC-DNSSRV
          sed -i "s/^127.0.0.1 localhost/127.0.0.1 localhost VPC2-Seoul-IDC-DNSSRV/g" /etc/hosts
          apt-get update -y
          apt-get install bind9 bind9-doc language-pack-ko -y
          # named.conf.options
          cat <<EOF> /etc/bind/named.conf.options
          options {
             directory "/var/cache/bind";
             recursion yes;
             allow-query { any; };
             forwarders {
                   8.8.8.8;
                    };
              forward only;
              auth-nxdomain no;
          };
          zone "awsseoul.internal" {
              type forward;
              forward only;
              forwarders { 10.1.3.250; 10.1.4.250; };
          };
          zone "awssingapore.internal" {
              type forward;
              forward only;
              forwarders { 10.3.3.250; 10.3.4.250; };
          };
          zone "idcsingapore.internal" {
              type forward;
              forward only;
              forwarders { 10.4.1.200; };
          };
          EOF

          # named.conf.local
          cat <<EOF> /etc/bind/named.conf.local
          zone "idcseoul.internal" {
              type master;
              file "/etc/bind/db.idcseoul.internal"; # zone file path
          };

          zone "2.10.in-addr.arpa" {
              type master;
              file "/etc/bind/db.10.2";  # 10.2.0.0/16 subnet
          };
          EOF

          # db.idcseoul.internal
          cat <<EOF> /etc/bind/db.idcseoul.internal
          \$TTL 30
          @ IN SOA idcseoul.internal. root.idcseoul.internal. (
            2019122114 ; serial
            3600       ; refresh
            900        ; retry
            604800     ; expire
            86400      ; minimum ttl
          )

          ; dns server
          @      IN NS ns1.idcseoul.internal.

          ; ip address of dns server
          ns1    IN A  10.2.1.200

          ; Hosts
          dbsrv   IN A  10.2.1.100
          dnssrv   IN A  10.2.1.200
          EOF
          # db.10.2
          cat <<EOF> /etc/bind/db.10.2
          \$TTL 30
          @ IN SOA idcseoul.internal. root.idcseoul.internal. (
            2019122114 ; serial
            3600       ; refresh
            900        ; retry
            604800     ; expire
            86400      ; minimum ttl
          )

          ; dns server
          @      IN NS ns1.idcseoul.internal.

          ; ip address of dns server
          3      IN PTR  ns1.idcseoul.internal.

          ; A Record list
          100.1    IN PTR  dbsrv.idcseoul.internal.
          200.1    IN PTR  dnssrv.idcseoul.internal.
          EOF
          # bind9 service start
          systemctl start bind9 && systemctl enable bind9
