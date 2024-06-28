#!/usr/bin/env bash

set -e

{{- if get "config.cert-manager.enable" }}{{- else }}
exit 0
{{- end }}

echo "安装Cert-Manager"
helm repo add jetstack https://charts.jetstack.io --force-update

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version {{ get "config.cert-manager.version" }} \
  --set crds.enabled=true \
  --set replicaCount={{ get "config.cert-manager.replicas" }} \
  --set webhook.replicaCount={{ get "config.cert-manager.replicas" }} \
  --set cainjector.replicaCount={{ get "config.cert-manager.replicas" }}