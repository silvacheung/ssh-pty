#!/usr/bin/env bash

set -e

# check os release
OS="$(head -n 1 /etc/issue | awk '{split($1, arr, " "); print arr[1]}' | tr '[:upper:]' '[:lower:]')"
if [[ "${OS}" != "debian" && "${OS}" != "unbutu" ]];then
  echo "not supported os, only debian/unbutu!"
  exit 1
fi

# check network access
{{- range (get "hosts") }}
ncat -zv {{ .address }} {{ .port }}
{{- end }}

# check mac address
NET_IF=$(ip route | grep ' {{ get "host.address" }} ' | grep 'proto kernel scope link src' | sed -e 's/^.*dev.//' -e 's/.proto.*//' | uniq)
if [ "${NET_IF}" == "" ]; then
  NET_IF=$(ip route | grep ' {{ get "host.internal" }} ' | grep 'proto kernel scope link src' | sed -e 's/^.*dev.//' -e 's/.proto.*//' | uniq)
fi

if [ "${NET_IF}" == "" ]; then
  echo "获取主机网卡名称失败"
  exit 1
fi

ip link show ${NET_IF} | awk '/ether/ {print $2}'

# check product uuid
cat /sys/class/dmi/id/product_uuid

# check hostname
hostname

# check network port
#nc -zv 127.0.0.1 22
#nc -zv 127.0.0.1 53
#nc -zv 127.0.0.1 179
#nc -zv 127.0.0.1 2379
#nc -zv 127.0.0.1 2380
#nc -zv 127.0.0.1 6443
#nc -zv 127.0.0.1 10250
#nc -zv 127.0.0.1 10251
#nc -zv 127.0.0.1 10252
#nc -zv 127.0.0.1 10253
#nc -zv 127.0.0.1 10254
#nc -zv 127.0.0.1 10255
#nc -zv 127.0.0.1 10256
#nc -zv 127.0.0.1 10257
#nc -zv 127.0.0.1 10258
#nc -zv 127.0.0.1 10259
#nc -zv 127.0.0.1 30000
#nc -zv 127.0.0.1 32767
#nc -zv 127.0.0.1 5000
#nc -zv 127.0.0.1 5080
#nc -zv 127.0.0.1 4240
#nc -zv 127.0.0.1 8472
#nc -zv 127.0.0.1 6081
#nc -zv 127.0.0.1 4244
#nc -zv 127.0.0.1 4245
#nc -zv 127.0.0.1 4250
#nc -zv 127.0.0.1 4251
#nc -zv 127.0.0.1 6060
#nc -zv 127.0.0.1 6061
#nc -zv 127.0.0.1 6062
#nc -zv 127.0.0.1 9878
#nc -zv 127.0.0.1 9879
#nc -zv 127.0.0.1 9880
#nc -zv 127.0.0.1 9881
#nc -zv 127.0.0.1 9882
#nc -zv 127.0.0.1 9883
#nc -zv 127.0.0.1 9884
#nc -zv 127.0.0.1 9885
#nc -zv 127.0.0.1 9886
#nc -zv 127.0.0.1 9887
#nc -zv 127.0.0.1 9888
#nc -zv 127.0.0.1 9889
#nc -zv 127.0.0.1 9890
#nc -zv 127.0.0.1 9891
#nc -zv 127.0.0.1 9893
#nc -zv 127.0.0.1 9962
#nc -zv 127.0.0.1 9963
#nc -zv 127.0.0.1 9964
#nc -zv 127.0.0.1 51871
