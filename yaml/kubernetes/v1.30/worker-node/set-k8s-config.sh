#!/usr/bin/env bash

set -e

CONTROL_PLANE_ENDPOINT_DOMAIN="{{ get "config.k8s.control_plane_endpoint.domain" }}"
CONTROL_PLANE_ENDPOINT_ADDRESS="{{ get "config.k8s.control_plane_endpoint.address" }}"
CONTROL_PLANE_ENDPOINT_PORT="{{ get "config.k8s.control_plane_endpoint.port" }}"
CONTROL_PLANE_ENDPOINT=""

if [ "${CONTROL_PLANE_ENDPOINT_PORT}" == "" ]; then
  CONTROL_PLANE_ENDPOINT_PORT="6443"
fi

if [ "${CONTROL_PLANE_ENDPOINT_DOMAIN}" != "" ]; then
  CONTROL_PLANE_ENDPOINT="${CONTROL_PLANE_ENDPOINT_DOMAIN}:${CONTROL_PLANE_ENDPOINT_PORT}"
elif [ "${CONTROL_PLANE_ENDPOINT_ADDRESS}" != "" ]; then
  CONTROL_PLANE_ENDPOINT="${CONTROL_PLANE_ENDPOINT_ADDRESS}:${CONTROL_PLANE_ENDPOINT_PORT}"
fi

echo "写入配置文件 >> /etc/kubernetes/kubeadm-config.yaml"
cat >/etc/kubernetes/kubeadm-config.yaml<<EOF
---
# see https://kubernetes.io/zh-cn/docs/reference/config-api/kubeadm-config.v1beta4/
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration

nodeRegistration:
  name: "{{ get "host.hostname" }}"
  criSocket: "unix:///var/run/containerd/containerd.sock"
  imagePullPolicy: "IfNotPresent"
  ignorePreflightErrors:
  - "IsPrivilegedUser"
  - "FileExisting-crictl"
  - "ImagePull"
  taints:
  - key: ""
    value: ""
    effect: ""
  kubeletExtraArgs:
    node-ip: "{{ get "host.internal" }}"
    hostname-override: "{{ get "host.hostname" }}"
    node-labels: ""

discovery:
  tlsBootstrapToken: "{{ get "config.k8s.bootstrap_token" }}"
  bootstrapToken:
    unsafeSkipCAVerification: true
    token: "{{ get "config.k8s.bootstrap_token" }}"
    apiServerEndpoint: "${CONTROL_PLANE_ENDPOINT}"

#skipPhases:
#- "addon/kube-proxy"

#---
# see https://kubernetes.io/zh-cn/docs/reference/config-api/kubeadm-config.v1beta4/
#apiVersion: kubeadm.k8s.io/v1beta4
#kind: ResetConfiguration
#
#dryRun: false
#force: false
#
#cleanupTmpDir: true
#certificatesDir: "/etc/kubernetes/pki"
#criSocket: "unix:///var/run/containerd/containerd.sock"
#
#ignorePreflightErrors:
#- "IsPrivilegedUser"
#- "FileExisting-crictl"
#- "ImagePull"
#
#skipPhases:
#- "addon/kube-proxy"

EOF
