#!/usr/bin/env bash

set -e

K8S_VERSION="{{ get "config.k8s.version" }}"
DEB_VERSION="${K8S_VERSION%.*}"

if [ "$(systemctl is-active kubelet)" == "active" ]; then
  echo "安装k8s组件工具 >> kubelet运行中, 跳过安装kubeadm/kubelet/kubectl"
  exit 0
fi

if [ "$(command -v kubeadm)" ]; then
  echo "安装k8s组件工具 >> kubeadm reset"
  kubeadm reset -f
fi

sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo rm -f /etc/apt/sources.list.d/kubernetes.list

# 这里使用阿里云的镜像源
# see https://developer.aliyun.com/mirror
# see https://developer.aliyun.com/mirror/kubernetes
# 更新apt包索引并安装使用kubernetes apt仓库所需要的包
echo "安装k8s组件工具 >> 安装kubelet/kubeadm/kubectl"
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl gpg

# 在低于Debian 12和Ubuntu 22.04的发行版本中，/etc/apt/keyrings默认不存在
sudo mkdir -p -m 755 /etc/apt/keyrings

# 下载用于kubernetes软件包仓库的公共签名密钥
#curl -fsSL https://pkgs.k8s.io/core:/stable:/v${DEB_VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
#curl -fsSL https://mirrors.aliyun.com/kubernetes-new/core/stable/v${DEB_VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
curl -fsSL http://mirrors.ustc.edu.cn//kubernetes/core:/stable:/v${DEB_VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# 添加kubernetes apt仓库
#echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${DEB_VERSION}/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
#echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.aliyun.com/kubernetes-new/core/stable/v${DEB_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] http://mirrors.ustc.edu.cn/kubernetes/core:/stable:/v${DEB_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# 更新apt包索引，安装kubelet、kubeadm、kubectl，并锁定其版本
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
