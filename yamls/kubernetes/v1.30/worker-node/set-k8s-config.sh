#!/usr/bin/env bash
set -e

#HA_ADDR="$(echo "{{ .Configs.K8s.ControlPlaneEndpoint }}" | awk '{split($1, arr, ":"); print arr[1]}')"
#HA_PORT="$(echo "{{ .Configs.K8s.ControlPlaneEndpoint }}" | awk '{split($1, arr, ":"); print arr[2]}')"
CONTROL_PLANE_ENDPOINT_DOMAIN="{{ .Configs.K8s.ControlPlaneEndpoint.Domain }}"
CONTROL_PLANE_ENDPOINT_ADDRESS="{{ .Configs.K8s.ControlPlaneEndpoint.Address }}"
CONTROL_PLANE_ENDPOINT_PORT="{{ .Configs.K8s.ControlPlaneEndpoint.Port }}"
CONTROL_PLANE_ENDPOINT=""

if [ "${CONTROL_PLANE_ENDPOINT_PORT}" == "" ]; then
  CONTROL_PLANE_ENDPOINT_PORT="6443"
fi

if [ "${CONTROL_PLANE_ENDPOINT_DOMAIN}" != "" ]; then
  CONTROL_PLANE_ENDPOINT="${CONTROL_PLANE_ENDPOINT_DOMAIN}:${CONTROL_PLANE_ENDPOINT_PORT}"
elif [ "${CONTROL_PLANE_ENDPOINT_ADDRESS}" != "" ]; then
  CONTROL_PLANE_ENDPOINT="${CONTROL_PLANE_ENDPOINT_ADDRESS}:${CONTROL_PLANE_ENDPOINT_PORT}"
fi

cat >/etc/kubernetes/kubeadm-config.yaml<<EOF
---
# see https://kubernetes.io/zh-cn/docs/reference/config-api/kubeadm-config.v1beta4/
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration

nodeRegistration:
  name: "{{ .Host.Hostname }}"
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
    node-ip: "{{ .Host.Internal }}"
    hostname-override: "{{ .Host.Hostname }}"
    node-labels: ""

discovery:
  tlsBootstrapToken: "{{ .Configs.K8s.BootstrapToken }}"
  bootstrapToken:
    unsafeSkipCAVerification: true
    token: "{{ .Configs.K8s.BootstrapToken }}"
    apiServerEndpoint: "${CONTROL_PLANE_ENDPOINT}"

#skipPhases:
#- "addon/kube-proxy"
EOF
