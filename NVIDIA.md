# [适用于 Linux 的 NVIDIA CUDA 安装指南](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/#meta-packages)

### 系统要求
#### 1.支持 CUDA 的 GPU
#### 2.带有 gcc [编译器](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/#host-compiler-support-policy)和工具链的受支持的 Linux [版本](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/#id14)
#### 3.CUDA 工具包（可从https://developer.nvidia.com/cuda-downloads获取）

### 安装前的操作
#### 1.验证系统是否具有支持 CUDA 的 GPU
```shell
# 更新PCI硬件数据，通常在/sbin
update-pciids

# 查看是否支持CUDA
lspci | grep -i nvidia
```
一般来说，如果显卡来自NVIDIA并在[cuda-gpus](https://developer.nvidia.com/cuda-gpus)列表中，则GPU支持CUDA

#### 2.确认受支持的 Linux 版本
```shell
uname -m && cat /etc/*release

# x86_64
# ......
```

#### 3.确认系统已安装 gcc
当使用CUDA Toolkit进行开发的时候需要gcc编译器，运行 CUDA 应用程序时不需要编译器    
要验证系统上安装的 gcc 版本，请在命令行中输入以下命令
```shell
gcc --version

# gcc (Debian 12.2.0-14) 12.2.0
# ......
```

#### 4.验证系统是否安装了正确的内核头文件和开发包
获取系统正在运行的内核版本
```shell
uname -r
```

安装内核头文件和工具包
```shell
apt update
apt install linux-headers-$(uname -r) linux-image-$(uname -r)
```

#### 5.下载 NVIDIA CUDA 工具包
```text
https://developer.nvidia.com/cuda-downloads
```

#### 6.提前卸载预防冲突
```shell
# 使用以下命令卸载 Toolkit 运行文件安装
/usr/local/cuda-X.Y/bin/cuda-uninstaller

# 使用以下命令卸载驱动程序运行文件安装：
/usr/bin/nvidia-uninstall

# 使用以下命令卸载 Deb 安装：
apt autoremove <package_name> --purge
```

#### 7.包管理器安装(debian)
```shell
# 使用以下命令安装当前运行的内核的内核头文件和开发包
apt install linux-headers-$(uname -r)

# see https://docs.nvidia.com/cuda/cuda-installation-guide-linux/#debian
# see https://blog.imixs.org/2024/05/19/how-to-run-docker-with-gpu-support/
apt update
apt upgrade
apt autoremove nvidia* --purge
apt install software-properties-common -y
add-apt-repository contrib non-free-firmware
apt install dirmngr ca-certificates apt-transport-https dkms curl -y
curl -fSsL https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-drivers.gpg > /dev/null 2>&1

# 安装nvidia-detect,这将为您提供有关硬件状态以及如何安装驱动程序的提示
apt update
apt install linux-headers-amd64 nvidia-detect
nvidia-detect

# 安装上一步的推荐包，另外也安装了一些额外包
apt install nvidia-driver nvidia-smi linux-image-amd64 cuda

# 验证安装
# 要验证您的安装运行nvidia-smi，它会向您显示一些硬件信息
nvidia-smi

```

#### 8.安装 NVIDIA 容器工具包
```shell
# see https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# 安装容器工具包
apt update
apt install -y nvidia-container-toolkit

# 配置容器环境
nvidia-ctk runtime configure --runtime=containerd
systemctl restart containerd
```

#### 9.运行示例工作负载
```text
https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/sample-workload.html
```