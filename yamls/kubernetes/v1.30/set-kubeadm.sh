#!/usr/bin/env bash

# 这里使用阿里云的镜像源
# see https://developer.aliyun.com/mirror
# see https://developer.aliyun.com/mirror/kubernetes

if [ -e /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]; then
  rm /etc/apt/keyrings/kubernetes-apt-keyring.gpg
fi

if [ -e /etc/apt/sources.list.d/kubernetes.list ]; then
  rm /etc/apt/sources.list.d/kubernetes.list
fi

# 更新 apt 包索引并安装使用 Kubernetes apt 仓库所需要的包
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl gpg

# 在低于 Debian 12 和 Ubuntu 22.04 的发行版本中，/etc/apt/keyrings 默认不存在
sudo mkdir -p -m 755 /etc/apt/keyrings

# 下载用于 Kubernetes 软件包仓库的公共签名密钥
curl -fsSL https://mirrors.aliyun.com/kubernetes-new/core/stable/v{{ .Configs.K8s.Version }}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
#curl -fsSL https://pkgs.k8s.io/core:/stable:/v{{ .Configs.K8s.Version }}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# 添加 Kubernetes apt 仓库
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.aliyun.com/kubernetes-new/core/stable/v{{ .Configs.K8s.Version }}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
#echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v{{ .Configs.K8s.Version }}/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# 更新 apt 包索引，安装 kubelet、kubeadm 和 kubectl，并锁定其版本
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
