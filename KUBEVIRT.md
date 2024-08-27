# kubevirt

### 查看主板BIOS是否支持虚拟化
```shell
# 输出不为0即可，如果为0则需要去设置主板开启虚拟化
egrep -c '(svm|vmx)' /proc/cpuinfo

# 查看支持的flags
grep -E "(vmx|svm)" /proc/cpuinfo 

# ----------------------------------------------------------------------------------------------------------------------
# flags: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush ... 
```

### 查看硬件虚拟化支持
```shell
apt install -y libvirt-clients

virt-host-validate qemu

# ----------------------------------------------------------------------------------------------------------------------
#  QEMU: Checking for hardware virtualization                                 : PASS
#  QEMU: Checking if device /dev/kvm exists                                   : PASS
#  QEMU: Checking if device /dev/kvm is accessible                            : PASS
#  QEMU: Checking if device /dev/vhost-net exists                             : PASS
#  QEMU: Checking if device /dev/net/tun exists                               : PASS
#  QEMU: Checking for cgroup 'cpu' controller support                         : PASS
#  QEMU: Checking for cgroup 'cpuacct' controller support                     : PASS
#  QEMU: Checking for cgroup 'cpuset' controller support                      : PASS
#  QEMU: Checking for cgroup 'memory' controller support                      : PASS
#  QEMU: Checking for cgroup 'devices' controller support                     : PASS
#  QEMU: Checking for cgroup 'blkio' controller support                       : PASS
#  QEMU: Checking for device assignment IOMMU support                         : WARN (No ACPI IVRS table found, IOMMU either disabled in BIOS or not supported by this hardware platform)
#  QEMU: Checking for secure guest support                                    : WARN (AMD Secure Encrypted Virtualization appears to be disabled in firmware.)
```

### 在 Kubernetes上安装KubeVirt
```shell
# 部署Operator
export RELEASE=$(curl https://storage.googleapis.com/kubevirt-prow/release/kubevirt/kubevirt/stable.txt)
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/${RELEASE}/kubevirt-operator.yaml

# 部署CDI
export TAG=$(curl -s -w %{redirect_url} https://github.com/kubevirt/containerized-data-importer/releases/latest)
export VERSION=$(echo ${TAG##*/})
kubectl create -f https://github.com/kubevirt/containerized-data-importer/releases/download/$VERSION/cdi-operator.yaml
kubectl create -f https://github.com/kubevirt/containerized-data-importer/releases/download/$VERSION/cdi-cr.yaml

# 创建KubeVirt(默认)
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/${RELEASE}/kubevirt-cr.yaml

# 手动标记节点的CPUManager（开启CPUManager特性门时必须设置，并且k8s必须启用CPUManager）
# 参考：https://kubernetes.io/zh-cn/docs/tasks/administer-cluster/cpu-management-policies
kubectl label --overwrite node [node_name] cpumanager=true

# 创建KubeVirt(自定义)
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
    ksmConfiguration:
      nodeLabelSelector: {}
    developerConfiguration:
      useEmulation: true
      featureGates:
        - LiveMigrate
        - Evict
        - DataVolumes
        - DisableMDEVConfiguration
        - Snapshot
        - PersistentReservation
        - CPUManager
        - CommonInstancetypesDeploymentGate
        - VMExport
        - HotplugVolumes
        - HostDisk
        - ExpandDisks
        - BlockVolume
        - GPU
    permittedHostDevices:
      pciHostDevices: []
      mediatedDevices: []
  customizeComponents: {}
  imagePullPolicy: IfNotPresent
  workloadUpdateStrategy: {}
EOF

# 等待KubeVirt组件启动
kubectl -n kubevirt wait kv kubevirt --for condition=Available
```

### 删除KubeVirt
```shell
# 要删除 KubeVirt，您应该首先删除KubeVirt自定义资源，然后删除 KubeVirt 操作员
kubectl delete -n kubevirt kubevirt kubevirt --wait=true
kubectl delete apiservices v1.subresources.kubevirt.io
kubectl delete mutatingwebhookconfigurations virt-api-mutator
kubectl delete validatingwebhookconfigurations virt-operator-validator
kubectl delete validatingwebhookconfigurations virt-api-validator

export RELEASE=$(curl https://storage.googleapis.com/kubevirt-prow/release/kubevirt/kubevirt/stable.txt)
kubectl delete -f https://github.com/kubevirt/kubevirt/releases/download/${RELEASE}/kubevirt-operator.yaml --wait=false

# Terminating：The apiservice and the webhookconfigurations need to be deleted manually due to a bug
kubectl -n kubevirt patch kv kubevirt --type=json -p '[{ "op": "remove", "path": "/metadata/finalizers" }]'
```

### 安装virtctl
```shell
export VERSION=$(curl https://storage.googleapis.com/kubevirt-prow/release/kubevirt/kubevirt/stable.txt)
export ARCH=$(uname -s | tr A-Z a-z)-$(uname -m | sed 's/x86_64/amd64/') || windows-amd64.exe
curl -L -o virtctl https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/virtctl-${VERSION}-${ARCH}
chmod +x virtctl
sudo install virtctl /usr/local/bin
```

### 创建k8s的Secret提供ssh密钥（可选）
```shell
# 生成ssh密钥
mkdir -p /root/.vmssh
ssh-keygen -m pem -t rsa -b 2048 -N "" -C "root" -f /root/.ssh/id_rsa

# 生成k8s的Secret
kubectl create secret generic vm-ssh-key-root --from-file=key1=/root/.ssh/id_rsa.pub
```

### 创建系统磁盘
- 如果需要使用本地存储：https://github.com/kubevirt/containerized-data-importer/blob/main/doc/local-storage-selector.md 和 https://kubevirt.io/user-guide/storage/disks_and_volumes/#hostdisk
- 数据卷参考：https://github.com/kubevirt/containerized-data-importer/blob/main/doc/datavolumes.md
```shell
kubectl apply -f - <<EOF
---
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata:
  name: vm-system-debian
  namespace: default
  annotations:
    cdi.kubevirt.io/allowClaimAdoption: "true"
    cdi.kubevirt.io/storage.usePopulator: "false"
spec:
  storage:
    accessModes:
    - ReadWriteOnce
    resources:
      requests:
        storage: 20Gi
    storageClassName: nfs-subdir-external
  source:
    http:
      url: http://172.16.67.200:8000/debian-12-generic-amd64.qcow2
EOF
```

### 创建数据磁盘（cdi）
```shell
kubectl apply -f - <<EOF
---
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata:
  name: vm-data-debian
  namespace: default
  annotations:
    cdi.kubevirt.io/allowClaimAdoption: "true"
    cdi.kubevirt.io/storage.usePopulator: "false"
spec:
  source:
    blank: {}
  storage:
    accessModes:
    - ReadWriteOnce
    resources:
      requests:
        storage: 50Gi
    storageClassName: nfs-subdir-external
EOF
```

### 创建数据磁盘（pvc）
```shell
kubectl apply -f - <<EOF
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: vm-data-debian
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  storageClassName: nfs-subdir-external
EOF
```

### 部署虚拟机
```shell
kubectl apply -f - <<EOF
---
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: debian
  namespace: default
spec:
  dataVolumeTemplates:
  - metadata:
      name: dv-debian
      namespace: default
    spec:
      pvc:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 20Gi
        storageClassName: nfs-subdir-external
      source:
        http:
          url: http://172.16.67.200:8000/debian-12-generic-amd64.qcow2
  running: false
  template:
    metadata:
      namespace: default
      labels:
        app.kubernetes.io/name: debian
        app.kubernetes.io/version: v1
    spec:
      domain:
        ioThreadsPolicy: auto
        clock:
          timezone: "Asia/Shanghai"
        devices:
          rng: {}
          disks:
          - name: cloudinitvolume
            dedicatedIOThread: true
            disk:
              bus: virtio
          - name: systemvolume
            dedicatedIOThread: true
            disk:
              bus: virtio
          - name: datavolume
            dedicatedIOThread: true
            disk:
              bus: virtio
        #cpu:
        #  dedicatedCpuPlacement: true
        #  isolateEmulatorThread: true
        resources:
          requests:
            cpu: 4
            memory: 8Gi
          limits:
            cpu: 4
            memory: 8Gi
      terminationGracePeriodSeconds: 0
      accessCredentials:
      - sshPublicKey:
          source:
            secret:
              secretName: vm-ssh-key-root
          propagationMethod:
            qemuGuestAgent:
              users:
              - root
      volumes:
      - name: systemvolume
        dataVolume:
          name: vm-system-debian
      - name: datavolume
        persistentVolumeClaim:
          claimName: vm-data-debian
      - name: cloudinitvolume
        cloudInitNoCloud:
          userData: |
            #cloud-config
            hostname: debian
            create_hostname_file: true
            locale: en_US.UTF-8
            timezone: Asia/Shanghai
            manage_resolv_conf: true
            resolv_conf:
              nameservers: [61.139.2.69, 211.137.96.205]
              options: {rotate: true, timeout: 1}
            ntp:
              enabled: true
              ntp_client: chrony
              servers:
              - ntp.aliyun.com
              - time1.cloud.tencent.com
            keyboard:
              layout: us
              model: pc105
              variant: ""
              options: ""
            #mounts:
            #- [/dev/vdb, /mnt/data, auto, "defaults,nofail", "0", "2"]
            users:
            - name: root
              lock_passwd: false
              plain_text_passwd: pwd123
              sudo: ALL=(ALL) NOPASSWD:ALL
            disable_root: false
            ssh_pwauth: true
            password: pwd123
            chpasswd:
              expire: false
            ssh:
              emit_keys_to_console: false
            apt:
              primary:
              - arches: [default]
                uri: http://mirrors.ustc.edu.cn/debian
              security:
              - arches: [default]
                uri: http://mirrors.ustc.edu.cn/debian-security
            package_update: true
            package_upgrade: false
            package_reboot_if_required: false
            packages:
            - vim
            runcmd:
            - sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
            - sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
            - systemctl restart sshd
            phone_home: {post: all, url: 'http://172.16.67.200:8000', tries: 1}

---
apiVersion: v1
kind: Service
metadata:
  name: vm-svc-debian
  labels: 
    kubernetes.io/service-export: "nginx"
    kubernetes.io/service-ssl: ""
spec:
  ports:
  - port: 38222
    protocol: TCP
    targetPort: 22
  selector:
    app.kubernetes.io/name: debian
    app.kubernetes.io/version: v1
  type: ClusterIP
EOF
```

### 直通GPU
- 开启系统IOMMU支持
- 安装Nvidia的GPU Operator
- 然后设置获取可以使用的资源在KubeVirt的CR中进行设备注册
```shell
# 获取资源名称和数量
kubectl get node <node> -o json | jq '.status.allocatable | with_entries(select(.key | startswith("nvidia.com/"))) | with_entries(select(.value != "0"))'

#-----------------------------------------------------------------------------------------------------------------------
# {
#   "nvidia.com/GP107_GEFORCE_GTX_1050_TI": "1"
# }

# 获取设备的PCI设备ID
lspci -nnk -d 10de:

#-----------------------------------------------------------------------------------------------------------------------
# 01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP107 [GeForce GTX 1050 Ti] [10de:1c82] (rev a1)
#        Subsystem: ASUSTeK Computer Inc. PH-GTX1050TI-4G [1043:8613]
#        Kernel driver in use: vfio-pci
#        Kernel modules: nvidia
# 01:00.1 Audio device [0403]: NVIDIA Corporation GP107GL High Definition Audio Controller [10de:0fb9] (rev a1)
#        Subsystem: ASUSTeK Computer Inc. GP107GL High Definition Audio Controller [1043:8613]
#        Kernel driver in use: vfio-pci
#        Kernel modules: snd_hda_intel


#-----------------------------------------------------------------------------------------------------------------------
# 注册直通设备
# ...
# permittedHostDevices:
#   pciHostDevices:
#   - externalResourceProvider: true
#     pciVendorSelector: "10DE:1C82"
#     resourceName: "nvidia.com/GP107_GEFORCE_GTX_1050_TI"
# ...

#-----------------------------------------------------------------------------------------------------------------------
# 在VM使用GPU资源
#devices:
#  gpus:
#  - name: gpu1
#    deviceName: nvidia.com/GP107_GEFORCE_GTX_1050_TI
```

### 安装QEMU
- 安装文档：https://www.qemu.org/download/#linux
```shell
sudo apt install -y qemu-system
```

### 安装genisoimage
```shell
sudo apt install -y genisoimage
```

### 通过ISO制作支持cloud-init的qcow2镜像
```shell
# 下载指定的linux镜像iso
sudo curl -LO https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2

# 创建cloud-init数据（user-data）
sudo cat > user-data <<EOF
#cloud-config
users:
- name: root
  lock_passwd: false
  plain_text_passwd: pwd123
  sudo: ALL=(ALL) NOPASSWD:ALL
disable_root: false
ssh_pwauth: true
password: pwd123
chpasswd:
  expire: false
apt:
  primary:
  - arches: [default]
    uri: http://mirrors.ustc.edu.cn/debian
  security:
  - arches: [default]
    uri: http://mirrors.ustc.edu.cn/debian-security
EOF

# 创建cloud-init数据（meta-data）
sudo cat > meta-data <<EOF
instance-id: m001
local-hostname: cloudos
EOF

# 创建cloud-init数据（vendor-data）
sudo cat > vendor-data <<EOF
EOF

# 创建cloud-init数据（network-config）
sudo cat > network-config <<EOF
EOF

# 创建cloud-init磁盘，并将数据文件导入
genisoimage -output cloud-init-disk.img -volid cidata -rational-rock -joliet user-data meta-data network-config vendor-data
sudo qemu-img create -f qcow2  debian-12.6.0-amd64.qcow2 20G

# 使用cloud-init数据启动虚拟机
qemu-system-x86_64 -m 1024 -smp 4 -cpu host -net nic -net user -machine type=q35,accel=kvm:tcg -nographic \
    -drive file=debian-12-generic-amd64.qcow2,index=0,format=qcow2,media=disk \
    -drive file=cloud-init-disk.img,index=1,media=cdrom

# 杀死虚拟机
kill $(ps -aux | grep qemu-system-x86_64 | head -n 1 | awk '{print $2}')
```