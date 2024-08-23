#!/usr/bin/env bash

set -e

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
modprobe vfio-pci && lsmod | grep vfio
cat > /etc/modules-load.d/vfio-pci.conf << EOF
vfio-pci
EOF

# 重启生效
reboot