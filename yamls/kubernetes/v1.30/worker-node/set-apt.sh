#!/usr/bin/env bash
set -e

# 安装必要包
apt update
apt -y install sudo ncat selinux-basics selinux-utils curl openssl tar socat conntrack ebtables ipset ipvsadm chrony ethtool lvm2
#apt -y upgrade sudo ncat selinux-basics selinux-utils curl openssl tar socat conntrack ebtables ipset ipvsadm chrony ethtool lvm2
source /etc/profile