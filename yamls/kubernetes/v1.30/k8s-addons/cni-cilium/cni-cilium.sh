#!/usr/bin/env bash
set -e

CILIUM_ARCH="amd64"
if [ "$(uname -m)" = "aarch64" ]; then
  CILIUM_ARCH="arm64";
fi


# see https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#install-the-cilium-cli
if [[ -e cilium-linux-${CILIUM_ARCH}.tar.gz || -e cilium-linux-${CILIUM_ARCH}.tar.gz.sha256sum ]]; then
  echo "下载cilium-cli"
  CILIUM_CLI_VERSION="$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)"
  curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CILIUM_ARCH}.tar.gz{,.sha256sum}
fi


echo "安装cilium-cli"
sha256sum --check cilium-linux-${CILIUM_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CILIUM_ARCH}.tar.gz /usr/local/bin
#rm cilium-linux-${CILIUM_ARCH}.tar.gz{,.sha256sum}


# 下载hubble
# see https://docs.cilium.io/en/stable/gettingstarted/hubble_setup/
if [[ -e hubble-linux-${CILIUM_ARCH}.tar.gz || -e hubble-linux-${CILIUM_ARCH}.tar.gz.sha256sum ]]; then
  echo "# 下载hubble"
  HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
  curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-linux-${CILIUM_ARCH}.tar.gz{,.sha256sum}
fi


echo "安装hubble"
sha256sum --check hubble-linux-${CILIUM_ARCH}.tar.gz.sha256sum
sudo tar xzvfC hubble-linux-${CILIUM_ARCH}.tar.gz /usr/local/bin
#rm hubble-linux-${CILIUM_ARCH}.tar.gz{,.sha256sum}


# see https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/
# see https://docs.cilium.io/en/stable/network/kubernetes/kata/
# see https://docs.cilium.io/en/stable/network/kubernetes/bandwidth-manager/
echo "安装cilium"
cilium install \
  --version 1.15.4 \
  --set containerRuntime.integration=containerd \
  --set bandwidthManager.enabled=true \
  --set hubble.tls.auto.enabled=true \
  --set hubble.tls.auto.method=cronJob \
  --set hubble.tls.auto.certValidityDuration=1095 \
  --set hubble.tls.auto.schedule="0 0 1 */4 *"


cilium status --wait


# see https://docs.cilium.io/en/stable/network/kubernetes/concepts/#networking-for-existing-pods
echo "更新coredns"
kubectl rollout restart deployment/coredns -n kube-system
kubectl get pods -A -w


# 开启cilium hubble和hubble ui
# see https://docs.cilium.io/en/stable/gettingstarted/hubble/
echo "开启hubble"
cilium hubble enable --ui



