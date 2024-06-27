#!/usr/bin/env bash

set -e

{{- if get "config.nfs.enable" }}{{- else }}
exit 0
{{- end }}

echo "安装NFS"
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

helm upgrade --install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
	--set image.repository=harbor.silvacheung.com/registry.k8s.io/sig-storage/nfs-subdir-external-provisioner \
	--set replicaCount={{ get "config.nfs.replicas" }} \
	--set nfs.server={{ get "config.nfs.server" }} \
	--set nfs.path={{ get "config.nfs.path" }} \
	--set nfs.volumeName=nfs-mnt-data \
	--set nfs.reclaimPolicy=Retain \
	--set strategyType=Recreate \
	--set storageClass.create=true \
	--set storageClass.name={{ get "config.nfs.storage_class_name" }} \
	--set storageClass.provisionerName=k8s-sigs.io/nfs-subdir-external-provisioner \
	--set storageClass.allowVolumeExpansion=true \
	--set storageClass.reclaimPolicy=Delete \
	--set storageClass.accessModes=ReadWriteOnce \
	--set storageClass.volumeBindingMode=WaitForFirstConsumer \
	--set storageClass.onDelete=retain \
	--set resources.limits.cpu=200m \
	--set resources.limits.memory=200Mi \
	--set resources.requests.cpu=100m \
	--set resources.requests.memory=100Mi \
	--set nfs.mountOptions[0]=nfsvers=4

