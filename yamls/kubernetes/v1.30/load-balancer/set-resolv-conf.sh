#!/usr/bin/env bash
set -e

sed -i ':a;$!{N;ba};s@# K8S LB CN DNS BEGIN.*# K8S LB CN DNS END@@' /etc/resolv.conf
sed -i '/^$/N;/\n$/N;//D' /etc/resolv.conf

cat >>/etc/resolv.conf<<EOF
# K8S LB CN DNS BEGIN
nameserver 61.139.2.69
nameserver 211.137.96.205
# K8S LB CN DNS END
EOF

tmpFile="$$.tmp"
awk ' !x[$0]++{print > "'$tmpFile'"}' /etc/resolv.conf
mv $tmpFile /etc/resolv.conf

cat /etc/resolv.conf