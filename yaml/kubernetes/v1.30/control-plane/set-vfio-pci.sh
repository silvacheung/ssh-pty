#!/usr/bin/env bash

set -e

# DMAR是否支持IOMMU
IOMMU_DMAR="$(dmesg | grep -e DMAR | grep -e IOMMU || true)"
# GRUB是否配置IOMMU
IOMMU_GRUB="$(cat /etc/default/grub | grep "GRUB_CMDLINE_LINUX" | grep "_iommu=on" || true)"
# IOMMU是否已经开启
IOMMU_ENABLED="$(dmesg | grep -e DMAR | grep -e IOMMU | grep 'DMAR: IOMMU enabled' || true)"
# CPU型号（AMD/AMD(R)/Intel/Intel(R)）
CPU_BRAND="$(cat /proc/cpuinfo | grep 'model name' | sed -e 's/model name\t:/ /' | uniq | awk '{print $1}' || true)"

# 已经开启IOMMU
if [ -n "${IOMMU_ENABLED}" ]; then
  echo "系统已经开启IOMMU"
else
  if [ -z "${IOMMU_DMAR}" ]; then
    echo "请检查系统硬件是否支持虚拟化或者BIOS是否开启IOMMU（AMD）/VT-d（Intel）"
    exit 0
  fi

  # 没有设置GRUB
  if [ -z "${IOMMU_GRUB}" ]; then
    case "${CPU_BRAND}" in
    "AMD")
      sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& amd_iommu=on video=efifb:off,vesafb:off/' /etc/default/grub
      ;;
    "AMD(R)")
      sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& amd_iommu=on video=efifb:off,vesafb:off/' /etc/default/grub
      ;;
    "Intel")
      sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& intel_iommu=on video=efifb:off,vesafb:off/' /etc/default/grub
      ;;
    "Intel(R)")
      sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& intel_iommu=on video=efifb:off,vesafb:off/' /etc/default/grub
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

# 绑定到vfio-pci
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
options vfio-pci ids=$(echo $VFIO_PCI_IDS | sed 's/^,//i')
EOF

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

cat > /etc/modprobe.d/kvm.conf << EOF
options kvm ignore_msrs=1
EOF

sudo apt install initramfs-tools -y
sudo update-initramfs -u

# 重启生效
reboot
