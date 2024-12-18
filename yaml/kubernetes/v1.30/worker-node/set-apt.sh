#!/usr/bin/env bash

set -e

export DEBIAN_FRONTEND=noninteractive

APT_MIRROR={{ if get "config.apt.mirror" }}"{{ get "config.apt.mirror" }}"{{ else }}"http://mirrors.ustc.edu.cn"{{ end }}
APT_USERNAME={{ if get "config.apt.username" }}"{{ get "config.apt.username" }}"{{ else }}""{{ end }}
APT_PASSWORD={{ if get "config.apt.password" }}"{{ get "config.apt.password" }}"{{ else }}""{{ end }}
APT_MACHINE=$(echo "${APT_MIRROR#*//}" | awk '{split($1, arr, "/"); print arr[1]}')
APT_RELEASE=$(cat /etc/os-release | grep 'VERSION_CODENAME=' | awk '{split($1, arr, "="); print arr[2]}')

echo "更新APT源 >> 获取发行名称"
if [ -z "${APT_RELEASE}" ]; then
  APT_RELEASE=stable
fi

echo "更新APT源 >> ${APT_MIRROR}"
if [[ -n "${APT_USERNAME}" || -n "${APT_PASSWORD}" ]]; then
  mkdir -p /etc/apt/auth.conf.d
  cat > /etc/apt/auth.conf.d/auth.conf << EOF
machine ${APT_MACHINE} login ${APT_USERNAME} password ${APT_PASSWORD}
EOF
fi

if [ -f /etc/apt/sources.list ]; then
  if [ ! -f /etc/apt/sources.list.bak ]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
  fi

  cat >/etc/apt/sources.list<<EOF
deb ${APT_MIRROR}/debian ${APT_RELEASE} main non-free-firmware
deb-src ${APT_MIRROR}/debian ${APT_RELEASE} main non-free-firmware

deb ${APT_MIRROR}/debian-security ${APT_RELEASE}-security main non-free-firmware
deb-src ${APT_MIRROR}/debian-security ${APT_RELEASE}-security main non-free-firmware

deb ${APT_MIRROR}/debian ${APT_RELEASE}-updates main non-free-firmware
deb-src ${APT_MIRROR}/debian ${APT_RELEASE}-updates main non-free-firmware

deb ${APT_MIRROR}/debian ${APT_RELEASE}-backports main non-free-firmware
deb-src ${APT_MIRROR}/debian ${APT_RELEASE}-backports main non-free-firmware
EOF
fi

echo "安装APT包 >> update upgrade install"
apt -y update
apt -y upgrade
apt -y install sudo gnupg ncat selinux-basics selinux-utils curl openssl tar socat conntrack ebtables ipset ipvsadm chrony ethtool lvm2 nfs-common ceph-common
