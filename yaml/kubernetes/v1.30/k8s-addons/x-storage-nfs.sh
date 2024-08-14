#!/usr/bin/env bash

set -e

{{- if ne (get "config.nfs.enable") true }}
exit 0
{{- end }}

echo "安装NFS"
helm repo add nfs-subdir-external-provisioner {{ if get "config.nfs.repo" }}{{ get "config.nfs.repo" }}{{ else }}https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/{{ end }} {{ if get "config.nfs.username" }}--username {{ get "config.nfs.username" }}{{ end }} {{ if get "config.nfs.password" }}--password {{ get "config.nfs.password" }}{{ end }}

helm upgrade --install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --version {{ get "config.nfs.version" }} \
	--set image.repository=registry.k8s.io/sig-storage/nfs-subdir-external-provisioner \
	--set replicaCount={{ get "config.nfs.replicas" }} \
	--set nfs.server={{ get "config.nfs.server" }} \
	--set nfs.path={{ get "config.nfs.path" }} \
	--set nfs.volumeName=nfs-mnt-data \
	--set nfs.reclaimPolicy=Delete \
  {{ range $idx, $val := (get "config.nfs.mnt_options") -}}
  --set nfs.mountOptions[{{ $idx }}]={{ $val }} \
  {{ end -}}
	--set strategyType=Recreate \
	--set storageClass.create=true \
	--set storageClass.name=nfs-subdir-external \
	--set storageClass.provisionerName=k8s-sigs.io/nfs-subdir-external-provisioner \
	--set storageClass.allowVolumeExpansion=true \
	--set storageClass.reclaimPolicy=Delete \
	--set storageClass.accessModes=ReadWriteOnce \
	--set storageClass.volumeBindingMode=WaitForFirstConsumer \
	--set storageClass.onDelete=retain \
	--set resources.limits.memory=200Mi \
	--set resources.requests.cpu=50m \
	--set resources.requests.memory=50Mi

