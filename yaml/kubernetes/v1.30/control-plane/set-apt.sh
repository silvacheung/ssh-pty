#!/usr/bin/env bash

set -e

# 替换apt源
#if [ -f /etc/apt/sources.list ]; then
#  if [ ! -f /etc/apt/sources.list.bak ]; then
#    cp /etc/apt/sources.list /etc/apt/sources.list.bak
#  fi
#  sed -i 's/http[^*]*\/debian-security/http\:\/\/mirrors\.ustc\.edu\.cn\/debian-security/g' /etc/apt/sources.list
#  sed -i 's/http[^*]*\/debian/http\:\/\/mirrors\.ustc\.edu\.cn\/debian/g' /etc/apt/sources.list
#fi
#
#if [ -f /etc/apt/sources.list.d/debian.sources ]; then
#  if [ ! -f /etc/apt/sources.list.d/debian.sources.bak ]; then
#    cp /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources.bak
#  fi
#  sed -i 's/http[^*]*\/debian-security/http\:\/\/mirrors\.ustc\.edu\.cn\/debian-security/g' /etc/apt/sources.list.d/debian.sources
#  sed -i 's/http[^*]*\/debian/http\:\/\/mirrors\.ustc\.edu\.cn\/debian/g' /etc/apt/sources.list.d/debian.sources
#fi

APT_MIRROR="http://mirrors.ustc.edu.cn"

if [ -f /etc/apt/sources.list ]; then
  if [ ! -f /etc/apt/sources.list.bak ]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
  fi

  cat >/etc/apt/sources.list<<EOF
deb ${APT_MIRROR}/debian stable main
deb-src ${APT_MIRROR}/debian stable main

deb ${APT_MIRROR}/debian-security stable-security main
deb-src ${APT_MIRROR}/debian-security stable-security main

deb ${APT_MIRROR}/debian stable-updates main
deb-src ${APT_MIRROR}/debian stable-updates main

deb ${APT_MIRROR}/debian stable-backports main
deb-src ${APT_MIRROR}/debian stable-backports main
EOF
fi

if [ -f /etc/apt/sources.list.d/debian.sources ]; then
  if [ ! -f /etc/apt/sources.list.d/debian.sources.bak ]; then
    cp /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources.bak
  fi

  cat >/etc/apt/sources.list.d/debian.sources<<EOF
deb ${APT_MIRROR}/debian stable main
deb-src ${APT_MIRROR}/debian stable main

deb ${APT_MIRROR}/debian-security stable-security main
deb-src ${APT_MIRROR}/debian-security stable-security main

deb ${APT_MIRROR}/debian stable-updates main
deb-src ${APT_MIRROR}/debian stable-updates main

deb ${APT_MIRROR}/debian stable-backports main
deb-src ${APT_MIRROR}/debian stable-backports main
EOF
fi

# 安装必要包
apt update
apt -y install sudo gnupg ncat selinux-basics selinux-utils curl openssl tar socat conntrack ebtables ipset ipvsadm chrony ethtool lvm2
#apt -y upgrade sudo gnupg ncat selinux-basics selinux-utils curl openssl tar socat conntrack ebtables ipset ipvsadm chrony ethtool lvm2
source /etc/profile
