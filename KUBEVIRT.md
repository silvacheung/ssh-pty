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
# 查看最新版本
curl https://storage.googleapis.com/kubevirt-prow/release/kubevirt/kubevirt/stable.txt

# 部署kubevirt'CRD
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/v1.3.1/kubevirt-operator.yaml

# 部署CDI
# 查看最新版本
export TAG=$(curl -s -w %{redirect_url} https://github.com/kubevirt/containerized-data-importer/releases/latest)
export VERSION=$(echo ${TAG##*/})

# 部署CDI'CRD和CR
kubectl apply -f https://github.com/kubevirt/containerized-data-importer/releases/download/v1.60.2/cdi-operator.yaml
kubectl apply -f https://github.com/kubevirt/containerized-data-importer/releases/download/v1.60.2/cdi-cr.yaml

# 创建CDI'CR(自定义)
kubectl apply -f - <<EOF
apiVersion: cdi.kubevirt.io/v1beta1
kind: CDI
metadata:
  name: cdi
spec:
  config:
    insecureRegistries:
    - my-private-registry-host:5000
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
      # debug
      - ClusterProfiler
    network:
      permitBridgeInterfaceOnPodNetwork: true
      permitSlirpInterface: true
    permittedHostDevices:
      pciHostDevices:
      # 注意，由于nvidia插件问题，这里需要设置`externalResourceProvider: false`,不能按文档设置`true`,否则会将同一iommu组显卡的Audio设备按GPU资源进行分配
      # see https://github.com/kubevirt/kubevirt/issues/6459
      - externalResourceProvider: true
        pciVendorSelector: "10DE:1F08"
        resourceName: "nvidia.com/TU106_GEFORCE_RTX_2060_REV__A"
      mediatedDevices: []
  customizeComponents: {}
  imagePullPolicy: IfNotPresent
  workloadUpdateStrategy:
    workloadUpdateMethods:
    - LiveMigrate
EOF

# 等待KubeVirt组件启动
kubectl -n kubevirt wait kv kubevirt --for condition=Available
```

### 删除KubeVirt
```shell
# 首先删除CDI'CR和CRD（如果需要）
kubectl delete -f https://github.com/kubevirt/containerized-data-importer/releases/download/v1.60.2/cdi-cr.yaml
kubectl delete -f https://github.com/kubevirt/containerized-data-importer/releases/download/v1.60.2/cdi-operator.yaml

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
        devices:
          rng: {}
          autoattachGraphicsDevice: false
          blockMultiQueue: true
          disks:
          - name: cloudinitvolume
            dedicatedIOThread: true
            cache: none
            disk:
              bus: virtio
          - name: systemvolume
            dedicatedIOThread: true
            cache: none
            disk:
              bus: virtio
          - name: datavolume
            dedicatedIOThread: true
            cache: none
            disk:
              bus: virtio
          interfaces:
          - name: default
            macAddress: "9e:89:49:37:3a:3c"
            model: virtio
            masquerade: {}
        #cpu:
        #  dedicatedCpuPlacement: true
        #  isolateEmulatorThread: true
        resources:
          overcommitGuestOverhead: false
          requests:
            cpu: 4
            memory: 8Gi
          limits:
            cpu: 4
            memory: 8Gi
      networks:
      - name: default
        pod: {}
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
            locale: en_US
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
            users:
            - name: root
              lock_passwd: false
              plain_text_passwd: pwd123
              sudo: ALL=(ALL) NOPASSWD:ALL
            password: pwd123
            chpasswd:
              expire: false
            disable_root: false
            ssh_pwauth: true
            ssh_quiet_keygen: true
            no_ssh_fingerprints: true
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
            disk_setup:
              /dev/vdb: {layout: true, overwrite: true, table_type: mbr}
            fs_setup:
            - {device: /dev/vdb1, filesystem: ext4, label: fs3}
            mounts:
            - [/dev/vdb1, /mnt/data]
            runcmd:
            - sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
            - sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
            - sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
            - sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
            - sed -i 's/^#AuthorizedKeysFile.*/AuthorizedKeysFile .ssh\/authorized_keys/g' /etc/ssh/sshd_config
            - sed -i 's/^AuthorizedKeysFile.*/AuthorizedKeysFile .ssh\/authorized_keys/g' /etc/ssh/sshd_config
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

### 在虚拟集中安装`qemu-guest-agent`
```shell
# 安装包
sudo apt install qemu-guest-agent -y

# 修改service文件，会缺少设置导致不能开机启动
cat >> /usr/lib/systemd/system/qemu-guest-agent.service <<EOF
WantedBy=multi-user.target
EOF

# 启动service并设置开机自启
systemctl daemon-reload
systemctl start qemu-guest-agent
systemctl enable qemu-guest-agent --now
```

# 在虚拟机中安装nvidia驱动和CUDA工具库
```shell
# 更新pci
sudo apt update
sudo update-pciids

# 禁用nouveau
modprobe --remove nouveau
sudo cat > /etc/modprobe.d/blacklist-nouveau.conf << EOF
blacklist nouveau
options nouveau modeset=0
EOF
sudo update-initramfs -u

# 安装内核头文件
if [ ! -e /usr/src/linux-headers-$(uname -r) ]; then
  sudo apt install -y linux-headers-$(uname -r)
fi

# 添加库
curl -LO https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt update

# 安装所有
sudo apt -y install cuda

# 安装运行时和驱动
sudo apt -y install cuda-runtime-12-6

# 验证安装
nvidia-smi
```

### 虚拟机安装`miniconda`(https://docs.anaconda.com/miniconda/)
```shell
# 安装miniconda3
mkdir -p /usr/local/miniconda3
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /usr/local/miniconda3/miniconda.sh
bash /usr/local/miniconda3/miniconda.sh -b -u -p /usr/local/miniconda3
rm /usr/local/miniconda3/miniconda.sh

# 激活conda环境
source /usr/local/miniconda3/bin/activate

# 退出conda环境
source .bashrc
```

### 重置虚拟机中的cloud-init初始化信息
```shell
# 删除目录下文件即可
sudo rm -rf /var/lib/cloud/*

# 或者
cloud-init clean
```

### 虚拟机导出
```shell

```

### 制作自定义镜像规则
- 1.准备ubuntu16.04/18.04/20.04/22.04/24.04 基础镜像（cloud-ubuntu16.04.qcow2）
- 2.准备安装了qemu-guest-agent/ssh/nfs-common/允许root和密钥登录/python7/8/10/12的镜像（cloud-ubuntu16.04-python3.0.qcow2）
- 3.准备安装了对应显卡cuda和驱动的镜像（cloud-ubuntu16.04-python3.0-cuda12.6-10de1f08.qcow2）
- 4.准备安装了对应版本AI框架的镜像(cloud-ubuntu16.04-python3.0-cuda12.6-10de1f08-pytorch1.3.1.qcow2)
- 5.基于cuda镜像制作出各种社区流行框架(cloud-ubuntu16.04-python3.0-cuda12.6-10de1f08-pytorch1.3.1-xxxxx.qcow2)
```shell
# qemu-guest-agent
apt update
apt install qemu-guest-agent -y
cat >> /usr/lib/systemd/system/qemu-guest-agent.service <<EOF
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl start qemu-guest-agent
systemctl enable qemu-guest-agent --now

# ssh
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
sed -i 's/^#AuthorizedKeysFile.*/AuthorizedKeysFile .ssh\/authorized_keys/g' /etc/ssh/sshd_config
sed -i 's/^AuthorizedKeysFile.*/AuthorizedKeysFile .ssh\/authorized_keys/g' /etc/ssh/sshd_config

# nfs-common
apt install nfs-common -y

# python
# 进入python官网(https://www.python.org/downloads/source/)
# 下载要安装的版本
# --enable-optimizations优化二进制文件，但是构建会变慢
# --prefix=/usr/local可以修改默认安装位置
# altinstall安装不会覆盖系统python,不要使用标准的make install,因为它将覆盖默认的系统python3二进制文件
apt update
apt install -y curl build-essential libssl-dev zlib1g-dev libncurses5-dev libncursesw5-dev libreadline-dev libsqlite3-dev libgdbm-dev libdb5.3-dev libbz2-dev libexpat1-dev liblzma-dev tk-dev libffi-dev
curl -LO https://www.python.org/ftp/python/3.8.18/Python-3.8.18.tgz
tar -xvf Python-3.8.18.tgz
cd Python-3.8.18
./configure --enable-optimizations --prefix=/usr/local
make && make altinstall

# 创建软链使用指定版本
update-alternatives --install /usr/bin/python python /usr/local/bin/python3.8 100
update-alternatives --install /usr/bin/pip pip /usr/local/bin/pip3.8 100

# 设置pip源
pip config set global.index-url https://mirrors.aliyun.com/pypi/simple

# 创建并生效python虚拟环境(可选，不然root账号会报警报)
python -m venv env-name
source env-name/bin/activate

# 停用虚拟环境只需要在虚拟环境shell中执行命令
deactivate
```

### cuda-12-6安装
```shell
# 添加nvidia库
sudo apt update
sudo apt install -y --no-install-recommends gnupg2 curl ca-certificates
sudo curl -LO https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb

# 基础运行时镜像> 安装运行时
sudo apt update
sudo apt install -y --no-install-recommends cuda-runtime-12-6

# 基础运行时镜像> 安装兼容包（可选）
sudo apt install -y --no-install-recommends cuda-compat-12-6

# 基础运行时镜像> 安装library
sudo apt install -y --no-install-recommends libnpp-12-6=12.3.1.23-1
sudo apt install -y --no-install-recommends libnccl2=2.22.3-1+cuda12.6

# 基础运行时+cudnn镜像> 安装cudnn
sudo apt install -y --no-install-recommends libcudnn9-cuda-12=9.3.0.75-1
apt-mark hold libcudnn9-cuda-12

# 基础运行时+dev镜像 > 安装开发库包
sudo apt install -y --no-install-recommends cuda-libraries-dev-12-6
```

### kubevirt镜像导出
```yaml
# 制作镜像时的虚拟机清单
---
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: image-gen
spec:
  runStrategy: Manual
  dataVolumeTemplates:
  - metadata:
      name: image-gen
    spec:
      storage:
        storageClassName: vm-host-path-csi
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 30Gi
      source:
        http:
          url: http://172.16.67.200:8000/ubuntu-24.04-server-cloudimg-amd64.img
  template:
    metadata:
      labels:
        app.kubernetes.io/name: image-gen
    spec:
      nodeSelector:
        kubernetes.io/hostname: lwy-cn-chengdu-1-std-43-172-16-67-12
      domain:
        ioThreadsPolicy: auto
        devices:
          rng: {}
          autoattachGraphicsDevice: false
          blockMultiQueue: true
          disks:
            - name: system
              tag: vda
              cache: none
              io: native
              bootOrder: 1
              dedicatedIOThread: false
              disk:
                bus: virtio
            - name: cloud-init
              tag: vdc
              cache: none
              io: native
              bootOrder: 4
              dedicatedIOThread: false
              disk:
                bus: virtio
          gpus:
            - deviceName: nvidia.com/TU106_GEFORCE_RTX_2060_REV__A
              name: gpu0
        resources:
          overcommitGuestOverhead: false
          requests:
            cpu: 4
            memory: 8Gi
          limits:
            cpu: 4
            memory: 8Gi
      dnsPolicy: None
      dnsConfig:
        nameservers: [119.29.29.29, 10.16.0.10, 8.8.8.8]
      terminationGracePeriodSeconds: 180
      volumes:
        - name: system
          dataVolume:
            name: image-gen
        - name: cloud-init
          cloudInitNoCloud:
            networkData: |
              network:
                version: 2
                ethernets:
                  enp1s0:
                    dhcp4: true
                    dhcp6: true
                    match:
                      name: enp*
            userData: |
              #cloud-config
              timezone: Asia/Shanghai
              users:
                - name: root
                  lock_passwd: false
                  plain_text_passwd: "123456"
                  sudo: ALL=(ALL) NOPASSWD:ALL
              password: "123456"
              chpasswd:
                expire: false
              disable_root: false
              ssh_pwauth: true
              ssh_quiet_keygen: true
              no_ssh_fingerprints: true
              ssh:
                emit_keys_to_console: false
              apt:
                primary:
                  - arches: [default]
                    uri: http://mirrors.ustc.edu.cn/ubuntu/
              runcmd:
                - sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
                - sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
                - sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
                - sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
                - sed -i 's/^#AuthorizedKeysFile.*/AuthorizedKeysFile .ssh\/authorized_keys/g' /etc/ssh/sshd_config
                - sed -i 's/^AuthorizedKeysFile.*/AuthorizedKeysFile .ssh\/authorized_keys/g' /etc/ssh/sshd_config
                - systemctl restart sshd || systemctl restart ssh
```
```shell
# 导出的目标必须没有被其他资源使用
# NFS导出时会产生权限不足错误
virtctl vmexport download vmexportname \
  --port-forward \
  --local-port=5410 \
  --format=gzip \
  -n vm-platform \
  --pvc=vm-disk-d0-xxx \
  --output=./xxx.img.gz
```
```shell
# 压缩镜像
qemu-img convert -c -p -f raw -O qcow2 xxx.img xxx3.qcow2
```

# 需要给节点node文件执行权限并开启Root功能门
```shell
chmod 777 /dev/kvm
```

# 如果主板开启UEFI则需要使用UEFI启动
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

# 不要使用Nvidia的Gpu设备插件来直通多Gpu

## 出现的问题
- 在为vm指定多个相同型号的GPU时，会将Audio设备当作一个GPU来分配（可能因为他们在一个iommu组中）

## 解决方式
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
      mediatedDevices: []
    # ...
```
- 在创建vm时即可指定`gpus`的设备名为`nvidia.com/AD102-GEFORCE-RTX-4090`