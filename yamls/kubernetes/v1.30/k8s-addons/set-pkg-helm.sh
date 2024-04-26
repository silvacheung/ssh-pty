#!/usr/bin/env bash
set -e

# see https://helm.sh/zh/docs/intro/install/#%E4%BD%BF%E7%94%A8apt-debianubuntu
echo "安装helm"
rm -f /usr/share/keyrings/helm.gpg
rm -f /etc/apt/sources.list.d/helm-stable-debian.list
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
