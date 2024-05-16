#!/usr/bin/env bash
set -e

# 1.清空原来的数据
sed -i ':a;$!{N;ba};s@# K8S CN DNS BEGIN.*# K8S CN DNS END@@' /etc/resolv.conf
sed -i '/^$/N;/\n$/N;//D' /etc/resolv.conf

# 2.写入新数据
# 四川联通 DNS：119.6.6.6/124.161.87.155
# 四川电信 DNS：61.139.2.69/218.6.200.139/202.98.96.68
# 四川移动 DNS：211.137.96.205/223.87.238.22/223.5.5.5/223.6.6.6
cat >>/etc/resolv.conf<<EOF
# K8S CN DNS BEGIN
nameserver 61.139.2.69
nameserver 211.137.96.205
# K8S CN DNS END
EOF

# 3.去除重复数据
tmpfile="$$.tmp"
awk ' !x[$0]++{print > "'$tmpfile'"}' /etc/resolv.conf
mv $tmpfile /etc/resolv.conf

# 4.输出最新文件
cat /etc/resolv.conf