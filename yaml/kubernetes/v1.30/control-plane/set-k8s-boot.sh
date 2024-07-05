#!/usr/bin/env bash

set -e

if [ "$(systemctl is-active kubelet)" == "active" ]; then
  echo "引导创建K8S集群 >> kubelet运行中, 跳过kubeadm引导"
  exit 0
fi

# 处理挂载目录中的lost+found目录，最好在挂载的目录的上级创建挂载点，这样可以找回丢失数据
echo "引导创建K8S集群 >> 处理lost+found目录"
if [ -e /var/lib/etcd/lost+found ]; then
  rm -rf /var/lib/etcd/lost+found
fi

echo "引导创建K8S集群 >> 开始kubeadm引导"
{{- if eq (get "hosts.0.hostname") (get "host.hostname") }}
kubeadm init --upload-certs --config /etc/kubernetes/kubeadm-config.yaml --v=5
{{- else }}
kubeadm join --config /etc/kubernetes/kubeadm-config.yaml --v=5
{{- end }}

echo "引导创建K8S集群 >> 创建.kube/config文件"
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "引导创建K8S集群 >> 去除节点污点"
{{- if eq (get "config.k8s.untainted") "control-plane" }}
kubectl taint nodes {{ get "host.hostname" }} node-role.kubernetes.io/control-plane=:NoSchedule-
kubectl label --overwrite node {{ get "host.hostname" }} node-role.kubernetes.io/worker-node=
{{- end }}