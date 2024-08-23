#!/usr/bin/env bash

set -e

# 确认系统虚拟化/开启IOMMU/加载vfio-pci内核模块
# ----------------------------------------------------------------------------------------------------------------------
IOMMU_DMAR="$(dmesg | grep -e DMAR | grep -e IOMMU)"
IOMMU_GRUB="$(cat /etc/default/grub | grep "GRUB_CMDLINE_LINUX" | grep "_iommu=on")"
IOMMU_ENABLED="$(dmesg | grep -e DMAR | grep -e IOMMU | grep 'DMAR: IOMMU enabled')"
CPU_BRAND="$(cat /proc/cpuinfo | grep 'model name' | sed -e 's/model name\t:/ /' | uniq | awk '{print $1}')"

if [ -n "${IOMMU_ENABLED}" ]; then
  echo "系统已经开启IOMMU"
  exit 0
fi

if [ -z "${IOMMU_DMAR}" ]; then
  echo "请检查系统硬件是否支持虚拟化或者BIOS是否开启IOMMU（AMD）/VT-d（Intel）"
  exit 0
fi

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
modprobe vfio-pci && lsmod | grep vfio
cat > /etc/modules-load.d/vfio-pci.conf << EOF
vfio-pci
EOF

# nvidia驱动安装
# ----------------------------------------------------------------------------------------------------------------------
# 卸载重启（卸载后必须重启后再重新安装）
#sudo apt autoremove nvidia* --purge -y || true
#sudo apt autoremove cuda* --purge -y || true
#sudo reboot

# 条件检查
sudo apt update
sudo update-pciids
sudo lspci | grep -i nvidia
sudo uname -mr && cat /etc/*release
sudo gcc --version

# 禁用`nouveau`
sudo cat > /etc/modprobe.d/blacklist-nouveau.conf << EOF
blacklist nouveau
options nouveau modeset=0
EOF
modprobe --remove nouveau
sudo update-initramfs -u
sudo lsmod | grep nouveau || true

# 安装内核头文件
sudo apt install linux-headers-$(uname -r)
sudo ls /usr/src/linux-headers-$(uname -r)

# 添加仓库
sudo curl -fSLO https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo rm -f cuda-keyring_1.1-1_all.deb
sudo apt install software-properties-common -y
sudo add-apt-repository contrib -y

# 安装驱动
sudo apt update
sudo apt -y install nvidia-open

# 重启生效
sudo reboot