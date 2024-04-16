#!/usr/bin/env bash

# 去除/etc/hosts重指定开头结尾的行
sed -i ':a;$!{N;ba};s@# k8s hosts BEGIN.*# k8s hosts END@@' /etc/hosts
sed -i '/^$/N;/\n$/N;//D' /etc/hosts

# set hosts
cat >>/etc/hosts<<EOF
# k8s hosts BEGIN
# <ipv4/ipv6> <hostname>.<k8s-cluster-domain> <hostname>
# eg. 172.16.0.1 my-cn-cd-01-high-001.cluster.local my-cn-cd-01-high-001
{{- $ClusterDomain := .Configs.K8s.ClusterDomain }}
{{- range $host := .Hosts }}
{{ $host.Address }} {{ $host.Hostname }} {{ $host.Hostname }}.{{ $ClusterDomain }}
{{- end }}
# k8s hosts END
EOF

# print
cat /etc/hosts