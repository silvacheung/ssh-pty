#!/usr/bin/env bash

set -e

echo "设置时间同步 >> chrony"

# clear old server and disable pool
sed -i '/^server/d' /etc/chrony/chrony.conf
sed -i 's/^pool /#pool /g' /etc/chrony/chrony.conf

# 检查或者添加NtpSever，多个server执行多次即可，以下是使用阿里云和腾讯的NtpServer
grep -q '^server ntp.aliyun.com' /etc/chrony/chrony.conf||sed '1a server ntp.aliyun.com iburst' -i /etc/chrony/chrony.conf
grep -q '^server time1.cloud.tencent.com' /etc/chrony/chrony.conf||sed '1a server time1.cloud.tencent.com iburst' -i /etc/chrony/chrony.conf

# 设置timezone
timedatectl set-timezone Asia/Shanghai
timedatectl set-ntp true

# 启动chrony并立即校正
systemctl enable chrony.service && systemctl restart chrony.service
chronyc makestep > /dev/null && chronyc sources