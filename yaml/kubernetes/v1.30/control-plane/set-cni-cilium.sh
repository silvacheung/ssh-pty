#!/usr/bin/env bash

set -e

{{- if ne (get "hosts.0.hostname") (get "host.hostname") }}
exit 0
{{- end }}

echo "安装Cilium >> 添加cilium仓库"
helm repo add cilium https://helm.cilium.io/

# see https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/
echo "安装Cilium >> 执行cilium安装"
helm upgrade --install cilium cilium/cilium \
  --version 1.15.6 \
  --namespace kube-system \
  --set operator.replicas=2 \
  --set ipam.mode=kubernetes \
  --set k8s.requireIPv4PodCIDR=true \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost={{ get "config.k8s.control_plane_endpoint.address" }} \
  --set k8sServicePort={{ get "config.k8s.control_plane_endpoint.port" }} \
  --set kubeProxyReplacementHealthzBindAddr=0.0.0.0:10256 \
  --set containerRuntime.integration=containerd \
  --set bandwidthManager.enabled=true \
  --set bandwidthManager.bbr=true \
  --set localRedirectPolicy=true \
  --set internalTrafficPolicy=Cluster \
  --set externalTrafficPolicy=Cluster \
  --set routingMode=native \
  --set ipv4NativeRoutingCIDR={{ get "config.k8s.ipvs_exclude_cidr" }} \
  --set maglev.tableSize=131071 \
  --set maglev.hashSeed=$(head -c12 /dev/urandom | base64 -w0) \
  --set loadBalancer.mode=hybrid \
  --set loadBalancer.algorithm=maglev \
  --set loadBalancer.acceleration=best-effort \
  --set loadBalancer.serviceTopology=true \
  --set socketLB.hostNamespaceOnly=true \
  --set config.bpfMapDynamicSizeRatio=0.0025 \
  --set bpf.lbMapMax=131072 \
  --set bpf.lbExternalClusterIP=true \
  --set encryption.enabled=false \
  --set encryption.type=wireguard \
  --set encryption.wireguard.persistentKeepalive=5s \
  --set encryption.wireguard.userspaceFallback=true \
  --set encryption.nodeEncryption=false \
  --set hubble.enabled=false \
  --set hubble.relay.enabled=false \
  --set hubble.relay.replicas=1 \
  --set hubble.tls.auto.enabled=false \
  --set hubble.tls.auto.method=cronJob \
  --set hubble.ui.enabled=false \
  --set hubble.ui.replicas=1

#echo "安装Cilium >> 滚动更新Coredns"
#kubectl rollout restart deployment/coredns -n kube-system