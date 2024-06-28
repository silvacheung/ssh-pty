#!/usr/bin/env bash

set -e

{{- if get "config.metrics-server.enable" }}{{- else }}
exit 0
{{- end }}

echo "安装Metrics-Server"
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/

helm upgrade --install metrics-server metrics-server/metrics-server \
  --version {{ get "config.metrics-server.version" }} \
  --set image.repository=registry.k8s.io/metrics-server/metrics-server \
  --set addonResizer.image.repository=registry.k8s.io/autoscaling/addon-resizer \
  --set replicas={{ get "config.metrics-server.replicas" }} \
  --set revisionHistoryLimit=10 \
  --set podDisruptionBudget.enabled=true \
  --set podDisruptionBudget.minAvailable=1 \
  --set resources.requests.cpu=20m \
  --set resources.requests.memory=50Mi \
  --set resources.limits.cpu=50m \
  --set resources.limits.memory=100Mi \
  --set addonResizer.enabled=true \
  --set addonResizer.resources.requests.cpu=20m \
  --set addonResizer.resources.requests.memory=50Mi \
  --set addonResizer.resources.limits.cpu=50m \
  --set addonResizer.resources.limits.memory=100Mi \
  --set addonResizer.nanny.cpu=20m \
  --set addonResizer.nanny.extraCPU=10m \
  --set addonResizer.nanny.memory=50Mi \
  --set addonResizer.nanny.extraMemory=10Mi \
  --set metrics.enabled=false \
  --set serviceMonitor.enabled={{ get "config.metrics-server.service_monitor" }} \
  --set args[0]=--kubelet-insecure-tls