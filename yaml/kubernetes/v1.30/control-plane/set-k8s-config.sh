#!/usr/bin/env bash

set -e

#HA_ADDR="$(echo "{{ get "config.k8s.control_plane_endpoint" }}" | awk '{split($1, arr, ":"); print arr[1]}')"
#HA_PORT="$(echo "{{ get "config.k8s.control_plane_endpoint" }}" | awk '{split($1, arr, ":"); print arr[2]}')"
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

cat >/etc/kubernetes/kubeadm-config.yaml<<EOF
---
# see https://kubernetes.io/zh-cn/docs/reference/config-api/kubeadm-config.v1beta4/
# see https://kubernetes.io/zh-cn/docs/reference/command-line-tools-reference/kube-apiserver/
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration

kubernetesVersion: "{{ get "config.k8s.version" }}"
clusterName: "{{ get "config.k8s.cluster_name" }}"
imageRepository: "{{ get "config.k8s.image_repository" }}"
controlPlaneEndpoint: "${CONTROL_PLANE_ENDPOINT}"
certificatesDir: "/etc/kubernetes/pki"

etcd:
  local:
    dataDir: "/var/lib/etcd"
    extraArgs:
      max-request-bytes: "$((10*1024*1024))"
      quota-backend-bytes: "$((8*1024*1024*1024))"
      auto-compaction-retention: "1000"
      auto-compaction-mode: "revision"
      snapshot-count: "50000"
      election-timeout: "3000"
      heartbeat-interval: "600"

networking:
  dnsDomain: "cluster.local"
  serviceSubnet: "{{ get "config.k8s.service_subnet" }}"
  podSubnet: "{{ get "config.k8s.pod_subnet" }}"

apiServer:
  timeoutForControlPlane: "10m0s"
  certSANs:
  - "{{ get "config.k8s.control_plane_endpoint.address" }}"
  {{- range get "config.k8s.control_plane_endpoint.sans" }}
  {{- if eq (get "config.k8s.control_plane_endpoint.address") . }}{{- else }}
  - "{{ . }}"
  {{- end }}
  {{- end }}
  extraArgs:
    bind-address: "0.0.0.0"
    authorization-mode: "Node,RBAC"
    enable-admission-plugins: "AlwaysPullImages,ServiceAccount,NamespaceLifecycle,NodeRestriction,LimitRanger,ResourceQuota,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,PodNodeSelector,PodSecurity"
    profiling: "false"
    allow-privileged: "true"
    request-timeout: "1m0s"
    service-node-port-range: {{ get "config.k8s.service_node_port_range" }}
    service-account-lookup: "true"
    enable-aggregator-routing: "true"
    max-requests-inflight: "3000"
    max-mutating-requests-inflight: "1000"
    watch-cache-sizes: "nodes#1000,services#1000,pods#5000"
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
    allocate-node-cidrs: "true"
    use-service-account-credentials: "true"
    kube-api-qps: "100"
    kube-api-burst: "150"
    node-cidr-mask-size: "{{ get "config.k8s.node_cidr_mask_size" }}"
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
    profiling: "false"
    kube-api-qps: "100"
    kube-api-burst: "150"
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

certificateKey: "{{ get "config.k8s.certificate_key" }}"
bootstrapTokens:
- token: "{{ get "config.k8s.bootstrap_token" }}"
  description: "kubeadm bootstrap token"
  ttl: "24h"
  usages:
  - authentication
  - signing
  groups:
  - system:bootstrappers:kubeadm:default-node-token

localAPIEndpoint:
  advertiseAddress: "0.0.0.0"
  bindPort: 6443

nodeRegistration:
  name: "{{ get "host.hostname" }}"
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
    node-ip: "{{ get "host.internal" }}"
    hostname-override: "{{ get "host.hostname" }}"

skipPhases:
- "addon/kube-proxy"

---
# see https://kubernetes.io/zh-cn/docs/reference/config-api/kube-proxy-config.v1alpha1/
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration

bindAddress: "0.0.0.0"
healthzBindAddress: "0.0.0.0:10256"
metricsBindAddress: "0.0.0.0:10249"
enableProfiling: false
clusterCIDR: "{{ get "config.k8s.pod_subnet" }}"
hostnameOverride: "{{ get "host.hostname" }}"
mode: "ipvs"
{{- if get "config.k8s.kube_proxy_port_range" }}
portRange: "{{ get "config.k8s.kube_proxy_port_range" }}"
{{- else }}
portRange: "0-0"
{{- end }}

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
  {{- if get "config.k8s.ipvs_exclude_cidr" }}
  excludeCIDRs:
  {{- range (get "config.k8s.ipvs_exclude_cidr") }}
  - "{{ . }}"
  {{- end }}
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
streamingConnectionIdleTimeout: "5m"
evictionPressureTransitionPeriod: "30s"
evictionMaxPodGracePeriod: 120
serializeImagePulls: false # docker <= 1.9 or use 'aufs' must set true
maxParallelImagePulls: 10
registryPullQPS: 10
registryBurst: 20
eventRecordQPS: 100
eventBurst: 150
kubeAPIQPS: 100
kubeAPIBurst: 150
maxOpenFiles: 1024000
failSwapOn: true
runtimeRequestTimeout: "10m"

#featureGates:
#  RotateKubeletServerCertificate: "true"
#  InPlacePodVerticalScaling: "true"

#authorization:
#  mode: AlwaysAllow
#  webhook:
#    cacheAuthorizedTTL: "5m"
#    cacheUnauthorizedTTL: "30s"

systemReserved:
  cpu: "500m"
  memory: "500Mi"

kubeReserved:
  cpu: "500m"
  memory: "500Mi"

evictionHard:
  memory.available: "5%"
  pid.available: "10%"
  nodefs.available: "10%"
  nodefs.inodesFree: "5%"
  imagefs.available: "15%"

evictionSoft:
  memory.available: "10%"

evictionSoftGracePeriod:
  memory.available: "2m"

{{- if get "config.k8s.cluster_dns" }}
clusterDNS:
{{- range (get "config.k8s.cluster_dns") }}
- "{{ . }}"
{{- end }}
{{- end }}

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
  - key: "node-role.kubernetes.io/control-plane"
    value: ""
    effect: "NoSchedule"
  kubeletExtraArgs:
    node-ip: "{{ get "host.internal" }}"
    hostname-override: "{{ get "host.hostname" }}"

controlPlane:
  certificateKey: "{{ get "config.k8s.certificate_key" }}"
  localAPIEndpoint:
    advertiseAddress: "0.0.0.0"
    bindPort: 6443

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