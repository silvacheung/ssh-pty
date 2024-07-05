#!/usr/bin/env bash

set -e

if [ "$(systemctl is-active kubelet)" == "active" ]; then
  echo "引导创建K8S集群 >> kubelet运行中, 跳过kubeadm引导"
  exit 0
fi

echo "引导创建K8S集群 >> 开始kubeadm引导"
kubeadm join --config /etc/kubernetes/kubeadm-config.yaml --v=5