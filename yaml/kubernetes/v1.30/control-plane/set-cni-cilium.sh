#!/usr/bin/env bash

set -e

{{- if ne (get "hosts.0.hostname") (get "host.hostname") }}
exit 0
{{- end }}

echo "安装Cilium >> 添加cilium仓库"
helm repo add cilium https://helm.cilium.io/

echo "安装Cilium >> 执行cilium安装"
helm upgrade --install cilium cilium/cilium \
  --version 1.15.6 \
  --namespace kube-system \
  --set ipam.mode=kubernetes \
  --set operator.replicas=2 \
  --set k8s.requireIPv4PodCIDR=true \
  --set kubeProxyReplacement=true \
  --set kubeProxyReplacementHealthzBindAddr=0.0.0.0:10256 \
  --set containerRuntime.integration=containerd \
  --set bandwidthManager.enabled=true \
  --set bandwidthManager.bbr=true \
  --set localRedirectPolicy=true \
  --set encryption.enabled=false \
  --set encryption.type=wireguard \
  --set encryption.wireguard.persistentKeepalive=5s \
  --set encryption.wireguard.userspaceFallback=true \
  --set encryption.nodeEncryption=false \
  --set hubble.enabled=false \
  --set hubble.relay.enabled=false \
  --set hubble.relay.replicas=3 \
  --set hubble.tls.auto.enabled=false \
  --set hubble.tls.auto.method=cronJob \
  --set hubble.ui.enabled=false \
  --set hubble.ui.replicas=1

echo "安装Cilium >> 滚动更新Coredns"
kubectl rollout restart deployment/coredns -n kube-system