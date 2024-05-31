# 使用NFS挂载存储

- (1)使用helm部署[Provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)

```shell
# 添加chart仓库
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

# 部署provisioner，根据具体需要调整部署value
# 默认的repository需要替换为:
# registry.k8s.io/sig-storage/nfs-subdir-external-provisioner --> k8s.nju.edu.cn/sig-storage/nfs-subdir-external-provisioner
helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
	--set image.repository=k8s.nju.edu.cn/sig-storage/nfs-subdir-external-provisioner \
	--set replicaCount=3 \
	--set nfs.server=192.168.0.100 \
	--set nfs.path=/exported/path \
	--set nfs.volumeName=nfs-mnt-data \
	--set nfs.reclaimPolicy=Delete \
	--set strategyType=Recreate \
	--set storageClass.name=nfs-ext-subdir \
	--set storageClass.provisionerName=k8s-sigs.io/nfs-subdir-external-provisioner \
	--set storageClass.allowVolumeExpansion=true \
	--set storageClass.reclaimPolicy=Delete \
	--set storageClass.accessModes=ReadWriteOnce \
	--set storageClass.volumeBindingMode=WaitForFirstConsumer \
	--set storageClass.onDelete=retain \
	--set resources.limits.cpu=500m \
	--set resources.limits.memory=500Mi \
	--set resources.requests.cpu=500m \
	--set resources.requests.memory=500Mi \
	--set nfs.mountOptions[0]=nfsvers=4
```

- (2)使用部署的NFS的Provisioner和storageClass部署PVC资源

```yaml
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-pvc
spec:
  storageClassName: nfs-ext-subdir
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Mi
```