#!/usr/bin/env bash

set -e

echo "验证发行系统 >> /etc/issue"
OS="$(head -n 1 /etc/issue | awk '{split($1, arr, " "); print arr[1]}' | tr '[:upper:]' '[:lower:]')"
if [ "${OS}" != "debian" ];then
  echo "验证发行系统 >> 仅支持debian!"
  exit 1
fi

echo "验证主机网络 >> ncat"
{{- range (get "hosts") }}
ncat -zv {{ .address }} {{ .port }}
{{- end }}

echo "验证网络接口 >> ip route"
NET_IF=$(ip route | grep ' {{ get "host.internal" }} ' | grep 'proto kernel scope link src' | sed -e 's/^.*dev.//' -e 's/.proto.*//' | uniq)
if [ "${NET_IF}" == "" ]; then
  echo "验证网络接口 >> 获取接口失败"
  exit 1
fi

echo "验证主机MAC >> ip link"
ip link show ${NET_IF} | awk '/ether/ {print $2}'

echo "验证主机UUID >> /sys/class/dmi/id/product_uuid "
cat /sys/class/dmi/id/product_uuid

echo "验证主机名称 >> hostname"
hostname