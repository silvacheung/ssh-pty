#!/usr/bin/env bash

set -e

if [ "$(systemctl is-active kubelet)" == "active" ]; then
  echo "Kubelet运行中,跳过kubeadm引导"
  exit 0
fi

# 初始化
kubeadm join --config /etc/kubernetes/kubeadm-config.yaml