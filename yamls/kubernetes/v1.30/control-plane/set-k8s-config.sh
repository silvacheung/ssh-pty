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
# see https://kubernetes.io/zh-cn/docs/reference/command-line-tools-reference/kube-apiserver/
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration

kubernetesVersion: "{{ .Configs.K8s.Version }}"
clusterName: "{{ .Configs.K8s.ClusterName }}"
imageRepository: "{{ .Configs.K8s.ImageRepository }}"
controlPlaneEndpoint: "${CONTROL_PLANE_ENDPOINT}"
certificatesDir: "/etc/kubernetes/pki"

etcd:
  local:
    dataDir: "/var/lib/etcd"

networking:
  dnsDomain: "cluster.local"
  serviceSubnet: "{{ .Configs.K8s.ServiceSubnet }}"
  podSubnet: "{{ .Configs.K8s.PodSubnet }}"

apiServer:
  extraArgs:
    bind-address: "0.0.0.0"
    authorization-mode: "Node,RBAC"
    enable-admission-plugins: "AlwaysPullImages,ServiceAccount,NamespaceLifecycle,NodeRestriction,LimitRanger,ResourceQuota,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,PodNodeSelector,PodSecurity"
    profiling: "false"
    #allow-privileged: "true"
    request-timeout: "1m0s"
    service-account-lookup: "true"
    audit-log-format: "json"
    audit-log-maxbackup: "2"
    audit-log-maxsize: "200"
    audit-log-path: "/var/log/kubernetes/audit/audit.log"
    audit-policy-file: "/etc/kubernetes/audit/audit-policy.yaml"
    #audit-webhook-config-file: "/etc/kubernetes/audit/audit-webhook.yaml"
    runtime-config: "api/all=true"
    feature-gates: "RotateKubeletServerCertificate=true"
  extraVolumes:
  - name: "host-time"
    hostPath: "/etc/localtime"
    mountPath: "/etc/localtime"
    readOnly: true
    pathType: File
  - name: k8s-audit-policy
    hostPath: /etc/kubernetes/audit
    mountPath: /etc/kubernetes/audit
    pathType: DirectoryOrCreate
    readOnly: false
  - name: k8s-audit-log
    hostPath: /var/log/kubernetes/audit
    mountPath: /var/log/kubernetes/audit
    pathType: DirectoryOrCreate
    readOnly: false

controllerManager:
  extraArgs:
    bind-address: "0.0.0.0"
    cluster-signing-duration: "87600h"
    profiling: "false"
    terminated-pod-gc-threshold: "100"
    use-service-account-credentials: "true"
    node-cidr-mask-size: "{{ .Configs.K8s.NodeCidrMaskSize }}"
    feature-gates: "RotateKubeletServerCertificate=true"
  extraVolumes:
  - name: "host-time"
    hostPath: "/etc/localtime"
    mountPath: "/etc/localtime"
    readOnly: true
    pathType: File

scheduler:
  extraArgs:
    bind-address: "0.0.0.0"
    profiling:    "false"
    feature-gates: "RotateKubeletServerCertificate=true"
  extraVolumes:
  - name: "host-time"
    hostPath: "/etc/localtime"
    mountPath: "/etc/localtime"
    readOnly: true
    pathType: File

---
# see https://kubernetes.io/zh-cn/docs/reference/config-api/kubeadm-config.v1beta4/
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration

certificateKey: "{{ .Configs.K8s.CertificateKey }}"
bootstrapTokens:
- token: "{{ .Configs.K8s.BootstrapToken }}"
  description: "kubeadm bootstrap token"
  ttl: "24h"
#- token: ""
#  description: "another bootstrap token"
#  usages:
#  - authentication
#  - signing
#  groups:
#  - system:bootstrappers:kubeadm:default-node-token

localAPIEndpoint:
  advertiseAddress: "0.0.0.0"
  bindPort: 6443

nodeRegistration:
  name: "{{ .Host.Hostname }}"
  criSocket: "unix:///var/run/containerd/containerd.sock"
  imagePullPolicy: "IfNotPresent"
  ignorePreflightErrors:
  - "IsPrivilegedUser"
  - "FileExisting-crictl"
  - "ImagePull"
  taints:
  - key: "node-role.kubernetes.io/control-plane"
    value: ""
    effect: "NoSchedule"
  kubeletExtraArgs:
    node-ip: "{{ .Host.Internal }}"
    hostname-override: "{{ .Host.Hostname }}"

#skipPhases:
#- "addon/kube-proxy"

---
# see https://kubernetes.io/zh-cn/docs/reference/config-api/kube-proxy-config.v1alpha1/
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration

bindAddress: "0.0.0.0"
healthzBindAddress: "0.0.0.0:10256"
metricsBindAddress: "0.0.0.0:10249"
enableProfiling: false
clusterCIDR: "{{ .Configs.K8s.PodSubnet }}"
hostnameOverride: "{{ .Host.Hostname }}"
mode: "ipvs"
portRange: "0-0"

iptables:
  masqueradeBit: 14
  syncPeriod: "30s"
  minSyncPeriod: "0s"
  masqueradeAll: false
  localhostNodePorts: true

ipvs:
  scheduler: ""
  syncPeriod: "30s"
  minSyncPeriod: "0s"
  strictARP: true
  tcpTimeout: "0"
  tcpFinTimeout: "0"
  udpTimeout: "0"
  excludeCIDRs:
  {{- range .Configs.K8s.IPVSExcludeCIDRs }}
  - "{{ . }}"
  {{- end }}

#nodePortAddresses:
#- "127.0.0.0/8"

---
# see https://kubernetes.io/zh-cn/docs/reference/config-api/kubelet-config.v1beta1/
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration

address: "0.0.0.0"
port: 10250
healthzBindAddress: "127.0.0.1"
healthzPort: 10248
readOnlyPort: 0
rotateCertificates: true
clusterDomain: "cluster.local"
cgroupsPerQOS: true
cgroupDriver: "systemd"
hairpinMode: "promiscuous-bridge"
maxPods: 110
podPidsLimit: -1
containerLogMaxSize: "5Mi"
containerLogMaxFiles: 3
staticPodPath: "/etc/kubernetes/manifests"
containerRuntimeEndpoint: "unix:///var/run/containerd/containerd.sock"
eventRecordQPS: 50
streamingConnectionIdleTimeout: "5m"
evictionPressureTransitionPeriod: "30s"
evictionMaxPodGracePeriod: 120
#failSwapOn: true

systemReserved:
  cpu: "200m"
  memory: "250Mi"

kubeReserved:
  cpu: "200m"
  memory: "250Mi"

evictionHard:
  memory.available: "5%"
  pid.available:    "10%"

evictionSoft:
  memory.available: "10%"

evictionSoftGracePeriod:
  memory.available: "2m"

# clusterDNS:
# - "8.8.8.8"
# - "114.114.114.114"

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
  - key: "node-role.kubernetes.io/control-plane"
    value: ""
    effect: "NoSchedule"
  kubeletExtraArgs:
    node-ip: "{{ .Host.Internal }}"
    hostname-override: "{{ .Host.Hostname }}"

controlPlane:
  certificateKey: "{{ .Configs.K8s.CertificateKey }}"
  localAPIEndpoint:
    advertiseAddress: "0.0.0.0"
    bindPort: 6443

discovery:
  tlsBootstrapToken: "{{ .Configs.K8s.BootstrapToken }}"
  bootstrapToken:
    unsafeSkipCAVerification: true
    token: "{{ .Configs.K8s.BootstrapToken }}"
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