#!/usr/bin/env bash
set -e

# k8s优化
# see https://zhuanlan.zhihu.com/p/647149643

NET_IF=$(ip route | grep ' {{ get "host.internal" }} ' | grep 'proto kernel scope link src' | sed -e 's/^.*dev.//' -e 's/.proto.*//' | uniq)
if [ "${NET_IF}" == "" ]; then
  echo "获取主机网卡名 >> 失败"
  exit 1
fi

echo "优化K8S性能 >> 修改etcd的IO调度优先级"
ionice -c2 -n0 -p $(pgrep etcd)

#echo "优化K8S性能 >> 提高etcd对于对等网络流量优先级"
#if [ "$(tc qdisc show dev ${NET_IF} handle 1)" != "" ]; then
#  tc qdisc del dev ${NET_IF} root handle 1: prio bands 3
#fi
#
#tc qdisc add dev ${NET_IF} root handle 1: prio bands 3
#tc filter add dev ${NET_IF} parent 1: protocol ip prio 1 u32 match ip sport 2380 0xffff flowid 1:1
#tc filter add dev ${NET_IF} parent 1: protocol ip prio 1 u32 match ip dport 2380 0xffff flowid 1:1
#tc filter add dev ${NET_IF} parent 1: protocol ip prio 2 u32 match ip sport 2379 0xffff flowid 1:
#tc filter add dev ${NET_IF} parent 1: protocol ip prio 2 u32 match ip dport 2379 0xffff flowid 1:1