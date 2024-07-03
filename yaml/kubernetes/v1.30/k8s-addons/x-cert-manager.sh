#!/usr/bin/env bash

set -e

{{- if ne (get "config.cert-manager.enable") true }}
exit 0
{{- end }}

echo "安装Cert-Manager"
helm repo add jetstack {{ if get "config.cert-manager.repo" }}{{ get "config.cert-manager.repo" }}{{ else }}https://charts.jetstack.io{{ end }} --force-update {{ if get "config.cert-manager.username" }}--username {{ get "config.cert-manager.username" }}{{ end }} {{ if get "config.cert-manager.password" }}--password {{ get "config.cert-manager.password" }}{{ end }}

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version {{ get "config.cert-manager.version" }} \
  --set crds.enabled=true \
  --set replicaCount={{ get "config.cert-manager.replicas" }} \
  --set webhook.replicaCount={{ get "config.cert-manager.replicas" }} \
  --set cainjector.replicaCount={{ get "config.cert-manager.replicas" }}