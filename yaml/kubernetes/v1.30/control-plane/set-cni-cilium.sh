#!/usr/bin/env bash

set -e

{{- if ne (get "hosts.0.hostname") (get "host.hostname") }}
exit 0
{{- end }}

echo "安装Cilium >> 添加cilium仓库"
helm repo add cilium https://helm.cilium.io/

# see https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/
# see https://docs.cilium.io/en/stable/operations/performance/tuning/
echo "安装Cilium >> 执行cilium安装"
helm upgrade --install cilium cilium/cilium \
  --version 1.15.7 \
  --namespace kube-system \
  --set operator.replicas=2 \
  --set ipam.mode=kubernetes \
  --set k8s.requireIPv4PodCIDR=true \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost={{ get "config.k8s.control_plane_endpoint.address" }} \
  --set k8sServicePort={{ get "config.k8s.control_plane_endpoint.port" }} \
  --set kubeProxyReplacementHealthzBindAddr=0.0.0.0:10256 \
  --set bandwidthManager.enabled=true \
  --set bandwidthManager.bbr=true \
  --set localRedirectPolicy=true \
  --set internalTrafficPolicy=Cluster \
  --set externalTrafficPolicy=Cluster \
  --set loadBalancer.acceleration=best-effort \
  --set loadBalancer.serviceTopology=true \
  --set loadBalancer.algorithm=maglev \
  --set maglev.tableSize=131071 \
  --set maglev.hashSeed=$(head -c12 /dev/urandom | base64 -w0) \
  --set bpf.masquerade=true \
  --set bpf.lbExternalClusterIP=true \
  --set bpf.mapDynamicSizeRatio=0.0025 \
  --set bpf.lbMapMax=131072 \
  --set bpf.authMapMax=524288 \
  --set bpf.ctAnyMax=524288 \
  --set bpf.ctTcpMax=786432 \
  --set bpf.natMax=786432 \
  --set bpf.neighMax=786432 \
  --set bpf.policyMapMax=32768 \
  --set encryption.enabled=false \
  --set encryption.nodeEncryption=false \
  --set encryption.type=wireguard \
  --set encryption.wireguard.userspaceFallback=true \
  --set encryption.wireguard.persistentKeepalive=5s \
  --set hubble.enabled=false \
  --set hubble.relay.enabled=false \
  --set hubble.relay.replicas=1 \
  --set hubble.ui.enabled=false \
  --set hubble.ui.replicas=1 \
  --set hubble.ui.service.type=ClusterIP \
  --set hubble.tls.auto.enabled=false \
  --set hubble.tls.auto.method=cronJob

# native routing mode valid data
#  --set routingMode=native \
#  --set loadBalancer.mode=hybrid \
#  --set ipv4NativeRoutingCIDR=10.0.0.0/8 \
#  --set autoDirectNodeRoutes=true \
#  --set installNoConntrackIptablesRules=true \
#  --set socketLB.hostNamespaceOnly=true \
#  --set enableIPv4BIGTCP=true \

#查看cilium状态
#kubectl -n kube-system exec ds/cilium -- cilium-dbg status --verbose

#echo "安装Cilium >> 滚动更新Coredns"
#kubectl rollout restart deployment/coredns -n kube-system