# [适用于 Linux 的 NVIDIA CUDA 安装指南](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/#meta-packages)

# CUDA工具包[下载](https://developer.nvidia.com/cuda-downloads)

### 安装前的操作，[参考文档](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/#pre-installation-actions)
#### 1.验证系统是否具有支持CUDA的GPU，[参考](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/#verify-you-have-a-cuda-capable-gpu)
- 一般来说，如果显卡来自NVIDIA并在[cuda-gpus](https://developer.nvidia.com/cuda-gpus)列表中，则GPU支持CUDA
```shell
# 更新PCI硬件数据，通常在/sbin
sudo update-pciids

# 查看是否支持CUDA
sudo lspci -vnn | grep -i nvidia

# ----------------------------------------------------------------------------------------------------------------------
# 03:00.0 VGA compatible controller: NVIDIA Corporation TU116 [GeForce GTX 1660] (rev a1)
# 03:00.1 Audio device: NVIDIA Corporation TU116 High Definition Audio Controller (rev a1)
# 03:00.2 USB controller: NVIDIA Corporation TU116 USB 3.1 Host Controller (rev a1)
# 03:00.3 Serial bus controller: NVIDIA Corporation TU116 USB Type-C UCSI Controller (rev a1)
# 04:00.0 VGA compatible controller: NVIDIA Corporation TU116 [GeForce GTX 1660] (rev a1)
# 04:00.1 Audio device: NVIDIA Corporation TU116 High Definition Audio Controller (rev a1)
# 04:00.2 USB controller: NVIDIA Corporation TU116 USB 3.1 Host Controller (rev a1)
# 04:00.3 Serial bus controller: NVIDIA Corporation TU116 USB Type-C UCSI Controller (rev a1)
```

#### 2.确认受支持的Linux版本，[参考](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/#verify-you-have-a-supported-version-of-linux)，[表](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/#id10)
- 对 Debian 11.9 的支持已弃用
```shell
sudo uname -mr && cat /etc/*release

# ----------------------------------------------------------------------------------------------------------------------
# 6.1.0-23-amd64 x86_64
# PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"
# NAME="Debian GNU/Linux"
# VERSION_ID="12"
# VERSION="12 (bookworm)"
# VERSION_CODENAME=bookworm
# ID=debian
# HOME_URL="https://www.debian.org/"
# SUPPORT_URL="https://www.debian.org/support"
# BUG_REPORT_URL="https://bugs.debian.org/"
```

#### 3.确认系统已安装gcc，[参考表](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/#host-compiler-support-policy)
- 当使用CUDA Toolkit进行开发的时候需要gcc编译器，运行CUDA应用程序时不需要编译器    
- 要验证系统上安装的gcc版本，请在命令行中输入以下命令
```shell
sudo gcc --version

# ----------------------------------------------------------------------------------------------------------------------
# gcc (Debian 12.2.0-14) 12.2.0
# Copyright (C) 2022 Free Software Foundation, Inc.
# This is free software; see the source for copying conditions.  There is NO
# warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
```

#### 4.验证系统是否安装了正确的内核头文件和开发包，[参考](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/#verify-the-system-has-the-correct-kernel-headers-and-development-packages-installed)
```shell
sudo ls /usr/src/linux-headers-$(uname -r)

# ----------------------------------------------------------------------------------------------------------------------
# arch  include  Makefile  Module.symvers  scripts  tools
```

#### 5.安装内核头文件和工具包
```shell
sudo apt update
sudo apt upgrade
sudo apt install linux-headers-$(uname -r) linux-image-$(uname -r)
```

### 查看BIOS 中启用了虚拟化和 IOMMU 扩展（Intel VT-d 或 AMD IOMMU）并加载vfio-pci内核
```shell
# DMAR是否支持IOMMU
IOMMU_DMAR="$(dmesg | grep -e DMAR | grep -e IOMMU)"
# GRUB是否配置IOMMU
IOMMU_GRUB="$(cat /etc/default/grub | grep "GRUB_CMDLINE_LINUX" | grep "_iommu=on")"
# IOMMU是否已经开启
IOMMU_ENABLED="$(dmesg | grep -e DMAR | grep -e IOMMU | grep 'DMAR: IOMMU enabled')"
# CPU型号（AMD/AMD(R)/Intel/Intel(R)）
CPU_BRAND="$(cat /proc/cpuinfo | grep 'model name' | sed -e 's/model name\t:/ /' | uniq | awk '{print $1}')"

# 已经开启IOMMU
if [ -n "${IOMMU_ENABLED}" ]; then
  echo "系统已经开启IOMMU"
  exit 0
fi

# 不支持IOMMU
if [ -z "${IOMMU_DMAR}" ]; then
  echo "请检查系统硬件是否支持虚拟化或者BIOS是否开启IOMMU（AMD）/VT-d（Intel）"
  exit 0
fi

# 没有设置GRUB
if [ -z "${IOMMU_GRUB}" ]; then
  case "${CPU_BRAND}" in
  "AMD")
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& amd_iommu=on/' /etc/default/grub
    ;;
  "AMD(R)")
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& amd_iommu=on/' /etc/default/grub
    ;;
  "Intel")
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& intel_iommu=on/' /etc/default/grub
    ;;
  "Intel(R)")
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& intel_iommu=on/' /etc/default/grub
    ;;
  *)
    echo "不支持的CPU型号"
    exit 0
    ;;
  esac
fi

# 重新构建grub.cfg
grub-mkconfig -o /boot/grub/grub.cfg

# 加载vfio-pci内核模块
modprobe vfio-pci
lsmod | grep vfio
cat > /etc/modules-load.d/vfio-pci.conf << EOF
vfio-pci
EOF

# 加载vfio-pci内核模块
modprobe vfio-pci && lsmod | grep vfio
cat > /etc/modules-load.d/vfio-pci.conf << EOF
vfio-pci
EOF

# 重启生效
reboot

# 再次执行确认是否生效
```

#### 6.安装NVIDIA CUDA工具包(网络安装，其他安装查看参考)，[参考](https://developer.nvidia.com/cuda-downloads)
- 第三方参考: https://blog.imixs.org/2024/05/19/how-to-run-docker-with-gpu-support/
- 使用开放版内核模块后，在使用helm安装时需要指定`--set driver.useOpenKernelModules=true`、`--set driver.rdma.useHostMofed=true`
```shell
# 禁用`nouveau`
modprobe --remove nouveau
sudo cat > /etc/modprobe.d/blacklist-nouveau.conf << EOF
blacklist nouveau
options nouveau modeset=0
EOF
sudo update-initramfs -u

# 启用`nouveau`
sudo rm -f /etc/modprobe.d/blacklist-nouveau.conf
sudo modprobe nouveau
sudo update-initramfs -u

# 是否禁用（无输出则已经禁用）
sudo lsmod | grep nouveau

# 卸载旧包，避免冲突
sudo apt autoremove nvidia* --purge -y
sudo apt autoremove cuda* --purge -y

# 安装deb
sudo curl -fSLO https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo rm -f cuda-keyring_1.1-1_all.deb

# !!!如果上一步无法安装，则使用此步骤手动安装，否则忽略此步骤
sudo apt install dirmngr apt-transport-https ca-certificates curl gpg -y
sudo curl -fSL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-cuda-3bf863cc.gpg
sudo echo "deb [signed-by=/usr/share/keyrings/nvidia-cuda-3bf863cc.gpg] https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/ /" | sudo tee /etc/apt/sources.list.d/nvidia-cuda-3bf863cc.list

# 添加仓库
sudo apt install software-properties-common -y
sudo add-apt-repository contrib -y

# 安装CUDA工具（可选，如果不需要使用CUDA则不需要安装）
sudo apt update
sudo apt -y install cuda-toolkit-12-6
sudo reboot

# 安装NVIDIA驱动程序（二选一,推荐nvidia-open）
# 1.安装开放内核模块版本
sudo apt install -y nvidia-open
# 2.安装旧版内核模块版本
sudo apt install -y cuda-drivers

# 开放版和旧版内核模块版本切换
# 1.从开放切换到传统
sudo apt remove --purge nvidia-kernel-open-dkms
sudo apt install --verbose-versions cuda-drivers-XXX
# 2.从旧版切换到开放版
sudo apt --purge remove nvidia-kernel-dkms
sudo apt install --verbose-versions nvidia-kernel-open-dkms
sudo apt install --verbose-versions cuda-drivers-XXX

# 需要重启机器
sudo reboot

# 验证安装
systemctl status nvidia-persistenced.service
sudo nvidia-smi

# ----------------------------------------------------------------------------------------------------------------------
# Fri Aug  2 14:22:27 2024
# +-----------------------------------------------------------------------------------------+
# | NVIDIA-SMI 560.28.03              Driver Version: 560.28.03      CUDA Version: 12.6     |
# |-----------------------------------------+------------------------+----------------------+
# | GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
# | Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
# |                                         |                        |               MIG M. |
# |=========================================+========================+======================|
# |   0  NVIDIA GeForce GTX 1660        Off |   00000000:03:00.0 Off |                  N/A |
# |  0%   32C    P0             19W /  120W |       1MiB /   6144MiB |      0%      Default |
# |                                         |                        |                  N/A |
# +-----------------------------------------+------------------------+----------------------+
# |   1  NVIDIA GeForce GTX 1660        Off |   00000000:04:00.0 Off |                  N/A |
# |  0%   30C    P0             16W /  120W |       1MiB /   6144MiB |      0%      Default |
# |                                         |                        |                  N/A |
# +-----------------------------------------+------------------------+----------------------+
# 
# +-----------------------------------------------------------------------------------------+
# | Processes:                                                                              |
# |  GPU   GI   CI        PID   Type   Process name                              GPU Memory |
# |        ID   ID                                                               Usage      |
# |=========================================================================================|
# |  No running processes found                                                             |
# +-----------------------------------------------------------------------------------------+
```

#### 7.处理安装冲突，[参考](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/#handle-conflicting-installation-methods)
```shell
# 使用以下命令卸载Toolkit运行文件安装, X是cuda主要版本，Y是次要版本，可以使用`nvidia-smi`查看
sudo /usr/local/cuda-X.Y/bin/cuda-uninstaller

# 使用以下命令卸载驱动程序运行文件安装：
sudo /usr/bin/nvidia-uninstall

# 使用以下命令卸载 Deb 安装：
sudo apt autoremove nvidia* --purge -y
sudo apt autoremove cuda* --purge -y
```

#### 8.安装NVIDIA容器工具包，[参考](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
- 可选，如果这里安装了，则helm安装时不需要开启toolkit
```shell
# 配置仓库
sudo curl -fSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
sudo curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# 可选：配置实验性包
sudo sed -i -e '/experimental/ s/^#//g' /etc/apt/sources.list.d/nvidia-container-toolkit.list

# 安装容器工具包
sudo apt update
sudo apt install -y nvidia-container-toolkit

# 配置容器环境
sudo nvidia-ctk runtime configure --runtime=containerd
sudo systemctl restart containerd
```

#### 9.运行示例工作负载
- 参考：https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/sample-workload.html

#### 10.k8s中安装gpu-operator，[文档](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/index.html)
```shell
# 给不需要安装Operands的节点打上标签
kubectl label nodes <node> nvidia.com/gpu.deploy.operands=false --overwrite

# 给不需要安装驱动的节点打上标签
kubectl label nodes <node> nvidia.com/gpu.deploy.driver=false --overwrite

# 给直通GPU节点打上标签(container/vm-passthrough/vm-vgpu)
kubectl label node <node-name> --overwrite nvidia.com/gpu.workload.config=vm-passthrough

# 安装Chart
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

#### 11.验证集群中是否可以访问GPU
```shell
kubectl.exe exec -it -n gpu-operator   daemonset/nvidia-device-plugin-daemonset -- nvidia-smi

# ----------------------------------------------------------------------------------------------------------------------
# Fri Aug  2 14:22:27 2024
# +-----------------------------------------------------------------------------------------+
# | NVIDIA-SMI 560.28.03              Driver Version: 560.28.03      CUDA Version: 12.6     |
# |-----------------------------------------+------------------------+----------------------+
# | GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
# | Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
# |                                         |                        |               MIG M. |
# |=========================================+========================+======================|
# |   0  NVIDIA GeForce GTX 1660        Off |   00000000:03:00.0 Off |                  N/A |
# |  0%   32C    P0             19W /  120W |       1MiB /   6144MiB |      0%      Default |
# |                                         |                        |                  N/A |
# +-----------------------------------------+------------------------+----------------------+
# |   1  NVIDIA GeForce GTX 1660        Off |   00000000:04:00.0 Off |                  N/A |
# |  0%   30C    P0             16W /  120W |       1MiB /   6144MiB |      0%      Default |
# |                                         |                        |                  N/A |
# +-----------------------------------------+------------------------+----------------------+
# 
# +-----------------------------------------------------------------------------------------+
# | Processes:                                                                              |
# |  GPU   GI   CI        PID   Type   Process name                              GPU Memory |
# |        ID   ID                                                               Usage      |
# |=========================================================================================|
# |  No running processes found                                                             |
# +-----------------------------------------------------------------------------------------+
```

#### 卸载gpu-operator
```shell
# 卸载Chart
helm uninstall nvidia-gpu-operator -n gpu-operator

# 确认Operator空间的Pod已被删除或正在删除
kubectl get pods -n gpu-operator

# 列出并删除NVIDIA驱动程序自定义资源
kubectl get clusterpolicies -A
kubectl get nvidiadrivers -A
kubectl delete clusterpolicies <cr>
kubectl delete nvidiadriver <cr>

# helm不会某些CRD，如`clusterpolicy`、`nvidiadrivers`，可以在helm安装时指定`--set operator.cleanupCRD=true`让helm钩子自动删除，也可以手动删除
kubectl get crd clusterpolicies.nvidia.com
kubectl get crd nvidiadrivers.nvidia.com
kubectl delete crd clusterpolicies.nvidia.com
kubectl delete crd nvidiadrivers.nvidia.com

# 删除指定节点标签
kubectl.exe label node <node> nvidia.com/gpu-driver-upgrade-state-
kubectl.exe label node <node> nvidia.com/gpu.deploy.container-toolkit-
kubectl.exe label node <node> nvidia.com/gpu.deploy.dcgm-
kubectl.exe label node <node> nvidia.com/gpu.deploy.dcgm-exporter-
kubectl.exe label node <node> nvidia.com/gpu.deploy.device-plugin-
kubectl.exe label node <node> nvidia.com/gpu.deploy.driver-
kubectl.exe label node <node> nvidia.com/gpu.deploy.gpu-feature-discovery-
kubectl.exe label node <node> nvidia.com/gpu.deploy.node-status-exporter-
kubectl.exe label node <node> nvidia.com/gpu.deploy.nvsm-
kubectl.exe label node <node> nvidia.com/gpu.deploy.operator-validator-
kubectl.exe label node <node> nvidia.com/gpu.present-

# 卸载 Operator 后，NVIDIA 驱动程序模块可能仍会加载。请重新启动节点或使用以下命令卸载它们
sudo rmmod nvidia_modeset nvidia_uvm nvidia
```

### 部署GPU应用
```shell
# 部署ollama
kubectl apply -f - <<EOF
 ---
 apiVersion: v1
 kind: PersistentVolumeClaim
 metadata:
   name: ollama
 spec:
   storageClassName: nfs-subdir-external
   accessModes:
     - ReadWriteOnce
   resources:
     requests:
       storage: 50Gi

---
apiVersion: v1
kind: Pod
metadata:
  name: ollama
  labels:
    name: ollama
spec:
  runtimeClassName: nvidia
  containers:
  - name: ollama
    image: ollama/ollama:0.3.3
    env:
    - name: NVIDIA_DRIVER_CAPABILITIES
      value: compute,utility
    - name: NVIDIA_VISIBLE_DEVICES
      value: all
    - name: HF_ENDPOINT
      value: "https://hf-mirror.com"
    resources:
      limits:
        nvidia.com/gpu: 2
    ports:
    - containerPort: 11434
      name: ollama-serve
      protocol: TCP
    volumeMounts:
    - mountPath: /root/.ollama
      name: ollama-data
  volumes:
  - name: ollama-data
    persistentVolumeClaim:
      claimName: ollama

---
apiVersion: v1
kind: Service
metadata:
  name: ollama-serve
spec:
  ports:
    - name: ollama-api
      port: 11434
      protocol: TCP
      targetPort: ollama-serve
  selector:
    name: ollama
  type: ClusterIP
EOF

# 部署open-webui
kubectl apply -f - <<EOF
 ---
 apiVersion: v1
 kind: PersistentVolumeClaim
 metadata:
   name: open-webui
 spec:
   storageClassName: nfs-subdir-external
   accessModes:
     - ReadWriteOnce
   resources:
     requests:
       storage: 10Gi

---
apiVersion: v1
kind: Pod
metadata:
  name: open-webui
  labels:
    name: open-webui
spec:
  containers:
  - name: open-webui
    image: ghcr.io/open-webui/open-webui:main
    env:
    - name: OLLAMA_BASE_URL
      value: "http://ollama-serve.default.svc.cluster.local:11434"
    - name: ENV
      value: "prod"
    - name: RAG_EMBEDDING_ENGINE
      value: "ollama"
    - name: HF_ENDPOINT
      value: "https://hf-mirror.com"
    volumeMounts:
    - mountPath: /app/backend/data
      name: open-webui-data
    ports:
    - containerPort: 8080
      name: open-webui-http
      protocol: TCP
  volumes:
  - name: open-webui-data
    persistentVolumeClaim:
      claimName: open-webui

---
apiVersion: v1
kind: Service
metadata:
  name: open-webui
  labels:
    kubernetes.io/service-export: "nginx"
    kubernetes.io/service-ssl: "38003"
spec:
  ports:
    - name: open-webui
      port: 38003
      protocol: TCP
      targetPort: open-webui-http
  selector:
    name: open-webui
  type: ClusterIP
EOF
```