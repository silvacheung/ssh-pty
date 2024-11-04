# K8s集群部署Kubevirt流程

## 安装GPU Operator

-

如果不需要环境同时用于容器或者vGPU，则不需要安装Chart，只需要打标签`kubectl label node <node-name> --overwrite nvidia.com/gpu.workload.config=vm-passthrough`

```shell
# 给不需要安装Operands的节点打上标签
kubectl label nodes <node> nvidia.com/gpu.deploy.operands=false --overwrite

# 给不需要安装驱动的节点打上标签
kubectl label nodes <node> nvidia.com/gpu.deploy.driver=false --overwrite

# 给直通GPU节点打上标签(container/vm-passthrough/vm-vgpu)
kubectl label node <node-name> --overwrite nvidia.com/gpu.workload.config=vm-passthrough

# 安装Chart（注意使用vm-passthrough时--set sandboxWorkloads.enabled=false，然后自己设置直通，否则多显卡有bug）
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia --force-update
helm upgrade --install nvidia-gpu-operator nvidia/gpu-operator -n gpu-operator \
  --create-namespace \
  --set operator.cleanupCRD=true \
  --set driver.enabled=false \
  --set driver.rdma.enabled=true \
  --set driver.rdma.useHostMofed=true \
  --set driver.useOpenKernelModules=true \
  --set sandboxWorkloads.enabled=true \
  --set toolkit.env[0].name=CONTAINERD_CONFIG \
  --set toolkit.env[0].value=/etc/containerd/config.toml \
  --set toolkit.env[1].name=CONTAINERD_SOCKET \
  --set toolkit.env[1].value=/run/containerd/containerd.sock \
  --set toolkit.env[2].name=CONTAINERD_RUNTIME_CLASS \
  --set toolkit.env[2].value=nvidia \
  --set toolkit.env[3].name=CONTAINERD_SET_AS_DEFAULT \
  --set-string toolkit.env[3].value=false
```

## 安装Kubevirt

```shell
# 查看最新版本
export VERSION=$(curl https://storage.googleapis.com/kubevirt-prow/release/kubevirt/kubevirt/stable.txt)

# 部署Kubevirt CRD
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-operator.yaml

# 部署Kubevirt CR
kubectl apply -f - <<EOF
---
apiVersion: kubevirt.io/v1
kind: KubeVirt
metadata:
  name: kubevirt
  namespace: kubevirt
spec:
  certificateRotateStrategy: {}
  configuration:
    vmRolloutStrategy: Stage
    ksmConfiguration:
      nodeLabelSelector: {}
    developerConfiguration:
      useEmulation: false
      featureGates:
      # workload
      - Root
      - HypervStrictCheck
      - CPUManager
      - CommonInstancetypesDeploymentGate
      - Sidecar
      - CustomResourceSubresources
      # compute
      - VMLiveUpdateFeatures
      - AlignCPUs
      - HostDevices
      - NUMA
      - VSOCK
      - VMPersistentState
      - AutoResourceLimitsGate
      - DisableMDEVConfiguration
      - GPU
      # network
      - HotplugNICs
      - NetworkBindingPlugins
      # storage
      - Snapshot
      - PersistentReservation
      - BlockVolume
      - ExpandDisks
      - HostDisk
      - DownwardMetrics
      - ExperimentalVirtiofsSupport
      - VolumesUpdateStrategy
      - VMExport
      - HotplugVolumes
      - DataVolumes
      - BlockMultiQueue
      - VolumeMigration
    network:
      permitBridgeInterfaceOnPodNetwork: true
      permitSlirpInterface: true
    permittedHostDevices:
      pciHostDevices:
      - externalResourceProvider: false
        pciVendorSelector: "10DE:1F08"
        resourceName: "nvidia.com/TU106_GEFORCE_RTX_2060_REV__A"
      mediatedDevices: []
  customizeComponents: {}
  imagePullPolicy: IfNotPresent
  workloadUpdateStrategy:
    workloadUpdateMethods:
    - LiveMigrate
EOF
```

## 安装CDI

```shell
# 查看最新版本
export TAG=$(curl -s -w %{redirect_url} https://github.com/kubevirt/containerized-data-importer/releases/latest)
export VERSION=$(echo ${TAG##*/})

export VERSION=$(echo ${$(curl -s -w %{redirect_url} https://github.com/kubevirt/containerized-data-importer/releases/latest)##*/})

# 部署CDI CRD
kubectl apply -f https://github.com/kubevirt/containerized-data-importer/releases/download/${$VERSION}/cdi-operator.yaml

# 部署CDI CR
kubectl apply -f - <<EOF
apiVersion: cdi.kubevirt.io/v1beta1
kind: CDI
metadata:
  name: cdi
spec:
  config:
    insecureRegistries: []
    podResourceRequirements:
      requests:
        cpu: 100m
        memory: 60M
      limits:
        cpu: 4000m
        memory: 200M
    featureGates:
    - HonorWaitForFirstConsumer
  imagePullPolicy: IfNotPresent
  infra:
    nodeSelector:
      kubernetes.io/os: linux
    tolerations:
    - key: CriticalAddonsOnly
      operator: Exists
  workload:
    nodeSelector:
      kubernetes.io/os: linux
EOF
```

## 安装hostpath-provisioner-operator

### 1.安装cert-manager

```shell
helm repo add jetstack https://charts.jetstack.io --force-update
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.15.1 \
  --set crds.enabled=true \
  --set replicaCount=1 \
  --set webhook.replicaCount=1 \
  --set cainjector.replicaCount=1
```

### 2.安装hostpath-provisioner-operator

```shell
kubectl create -f https://raw.githubusercontent.com/kubevirt/hostpath-provisioner-operator/main/deploy/namespace.yaml
kubectl create -f https://raw.githubusercontent.com/kubevirt/hostpath-provisioner-operator/main/deploy/webhook.yaml -n hostpath-provisioner
kubectl create -f https://raw.githubusercontent.com/kubevirt/hostpath-provisioner-operator/main/deploy/operator.yaml -n hostpath-provisioner
```

### 3.部署HostPathProvisioner

```shell
kubectl apply -f - <<EOF
apiVersion: hostpathprovisioner.kubevirt.io/v1beta1
kind: HostPathProvisioner
metadata:
  name: vm-hostpath-provisioner
spec:
  imagePullPolicy: Always
  storagePools:
    - name: "local"
      path: "/var/hpp-volumes"
  workload:
    nodeSelector:
      nvidia.com/gpu.workload.config: vm-passthrough
EOF
```

### 4.创建StorageClass

```shell
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: vm-host-path-csi
  namespace: default
provisioner: kubevirt.io.hostpath-provisioner
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
parameters:
  storagePool: local
EOF
```

## 给主机文件权限

```shell
chmod 777 /dev/kvm
```

## 环境准备完毕可以部署Kubevirt资源了

## 注意！！！

### 1.如果主板开启UEFI则需要使用UEFI启动

- `secureBoot`设置为`true`时显卡驱动不能工作

```yaml
# ...
spec:
  domain:
    firmware:
      bootloader:
        efi:
          secureBoot: false
    features:
      smm:
        enabled: true
# ...
```

### 2.不要使用Nvidia的Gpu设备插件来直通多Gpu

#### 出现的问题

- 在为vm指定多个相同型号的GPU时，会将Audio设备当作一个GPU来分配（可能因为他们在一个iommu组中）

#### 解决方式

- 自己为需要直通的设备设置`vfio-pci`驱动
- 获取直通设备的`vendor-ID:device-ID`,下面示例的`[10de:2684]`为`VGA`,`[10de:22ba]`为`Audio`

```shell
lspci -nnk -d 10de:

#b1:00.0 VGA compatible controller [0300]: NVIDIA Corporation AD102 [GeForce RTX 4090] [10de:2684] (rev a1)
#        Subsystem: Gigabyte Technology Co., Ltd AD102 [GeForce RTX 4090] [1458:4104]
#        Kernel driver in use: vfio-pci
#        Kernel modules: nouveau
#b1:00.1 Audio device [0403]: NVIDIA Corporation AD102 High Definition Audio Controller [10de:22ba] (rev a1)
#        Subsystem: Gigabyte Technology Co., Ltd AD102 High Definition Audio Controller [1458:4104]
#        Kernel driver in use: vfio-pci
#        Kernel modules: snd_hda_intel
```

- 为要直通的设备起一个资源名，如RTX4090显卡就叫`nvidia.gpu/RTX4090`这种
- 将资源名设置为节点的可分配资源

```shell
kubectl patch node <name> --subresource='status' --type='json' -p='[{"op": "add", "path": "/status/capacity/nvidia.com~1AD102-GEFORCE-RTX-4090", "value": "8"}]'
```

- 将`vendor-ID:device-ID`和资源名设置到直通列表

```yaml
---
apiVersion: kubevirt.io/v1
kind: KubeVirt
metadata:
  name: kubevirt
  namespace: kubevirt
spec:
  configuration:
    # ...
    permittedHostDevices:
      pciHostDevices:
        - externalResourceProvider: true
          pciVendorSelector: "10de:2684"
          resourceName: "nvidia.com/AD102-GEFORCE-RTX-4090"
      mediatedDevices: [ ]
    # ...
```

- 在创建vm时即可指定`gpus`的设备名为`nvidia.com/AD102-GEFORCE-RTX-4090`