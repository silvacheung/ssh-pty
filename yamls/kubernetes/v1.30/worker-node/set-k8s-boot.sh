#!/usr/bin/env bash
set -e

if [ "$(systemctl is-active kubelet)" == "active" ]; then
  echo "Kubelet运行中,跳过kubeadm引导"
  exit 0
fi

# 初始化
{{- $this := .Host }}
{{- range $host := .Hosts }}
{{- if eq $host.Hostname $this.Hostname }}
kubeadm join --config /etc/kubernetes/kubeadm-config.yaml
{{- end }}
{{- end }}