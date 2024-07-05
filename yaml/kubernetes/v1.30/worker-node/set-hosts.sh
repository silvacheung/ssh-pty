#!/usr/bin/env bash

set -e

echo "设置主机Hosts >> /etc/hosts "

# 1.清空原来的数据
sed -i ':a;$!{N;ba};s@# K8S HOSTS BEGIN.*# K8S HOSTS END@@' /etc/hosts
sed -i '/^$/N;/\n$/N;//D' /etc/hosts

# 2.写入新数据
cat >>/etc/hosts<<EOF
# K8S HOSTS BEGIN
# <ipv4/ipv6> <hostname>.<k8s-cluster-domain> <hostname>
# eg: 172.16.0.1 my-cn-cd-01-high-001.cluster.local my-cn-cd-01-high-001
{{- if get "config.k8s.control_plane_endpoint.domain" }}
{{- if get "config.k8s.control_plane_endpoint.address" }}
{{ get "config.k8s.control_plane_endpoint.address" }} {{ get "config.k8s.control_plane_endpoint.domain" }}
{{- end }}
{{- end }}
{{ get "host.address" }} {{ get "host.hostname" }} {{ get "host.hostname" }}.cluster.local
# K8S HOSTS END
EOF

# 3.去除重复数据
TMP_FILE="$$.tmp"
awk ' !x[$0]++{print > "'$TMP_FILE'"}' /etc/hosts
mv $TMP_FILE /etc/hosts

# 4.输出最新文件
cat /etc/hosts