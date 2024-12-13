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
  --version 1.16.4 \
  --namespace kube-system \
  --set operator.replicas=2 \
  --set ipam.mode=kubernetes \
  --set k8s.requireIPv4PodCIDR=true \
  --set k8sClientRateLimit.qps=15 \
  --set k8sClientRateLimit.burst=30 \
  --set k8sServiceHost={{ get "config.k8s.control_plane_endpoint.address" }} \
  --set k8sServicePort={{ get "config.k8s.control_plane_endpoint.port" }} \
  --set kubeProxyReplacement=true \
  --set kubeProxyReplacementHealthzBindAddr=0.0.0.0:10256 \
  --set containerRuntime.integration=containerd \
  --set bandwidthManager.enabled=true \
  --set bandwidthManager.bbr=true \
  --set localRedirectPolicy=true \
  --set ingressController.enabled=true \
  --set gatewayAPI.enabled=true \
  --set internalTrafficPolicy=Cluster \
  --set externalTrafficPolicy=Cluster \
  --set loadBalancer.acceleration=disabled \
  --set loadBalancer.serviceTopology=true \
  --set loadBalancer.algorithm=maglev \
  --set maglev.tableSize=131071 \
  --set maglev.hashSeed=$(head -c12 /dev/urandom | base64 -w0) \
  --set socketLB.enabled=true \
  --set socketLB.hostNamespaceOnly=true \
  --set hostFirewall.enabled=true \
  --set l2announcements.enabled=true \
  --set externalIPs.enabled=true \
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
  --set bpf.tproxy=true \
  --set bpfClockProbe=true \
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

# enable gateway API(需要先安装GatewayCRD)
# see https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/#prerequisites
#helm upgrade cilium cilium/cilium \
#  --version 1.15.7 \
#  --namespace kube-system \
#  --reuse-values \
#  --set gatewayAPI.enabled=true

# native routing mode valid data
#  --set routingMode=native \
#  --set loadBalancer.mode=hybrid \
#  --set ipv4NativeRoutingCIDR=10.0.0.0/8 \
#  --set autoDirectNodeRoutes=true \
#  --set installNoConntrackIptablesRules=true \
#  --set enableIPv4BIGTCP=true \

# cilium metrics (hubble.enabled must to true)
#  --set prometheus.enabled=false \
#  --set operator.prometheus.enabled=false \
#  --set hubble.metrics.enableOpenMetrics=false \
#  --set hubble.metrics.enabled="{dns,drop,tcp,flow,port-distribution,icmp,httpV2:exemplars=true;labelsContext=source_ip\,source_namespace\,source_workload\,destination_ip\,destination_namespace\,destination_workload\,traffic_direction}"

#查看cilium状态
#kubectl -n kube-system exec ds/cilium -- cilium-dbg status --verbose
#kubectl -n kube-system rollout restart deployment/cilium-operator
#kubectl -n kube-system rollout restart ds/cilium

#echo "安装Cilium >> 滚动更新Coredns"
#kubectl rollout restart deployment/coredns -n kube-system