#!/usr/bin/env bash
set -e

sed -i ':a;$!{N;ba};s@# LB CN DNS BEGIN.*# LB CN DNS END@@' /etc/resolv.conf
sed -i '/^$/N;/\n$/N;//D' /etc/resolv.conf

cat >>/etc/resolv.conf<<EOF
# LB CN DNS BEGIN
nameserver 61.139.2.69
nameserver 218.6.200.139
nameserver 202.98.96.68
nameserver 211.137.96.205
nameserver 223.87.238.22
nameserver 223.5.5.5
nameserver 223.6.6.6
nameserver 119.6.6.6
nameserver 124.161.87.155
# LB CN DNS END
EOF

tmpFile="$$.tmp"
awk ' !x[$0]++{print > "'$tmpFile'"}' /etc/resolv.conf
mv $tmpFile /etc/resolv.conf

cat /etc/resolv.conf