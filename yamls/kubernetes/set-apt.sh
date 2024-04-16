#!/usr/bin/env bash

if [ -e /etc/apt/sources.list.d/ ]; then
	rm -r /etc/apt/sources.list.d/
else
	mkdir -p /etc/apt/sources.list.d/
fi

# 安装必要包
apt update
apt -y install sudo selinux-basics selinux-utils curl openssl tar socat conntrack ebtables ipset ipvsadm chrony ethtool lvm2
apt -y upgrade sudo selinux-basics selinux-utils curl openssl tar socat conntrack ebtables ipset ipvsadm chrony ethtool lvm2