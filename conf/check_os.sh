#!/usr/bin/env bash

# check os release
cat /etc/issue

#check network access
{{- range .Hosts}}
nc -zv {{ .Address }} {{ .Port }}
{{- end }}

# check mac address
ip link show {{ .Host.NetIF }} | awk '/ether/ {print $2}'

# check product uuid
cat /sys/class/dmi/id/product_uuid

# check network port
#{{- range .Configs.K8s.NetworkPorts }}
#nc -zv 127.0.0.1 {{ . }}
#{{- end }}