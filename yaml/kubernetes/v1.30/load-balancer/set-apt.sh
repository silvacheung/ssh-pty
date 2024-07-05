#!/usr/bin/env bash

set -e

APT_MIRROR={{ if get "config.apt.mirror" }}"{{ get "config.apt.mirror" }}"{{ else }}"http://mirrors.ustc.edu.cn"{{ end }}
APT_USERNAME={{ if get "config.apt.username" }}"{{ get "config.apt.username" }}"{{ else }}""{{ end }}
APT_PASSWORD={{ if get "config.apt.password" }}"{{ get "config.apt.password" }}"{{ else }}""{{ end }}
APT_MACHINE=$(echo "${APT_MIRROR#*//}" | awk '{split($1, arr, "/"); print arr[1]}')

echo "更新APT源 >> ${APT_MIRROR}"
mkdir -p /etc/apt/auth.conf.d
cat > /etc/apt/auth.conf.d/auth.conf << EOF
machine ${APT_MACHINE} login ${APT_USERNAME} password ${APT_PASSWORD}
EOF

if [ -f /etc/apt/sources.list ]; then
  if [ ! -f /etc/apt/sources.list.bak ]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
  fi

  cat >/etc/apt/sources.list<<EOF
deb ${APT_MIRROR}/debian stable main non-free-firmware
deb-src ${APT_MIRROR}/debian stable main non-free-firmware

deb ${APT_MIRROR}/debian-security stable-security main non-free-firmware
deb-src ${APT_MIRROR}/debian-security stable-security main non-free-firmware

deb ${APT_MIRROR}/debian stable-updates main non-free-firmware
deb-src ${APT_MIRROR}/debian stable-updates main non-free-firmware

deb ${APT_MIRROR}/debian stable-backports main non-free-firmware
deb-src ${APT_MIRROR}/debian stable-backports main non-free-firmware
EOF
fi
