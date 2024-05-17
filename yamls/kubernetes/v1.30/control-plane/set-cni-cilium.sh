#!/usr/bin/env bash
set -e

{{- $this := .Host }}
{{- range $idx, $host := .Hosts }}
{{- if eq $host.Hostname $this.Hostname }}
{{- if gt $idx 0 }}
exit 0
{{- end }}
{{- end }}
{{- end }}

if [ ! "$(command -v cilium)" ]; then
  CNI_DIR="{{ .Host.Workdir }}"
  CILIUM_ARCH="amd64"
  if [ "$(uname -m)" = "aarch64" ]; then
    CILIUM_ARCH="arm64";
  fi

  CILIUM_FILE=cilium-linux-${CILIUM_ARCH}.tar.gz
  CILIUM_SHA256=cilium-linux-${CILIUM_ARCH}.tar.gz.sha256sum

  # see https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#install-the-cilium-cli
  if [[ ! -e ${CNI_DIR}/${CILIUM_FILE} || ! -e ${CNI_DIR}/${CILIUM_SHA256} ]]; then
    echo "下载cilium-cli"
    CILIUM_CLI_VERSION="$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)"
    curl -fsSL -o ${CNI_DIR}/${CILIUM_FILE} https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/${CILIUM_FILE}
    curl -fsSL -o ${CNI_DIR}/${CILIUM_SHA256} https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/${CILIUM_SHA256}
  fi

  echo "安装cilium-cli"
  cd ${CNI_DIR}
  sha256sum --check ${CILIUM_SHA256}
  sudo tar xzvfC ${CILIUM_FILE} /usr/local/bin
fi

# see https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/
# see https://docs.cilium.io/en/stable/network/kubernetes/kata/
# see https://docs.cilium.io/en/stable/network/kubernetes/bandwidth-manager/
if [ $(cilium version | grep 'cilium image (running)' | awk '{print $4,$12,$13}') != "unknown. not found" ]; then
  echo "已经安装cilium,跳过安装"
  exit 0
fi

echo "安装cilium"
cilium install \
  --version 1.15.4 \
  --set ipam.mode=kubernetes \
  --set k8s.requireIPv4PodCIDR=true \
  --set kubeProxyReplacement=true \
  --set containerRuntime.integration=containerd \
  --set bandwidthManager.enabled=true


echo "滚动更新CoreDNS"
kubectl rollout restart deployment/coredns -n kube-system




