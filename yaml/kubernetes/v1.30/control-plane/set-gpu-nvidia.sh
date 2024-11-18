#!/usr/bin/env bash

set -e

export DEBIAN_FRONTEND=noninteractive

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
modprobe --remove nouveau
sudo cat > /etc/modprobe.d/blacklist-nouveau.conf << EOF
blacklist nouveau
options nouveau modeset=0
EOF
sudo update-initramfs -u
sudo lsmod | grep nouveau || true

# 安装内核头文件
if [ ! -e /usr/src/linux-headers-$(uname -r) ]; then
  sudo apt install -y linux-headers-$(uname -r)
fi

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