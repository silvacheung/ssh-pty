#!/usr/bin/env bash

set -e

echo "设置Nameserver >> /etc/resolv.conf "

sed -i ':a;$!{N;ba};s@# LB DNS BEGIN.*# LB DNS END@@' /etc/resolv.conf
sed -i '/^$/N;/\n$/N;//D' /etc/resolv.conf

cat >>/etc/resolv.conf<<EOF
# LB DNS BEGIN
nameserver 61.139.2.69
nameserver 211.137.96.205
# LB DNS END
EOF

TMP_FILE="$$.tmp"
awk ' !x[$0]++{print > "'$TMP_FILE'"}' /etc/resolv.conf
mv $TMP_FILE /etc/resolv.conf

cat /etc/resolv.conf