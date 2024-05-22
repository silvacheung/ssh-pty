#!/usr/bin/env bash

set -e

if [ "$(systemctl is-active kubelet)" == "active" ]; then
  echo "Kubelet运行中,跳过kubeadm引导"
  exit 0
fi

# 初始化
{{- if eq (get "hosts.0.hostname") (get "host.hostname") }}
kubeadm init --upload-certs --config /etc/kubernetes/kubeadm-config.yaml
{{- else }}
kubeadm join --config /etc/kubernetes/kubeadm-config.yaml
{{- end }}

# 拷贝文件
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 去除污点
{{- if eq (get "config.k8s.untainted") "control-plane" }}
kubectl taint nodes {{ get "host.hostname" }} node-role.kubernetes.io/control-plane=:NoSchedule-
kubectl label --overwrite node {{ get "host.hostname" }} node-role.kubernetes.io/worker-node=
{{- end }}