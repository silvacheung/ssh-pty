#!/usr/bin/env bash
# https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF

# ---BIOS/UEFI 设置---
# 对于英特尔，启用 VT-x / VT-d
# 对于 AMD，启用 AMD-v / AMD-Vi
# 如果存在，设置开启 ACS Enable
# 启用 4G解码 4G Decoding

# ---GRUB参数(https://imacos.top/2023/07/31/pci/)---
# quiet	默认参数，表示在启动过程中只显示重要信息
# intel_iommu=on	用 intel_iommu 驱动来驱动 IOMMU 硬件单元
# amd_iommu=on	用 amd_iommu 驱动来驱动 IOMMU 硬件单元
# iommu=pt	只为使用透传功能的设备启用 IOMMU，并可以提供更好的功能和性能
# pci=assign-busses	部分网卡开启 SR-IOV 需要这个参数，否则可能报错
# PCIe_acs_override=downstream	用于将 iommu groups 拆分，方便灵活按需直通一些板载的设备
# PCIe_acs_override=multifunction	PCIe 直通多功能支持，提高直通完美度（可选）
# nofb	该选项允许你不用一个frame缓冲来使用图形安装程序
# textonly	仅在文本模式下支持 GRUB 串行控制台
# nomodeset	系统启动过程中，暂时不运行图像驱动程序
# video=vesafb:off	禁用 vesa 启动显示设备
# video=efifb:off	禁用 efi 启动显示设备
# video=simplefb:off	5.15 内核开始直通可能需要这个参数
# initcall_blacklist=sysfb_init	部分 A 卡如 RX580 直通异常可能需要这个参数
# pcie_aspm=off	关闭 PCIe 设备的 ASPM 节能模式，解决部分 PCIe 设备 AER 报错
# pcie_aspm=force	强制 PCIe 设备及爱情 ASPM 节能模式，解决部分 PCIe 设备 AER 报错
# pci=noaer	不输出 AER 报错日志，华南主板经常会 AER 报错，建议配合使用，眼不见心不烦
# pci=nomsi	在系统范围内禁用 MSI 中断，主要还是解决 PCIe 相关的报错

set -e

export DEBIAN_FRONTEND=noninteractive

# DMAR是否支持IOMMU
IOMMU_DMAR="$(dmesg | grep -e DMAR | grep -e IOMMU || true)"
# GRUB是否配置IOMMU
IOMMU_GRUB="$(cat /etc/default/grub | grep "GRUB_CMDLINE_LINUX" | grep "_iommu=on" || true)"
# IOMMU是否已经开启
IOMMU_ENABLED="$(dmesg | grep -e DMAR | grep -e IOMMU | grep 'DMAR: IOMMU enabled' || true)"
# CPU型号（AMD/AMD(R)/Intel/Intel(R)）
CPU_BRAND="$(cat /proc/cpuinfo | grep 'model name' | sed -e 's/model name\t:/ /' | uniq | awk '{print $1}' || true)"
# 支持的巨页大小
HUGEPAGE_2M="$(cat /proc/meminfo | grep 'Hugepagesize:' | grep '2048 kB' | awk '{print$2}' || true)"
# 是否已开启巨页
HUGEPAGE_GRUB="$(cat /etc/default/grub | grep "GRUB_CMDLINE_LINUX" | grep "hugepagesz=2M hugepages=" || true)"

# 配置受支持2M巨页
if [[ "${HUGEPAGE_2M}" -eq "2048" && -z "${HUGEPAGE_GRUB}" ]]; then
  MEMORY="$(free -m | grep 'Mem:' | awk '{print$2}' || true)"
  let HUGEPAGE_2M_SIZE=($MEMORY / 10 * 9 / 2)
  sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& hugepagesz=2M hugepages='$HUGEPAGE_2M_SIZE'/' /etc/default/grub
fi

# 没有开启IOMMU
if [ -z "${IOMMU_ENABLED}" ]; then
  echo "系统没有开启IOMMU，开始配置GRUB"
  if [ -z "${IOMMU_DMAR}" ]; then
      echo "请检查系统硬件是否支持虚拟化或者BIOS是否开启IOMMU（AMD）/VT-d（Intel）"
      exit 0
  fi

  # 没有设置GRUB
  if [ -z "${IOMMU_GRUB}" ]; then
    case "${CPU_BRAND}" in
    "AMD")
      sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& amd_iommu=on iommu=pt video=efifb:off,vesafb:off,simplefb:off pcie_acs_override=downstream,multifunction/' /etc/default/grub
      ;;
    "AMD(R)")
      sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& amd_iommu=on iommu=pt video=efifb:off,vesafb:off,simplefb:off pcie_acs_override=downstream,multifunction/' /etc/default/grub
      ;;
    "Intel")
      sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& intel_iommu=on iommu=pt video=efifb:off,vesafb:off,simplefb:off pcie_acs_override=downstream,multifunction/' /etc/default/grub
      ;;
    "Intel(R)")
      sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& intel_iommu=on iommu=pt video=efifb:off,vesafb:off,simplefb:off pcie_acs_override=downstream,multifunction/' /etc/default/grub
      ;;
    *)
      echo "不支持的CPU型号"
      exit 0
      ;;
    esac
  fi
fi

# 重新构建grub.cfg
grub-mkconfig -o /boot/grub/grub.cfg

# 禁用模块
modprobe -r xhci_pci
modprobe -r xhci_hcd
modprobe -r snd_hda_intel
modprobe -r nouveau
sudo cat > /etc/modprobe.d/blacklist-drivers.conf << EOF
blacklist xhci_pci
blacklist xhci_hcd
blacklist snd_hda_intel
blacklist nouveau
options nouveau modeset=0
EOF

# 加载模块
modprobe vfio
modprobe vfio_pci
modprobe vfio_virqfd
modprobe vfio_iommu_type1
cat > /etc/modules-load.d/vfio.conf << EOF
vfio
vfio-pci
vfio_virqfd
vfio_iommu_type1
EOF

# 配置vfio-pci驱动直通
if [ -n "${IOMMU_ENABLED}" ]; then
  echo "系统已经开启IOMMU，开始配置vfio-pci驱动直通"
  declare -A VIDIDS
  for VGA in $(lspci -DD | grep NVIDIA | grep VGA | awk '{print $1}'); do
      for DEVICE in $(ls /sys/bus/pci/devices/$VGA/iommu_group/devices); do
          VENDOR_ID="$(cat /sys/bus/pci/devices/$DEVICE/vendor | sed 's/^0x//i')"
          DEVICE_ID="$(cat /sys/bus/pci/devices/$DEVICE/device | sed 's/^0x//i')"
          VIDIDS["$VENDOR_ID:$DEVICE_ID"]="$VENDOR_ID:$DEVICE_ID"
          echo "$VGA >> $DEVICE >> [$VENDOR_ID:$DEVICE_ID]"
          if [ -e /sys/bus/pci/devices/$DEVICE/driver/unbind ]; then
              echo -n "$DEVICE" > /sys/bus/pci/devices/$DEVICE/driver/unbind
          fi
          if [ -e /sys/bus/pci/devices/$DEVICE/driver_override ]; then
              echo -n "vfio-pci" > /sys/bus/pci/devices/$DEVICE/driver_override
          fi
      done
  done

  VFIO_PCI_IDS=""
  for KEY in "${!VIDIDS[@]}"; do
      VFIO_PCI_IDS="$VFIO_PCI_IDS,$KEY"
  done

  cat > /etc/modprobe.d/vfio.conf << EOF
options vfio-pci ids=$(echo $VFIO_PCI_IDS | sed 's/^,//i') disable_vga=1
EOF
fi

# 更新初始化内存文件系统
sudo apt install initramfs-tools -y
sudo update-initramfs -u

# 重启生效
reboot