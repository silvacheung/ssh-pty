# 使用NFS挂载存储

- (1)所有工作节点需要安装nfs-common

```shell
apt -y install nfs-common
```

- (2)使用helm部署[Provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)

```shell
# 添加chart仓库
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

# 部署provisioner，根据具体需要调整部署value
# 默认的repository需要替换为:
# registry.k8s.io/sig-storage/nfs-subdir-external-provisioner --> k8s.nju.edu.cn/sig-storage/nfs-subdir-external-provisioner
# 不需要创建storageClass时设置'storageClass.create=false'
helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
	--set image.repository=k8s.nju.edu.cn/sig-storage/nfs-subdir-external-provisioner \
	--set replicaCount=3 \
	--set nfs.server=192.168.0.100 \
	--set nfs.path=/exported/path \
	--set nfs.volumeName=nfs-mnt-data \
	--set nfs.reclaimPolicy=Delete \
	--set strategyType=Recreate \
	--set storageClass.create=true \
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

- (3)上面已经部署了一个storageClass，我们可以直接使用，我们也可以自己创建一个
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-ext-subdir-custom
  annotations:
    nfs.io/storage-path: "nfs-path"
provisioner: k8s-sigs.io/nfs-subdir-external-provisioner
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
allowedTopologies:
  - matchLabelExpressions:
      - key: kubernetes.io/os
        values:
          - linux
mountOptions:
  - "nfsvers=4"
parameters:
  archiveOnDelete: "true"
  onDelete: "retain"
  # format: ${.PVC.<metadata>}
  pathPattern: "${.PVC.namespace}/${.PVC.annotations.nfs.io/storage-path}"
```

- (4)使用部署的NFS的Provisioner和storageClass部署PVC资源

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

---
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    name: nginx
spec:
  automountServiceAccountToken: false
  containers:
    - image: nginx:1.26-alpine
      name: nginx
      imagePullPolicy: IfNotPresent
      ports:
        - containerPort: 80
          protocol: TCP
      volumeMounts:
        - name: nginx-data
          mountPath: /var/nginx
  volumes:
    - name: nginx-data
      persistentVolumeClaim:
        claimName: nfs-pvc
```