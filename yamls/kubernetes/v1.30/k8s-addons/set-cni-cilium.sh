#!/usr/bin/env bash
set -e

# see https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#install-the-cilium-cli
echo "安装cilium-cli"
CILIUM_CLI_VERSION="$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)"
CLI_ARCH="amd64"
if [ "$(uname -m)" = "aarch64" ]; then
  CLI_ARCH="arm64";
fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
#rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

# see https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/
# see https://docs.cilium.io/en/stable/network/kubernetes/kata/
# see https://docs.cilium.io/en/stable/network/kubernetes/bandwidth-manager/
echo "安装cilium"
cilium install \
  --version 1.15.4 \
  --set containerRuntime.integration=containerd \
  --set bandwidthManager.enabled=true

cilium status --wait


# see https://docs.cilium.io/en/stable/network/kubernetes/concepts/#networking-for-existing-pods
echo "更新coredns"
kubectl rollout restart deployment/coredns -n kube-system
kubectl get pods -A -w

# 开启cilium hubble
echo "开启hubble"
cilium hubble enable --ui


# 下载hubble
HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
sha256sum --check hubble-linux-${HUBBLE_ARCH}.tar.gz.sha256sum
sudo tar xzvfC hubble-linux-${HUBBLE_ARCH}.tar.gz /usr/local/bin
#rm hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}

