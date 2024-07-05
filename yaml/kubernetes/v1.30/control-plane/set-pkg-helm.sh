#!/usr/bin/env bash

set -e

if [ "$(command -v helm)" ]; then
  echo "安装Helm包 >> 已安装,跳过安装"
  exit 0
fi

# see https://helm.sh/zh/docs/intro/install/#%E4%BD%BF%E7%94%A8apt-debianubuntu
echo "安装Helm包 >> 未安装,开始安装"
rm -f /usr/share/keyrings/helm.gpg
rm -f /etc/apt/sources.list.d/helm-stable-debian.list
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt update
sudo apt install helm