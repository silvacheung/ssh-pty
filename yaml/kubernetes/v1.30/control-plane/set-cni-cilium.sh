#!/usr/bin/env bash

set -e

{{- if eq (get "hosts.0.hostname") (get "host.hostname") }}{{- else }}
exit 0
{{- end }}

echo "安装cilium"
helm repo add cilium https://helm.cilium.io/

helm upgrade --install cilium cilium/cilium \
  --version 1.15.6 \
  --namespace kube-system \
  --set ipam.mode=kubernetes \
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
  --set hubble.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.relay.replicas=3 \
  --set hubble.tls.auto.enabled=true \
  --set hubble.tls.auto.method=cronJob \
  --set hubble.ui.enabled=true \
  --set hubble.ui.replicas=1

echo "滚动更新CoreDNS"
kubectl rollout restart deployment/coredns -n kube-system