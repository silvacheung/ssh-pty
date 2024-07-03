#!/usr/bin/env bash

set -e

{{- if ne (get "config.prometheus-stack.enable") true }}
exit 0
{{- end }}

echo "安装Prometheus-Stack"
helm repo add prometheus-community {{ if get "config.prometheus-stack.repo" }}{{ get "config.prometheus-stack.repo" }}{{ else }}https://prometheus-community.github.io/helm-charts{{ end }} {{ if get "config.prometheus-stack.username" }}--username {{ get "config.prometheus-stack.username" }}{{ end }} {{ if get "config.prometheus-stack.password" }}--password {{ get "config.prometheus-stack.password" }}{{ end }}

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --version {{ get "config.prometheus-stack.version" }} \
  --create-namespace \
  --namespace prometheus-stack \
  --set kubeTargetVersionOverride={{ get "config.prometheus-stack.kube_version_override" }} \
  --set namespaceOverride=prometheus-stack \
  --set kube-state-metrics.image.registry=registry.k8s.io \
  --set prometheusOperator.admissionWebhooks.patch.image.registry=registry.k8s.io \
  --set prometheusOperator.admissionWebhooks.certManager.enabled=true \
  --set prometheusOperator.admissionWebhooks.certManager.rootCert.duration=87840h0m0s \
  --set prometheusOperator.admissionWebhooks.certManager.admissionCert.duration=87840h0m0s \
  --set prometheusOperator.admissionWebhooks.deployment.enabled=true \
  --set prometheusOperator.admissionWebhooks.deployment.podDisruptionBudget.minAvailable=1 \
  --set prometheusOperator.networkPolicy.enabled=false \
  --set grafana.adminPassword={{ get "config.prometheus-stack.grafana_admin_password"}} \
  --set prometheus.prometheusSpec.enableAdminAPI=true \
  --set prometheus.networkPolicy.enabled=false \
  --set prometheus.podDisruptionBudget.enabled=true \
  --set prometheus.podDisruptionBudget.minAvailable=1 \
  --set alertmanager.podDisruptionBudget.enabled=true \
  --set alertmanager.podDisruptionBudget.minAvailable=1 \
  --set thanosRuler.enabled=true \
  --set thanosRuler.podDisruptionBudget.enabled=true \
  --set thanosRuler.podDisruptionBudget.minAvailable=1 \
  --set kubelet.serviceMonitor.attachMetadata.node=true \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName={{ get "config.prometheus-stack.storage_class_name"}} \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]=ReadWriteOnce \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi \
  --set grafana.persistence.enabled=false \
  --set grafana.persistence.type=sts \
  --set grafana.persistence.storageClassName={{ get "config.prometheus-stack.storage_class_name"}} \
  --set grafana.persistence.accessModes[0]=ReadWriteOnce \
  --set grafana.persistence.size=20Gi \
  --set grafana.persistence.finalizers[0]=kubernetes.io/pvc-protection \
  --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.storageClassName={{ get "config.prometheus-stack.storage_class_name"}} \
  --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.accessModes[0]=ReadWriteOnce \
  --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage=50Gi \
  --set thanosRuler.thanosRulerSpec.storage.volumeClaimTemplate.spec.storageClassName={{ get "config.prometheus-stack.storage_class_name"}} \
  --set thanosRuler.thanosRulerSpec.storage.volumeClaimTemplate.spec.accessModes[0]=ReadWriteOnce \
  --set thanosRuler.thanosRulerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage=50Gi \
  --set prometheusOperator.resources.requests.cpu=50m \
  --set prometheusOperator.resources.requests.memory=50Mi \
  --set prometheusOperator.resources.limits.cpu=100m \
  --set prometheusOperator.resources.limits.memory=200Mi \
  --set prometheusOperator.admissionWebhooks.deployment.resources.requests.cpu=50m \
  --set prometheusOperator.admissionWebhooks.deployment.resources.requests.memory=50Mi \
  --set prometheusOperator.admissionWebhooks.deployment.resources.limits.cpu=100m \
  --set prometheusOperator.admissionWebhooks.deployment.resources.limits.memory=200Mi \
  --set prometheusOperator.admissionWebhooks.patch.resources.requests.cpu=50m \
  --set prometheusOperator.admissionWebhooks.patch.resources.requests.memory=50Mi \
  --set prometheusOperator.admissionWebhooks.patch.resources.limits.cpu=100m \
  --set prometheusOperator.admissionWebhooks.patch.resources.limits.memory=100Mi \
  --set prometheusOperator.prometheusConfigReloader.resources.requests.cpu=50m \
  --set prometheusOperator.prometheusConfigReloader.resources.requests.memory=50Mi \
  --set prometheusOperator.prometheusConfigReloader.resources.limits.cpu=100m \
  --set prometheusOperator.prometheusConfigReloader.resources.limits.memory=100Mi \
  --set prometheus.prometheusSpec.resources.requests.cpu=50m \
  --set prometheus.prometheusSpec.resources.requests.memory=50Mi \
  --set prometheus.prometheusSpec.resources.limits.cpu=100m \
  --set prometheus.prometheusSpec.resources.limits.memory=500Mi \
  --set alertmanager.alertmanagerSpec.resources.requests.cpu=50m \
  --set alertmanager.alertmanagerSpec.resources.requests.memory=50Mi \
  --set alertmanager.alertmanagerSpec.resources.limits.cpu=100m \
  --set alertmanager.alertmanagerSpec.resources.limits.memory=500Mi \
  --set thanosRuler.thanosRulerSpec.resources.requests.cpu=50m \
  --set thanosRuler.thanosRulerSpec.resources.requests.memory=50Mi \
  --set thanosRuler.thanosRulerSpec.resources.limits.cpu=100m \
  --set thanosRuler.thanosRulerSpec.resources.limits.memory=500Mi