#!/usr/bin/env bash
set -e

# 去除/etc/resolv.conf重指定开头结尾的行
sed -i ':a;$!{N;ba};s@# cn dns BEGIN.*# cn dns END@@' /etc/resolv.conf
sed -i '/^$/N;/\n$/N;//D' /etc/resolv.conf

# set /etc/resolv.conf
# 四川联通 DNS：119.6.6.6/124.161.87.155
# 四川电信 DNS：61.139.2.69/218.6.200.139/202.98.96.68
# 四川移动 DNS：211.137.96.205/223.87.238.22/223.5.5.5/223.6.6.6
cat >>/etc/resolv.conf<<EOF
# cn dns BEGIN
nameserver 61.139.2.69
nameserver 218.6.200.139
nameserver 202.98.96.68
nameserver 211.137.96.205
nameserver 223.87.238.22
nameserver 223.5.5.5
nameserver 223.6.6.6
nameserver 119.6.6.6
nameserver 124.161.87.155
# cn dns END
EOF

# 临时文件去重后覆盖原文件
tmpfile="$$.tmp"
awk ' !x[$0]++{print > "'$tmpfile'"}' /etc/resolv.conf
mv $tmpfile /etc/resolv.conf

# print
cat /etc/resolv.conf