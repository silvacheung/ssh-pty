#!/usr/bin/env bash
set -e

if [[ "$(systemctl is-active kubelet)" == "active" && "$(systemctl is-enabled kubelet)" == "enabled" ]]; then
  echo "Kubelet运行中,跳过kubeadm引导"
  exit 0
fi

# 初始化
{{- $this := .Host }}
{{- range $idx, $host := .Hosts }}
{{- if eq $host.Hostname $this.Hostname }}
{{- if eq $idx 0 }}
kubeadm init --upload-certs --config /etc/kubernetes/kubeadm-config.yaml
{{- else }}
kubeadm join --config /etc/kubernetes/kubeadm-config.yaml
{{- end }}
{{- end }}
{{- end }}

# 拷贝文件
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 去除污点
{{- if eq .Configs.K8s.Untainted "control-plane" }}
kubectl taint nodes {{ $this.Hostname }} node-role.kubernetes.io/control-plane=:NoSchedule-
kubectl label --overwrite node {{ $this.Hostname }} node-role.kubernetes.io/worker-node=
{{- end }}