#!/usr/bin/env bash

set -e

{{- if ne (get "config.harbor.enable") true }}
exit 0
{{- end }}

echo "安装Harbor"
helm repo add harbor {{ if get "config.harbor.repo" }}{{ get "config.harbor.repo" }}{{ else }}https://helm.goharbor.io{{ end }} {{ if get "config.harbor.username" }}--username {{ get "config.harbor.username" }}{{ end }} {{ if get "config.harbor.password" }}--password {{ get "config.harbor.password" }}{{ end }}

helm upgrade --install harbor-registry harbor/harbor \
  --version {{ get "config.harbor.version" }} \
  --set expose.type=nodePort \
  --set expose.tls.enabled=true \
  --set expose.tls.certSource=auto \
  --set expose.tls.auto.commonName=localhost \
  --set expose.nodePort.ports.http.nodePort={{ get "config.harbor.node_port_http" }} \
  --set expose.nodePort.ports.https.nodePort={{ get "config.harbor.node_port_https" }} \
  --set externalURL={{ get "config.harbor.external_url" }} \
  --set harborAdminPassword={{ get "config.harbor.admin_password" }} \
  --set secretKey=cg4N8mJ3mVkcjKq7 \
  --set internalTLS.enabled=true \
  --set internalTLS.strong_ssl_ciphers=true \
  --set internalTLS.certSource=auto \
  --set ipFamily.ipv6.enabled=true \
  --set ipFamily.ipv4.enabled=true \
  --set persistence.enabled=true \
  --set persistence.resourcePolicy=keep \
  --set persistence.imageChartStorage.disableredirect=false \
  --set persistence.imageChartStorage.type=filesystem \
  --set persistence.imageChartStorage.filesystem.rootdirectory=/storage \
  --set persistence.imageChartStorage.filesystem.maxthreads=1000 \
  --set persistence.persistentVolumeClaim.registry.storageClass={{ get "config.harbor.storage_class_name" }} \
  --set persistence.persistentVolumeClaim.registry.subPath=harbor-registry \
  --set persistence.persistentVolumeClaim.registry.accessMode=ReadWriteOnce \
  --set persistence.persistentVolumeClaim.registry.size={{ get "config.harbor.storage_size_registry" }} \
  --set persistence.persistentVolumeClaim.jobservice.jobLog.storageClass={{ get "config.harbor.storage_class_name" }} \
  --set persistence.persistentVolumeClaim.jobservice.jobLog.subPath=harbor-jobservice \
  --set persistence.persistentVolumeClaim.jobservice.jobLog.accessMode=ReadWriteOnce \
  --set persistence.persistentVolumeClaim.jobservice.jobLog.size={{ get "config.harbor.storage_size_job_service" }} \
  --set persistence.persistentVolumeClaim.database.storageClass={{ get "config.harbor.storage_class_name" }} \
  --set persistence.persistentVolumeClaim.database.subPath=harbor-database \
  --set persistence.persistentVolumeClaim.database.accessMode=ReadWriteOnce \
  --set persistence.persistentVolumeClaim.database.size={{ get "config.harbor.storage_size_database" }} \
  --set persistence.persistentVolumeClaim.redis.storageClass={{ get "config.harbor.storage_class_name" }} \
  --set persistence.persistentVolumeClaim.redis.subPath=harbor-redis \
  --set persistence.persistentVolumeClaim.redis.accessMode=ReadWriteOnce \
  --set persistence.persistentVolumeClaim.redis.size={{ get "config.harbor.storage_size_redis" }} \
  --set persistence.persistentVolumeClaim.trivy.storageClass={{ get "config.harbor.storage_class_name" }} \
  --set persistence.persistentVolumeClaim.trivy.subPath=harbor-trivy \
  --set persistence.persistentVolumeClaim.trivy.accessMode=ReadWriteOnce \
  --set persistence.persistentVolumeClaim.trivy.size={{ get "config.harbor.storage_size_trivy" }} \
  --set metrics.enabled=true \
  --set metrics.serviceMonitor.enabled={{ get "config.harbor.service_monitor" }} \
  --set cache.enabled=true \
  --set cache.expireHours=24 \
  --set nginx.image.repository=docker.io/goharbor/nginx-photon \
  --set nginx.replicas=3 \
  --set nginx.resources.requests.cpu=50m \
  --set nginx.resources.requests.memory=100Mi \
  --set nginx.resources.limits.cpu=100m \
  --set nginx.resources.limits.memory=200Mi \
  --set nginx.topologySpreadConstraints[0].maxSkew=1 \
  --set nginx.topologySpreadConstraints[0].topologyKey=kubernetes.io/hostname \
  --set nginx.topologySpreadConstraints[0].nodeTaintsPolicy=Honor \
  --set nginx.topologySpreadConstraints[0].whenUnsatisfiable=DoNotSchedule \
  --set portal.image.repository=docker.io/goharbor/harbor-portal \
  --set portal.replicas=3 \
  --set portal.resources.requests.cpu=50m \
  --set portal.resources.requests.memory=100Mi \
  --set portal.resources.limits.cpu=100m \
  --set portal.resources.limits.memory=200Mi \
  --set portal.topologySpreadConstraints[0].maxSkew=1 \
  --set portal.topologySpreadConstraints[0].topologyKey=kubernetes.io/hostname \
  --set portal.topologySpreadConstraints[0].nodeTaintsPolicy=Honor \
  --set portal.topologySpreadConstraints[0].whenUnsatisfiable=DoNotSchedule \
  --set core.image.repository=docker.io/goharbor/harbor-core \
  --set core.replicas=3 \
  --set core.resources.requests.cpu=50m \
  --set core.resources.requests.memory=100Mi \
  --set core.resources.limits.cpu=100m \
  --set core.resources.limits.memory=200Mi \
  --set core.topologySpreadConstraints[0].maxSkew=1 \
  --set core.topologySpreadConstraints[0].topologyKey=kubernetes.io/hostname \
  --set core.topologySpreadConstraints[0].nodeTaintsPolicy=Honor \
  --set core.topologySpreadConstraints[0].whenUnsatisfiable=DoNotSchedule \
  --set jobservice.image.repository=docker.io/goharbor/harbor-jobservice \
  --set jobservice.replicas=3 \
  --set jobservice.resources.requests.cpu=50m \
  --set jobservice.resources.requests.memory=100Mi \
  --set jobservice.resources.limits.cpu=100m \
  --set jobservice.resources.limits.memory=200Mi \
  --set jobservice.topologySpreadConstraints[0].maxSkew=1 \
  --set jobservice.topologySpreadConstraints[0].topologyKey=kubernetes.io/hostname \
  --set jobservice.topologySpreadConstraints[0].nodeTaintsPolicy=Honor \
  --set jobservice.topologySpreadConstraints[0].whenUnsatisfiable=DoNotSchedule \
  --set registry.replicas=3 \
  --set registry.relativeurls=false \
  --set registry.registry.image.repository=docker.io/goharbor/registry-photon \
  --set registry.registry.resources.requests.cpu=50m \
  --set registry.registry.resources.requests.memory=100Mi \
  --set registry.registry.resources.limits.cpu=100m \
  --set registry.registry.resources.limits.memory=200Mi \
  --set registry.controller.image.repository=docker.io/goharbor/harbor-registryctl \
  --set registry.controller.resources.requests.cpu=50m \
  --set registry.controller.resources.requests.memory=100Mi \
  --set registry.controller.resources.limits.cpu=100m \
  --set registry.controller.resources.limits.memory=200Mi \
  --set registry.topologySpreadConstraints[0].maxSkew=1 \
  --set registry.topologySpreadConstraints[0].topologyKey=kubernetes.io/hostname \
  --set registry.topologySpreadConstraints[0].nodeTaintsPolicy=Honor \
  --set registry.topologySpreadConstraints[0].whenUnsatisfiable=DoNotSchedule \
  --set registry.credentials.username=harbor \
  --set registry.credentials.password=ws7THbag3UdmJk9M \
  --set registry.upload_purging.enabled=true \
  --set registry.upload_purging.age=168h \
  --set registry.upload_purging.interval=24h \
  --set registry.upload_purging.dryrun=false \
  --set trivy.enabled=true \
  --set trivy.replicas=3 \
  --set trivy.image.repository=docker.io/goharbor/trivy-adapter-photon \
  --set trivy.resources.requests.cpu=50m \
  --set trivy.resources.requests.memory=100Mi \
  --set trivy.resources.limits.cpu=100m \
  --set trivy.resources.limits.memory=200Mi \
  --set trivy.topologySpreadConstraints[0].maxSkew=1 \
  --set trivy.topologySpreadConstraints[0].topologyKey=kubernetes.io/hostname \
  --set trivy.topologySpreadConstraints[0].nodeTaintsPolicy=Honor \
  --set trivy.topologySpreadConstraints[0].whenUnsatisfiable=DoNotSchedule \
  --set exporter.replicas=3 \
  --set exporter.image.repository=docker.io/goharbor/harbor-exporter \
  --set exporter.resources.requests.cpu=50m \
  --set exporter.resources.requests.memory=100Mi \
  --set exporter.resources.limits.cpu=100m \
  --set exporter.resources.limits.memory=200Mi \
  --set exporter.topologySpreadConstraints[0].maxSkew=1 \
  --set exporter.topologySpreadConstraints[0].topologyKey=kubernetes.io/hostname \
  --set exporter.topologySpreadConstraints[0].nodeTaintsPolicy=Honor \
  --set exporter.topologySpreadConstraints[0].whenUnsatisfiable=DoNotSchedule \
  --set database.type=internal \
  --set database.internal.image.repository=docker.io/goharbor/harbor-db \
  --set database.internal.resources.requests.cpu=50m \
  --set database.internal.resources.requests.memory=100Mi \
  --set database.internal.resources.limits.cpu=100m \
  --set database.internal.resources.limits.memory=500Mi \
  --set database.internal.livenessProbe.timeoutSeconds=3 \
  --set database.internal.readinessProbe.timeoutSeconds=3 \
  --set database.internal.password=9p%S@e#Sg$#V$hN1 \
  --set database.internal.shmSizeLimit=512Mi \
  --set database.internal.initContainer.migrator.resources.requests.cpu=50m \
  --set database.internal.initContainer.migrator.resources.requests.memory=50Mi \
  --set database.internal.initContainer.migrator.resources.limits.cpu=100m \
  --set database.internal.initContainer.migrator.resources.limits.memory=100Mi \
  --set database.internal.initContainer.permissions.resources.requests.cpu=50m \
  --set database.internal.initContainer.permissions.resources.requests.memory=50Mi \
  --set database.internal.initContainer.permissions.resources.limits.cpu=100m \
  --set database.internal.initContainer.permissions.resources.limits.memory=100Mi \
  --set redis.type=internal \
  --set redis.internal.image.repository=docker.io/goharbor/redis-photon \
  --set redis.internal.resources.requests.cpu=50m \
  --set redis.internal.resources.requests.memory=100Mi \
  --set redis.internal.resources.limits.cpu=100m \
  --set redis.internal.resources.limits.memory=500Mi





