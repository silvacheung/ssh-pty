#!/usr/bin/env bash
set -e

cat >/etc/kubernetes/kubeadm-config.yaml<<EOF
---
# see https://kubernetes.io/zh-cn/docs/reference/config-api/kubeadm-config.v1beta4/
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration

kubernetesVersion: "{{ .Configs.K8s.Version }}" # "v1.21.0"
clusterName: "{{ .Configs.K8s.ClusterName }}" # "example-cluster"
imageRepository: "{{ .Configs.K8s.ImageRepository }}" # "registry.k8s.io"
controlPlaneEndpoint: "{{ .Configs.K8s.ControlPlaneEndpoint }}" # "10.100.0.1:6443"
certificatesDir: "/etc/kubernetes/pki"

#featureGates:
#  RotateKubeletServerCertificate: true
#  TTLAfterFinished: true
#  SeccompDefault: true

etcd:
  # one of local or external
  local:
    # imageRepository: "{{ .Configs.K8s.Etcd.ImageRepository }}" # "registry.k8s.io"
    # imageTag: "{{ .Configs.K8s.Etcd.ImageTag }}" # "3.2.24"
    dataDir: "/var/lib/etcd"
    # serverCertSANs:
    # - "localhost"
    # - "127.0.0.1"
    # - "::1"
    # - "0:0:0:0:0:0:0:1"
    # - "etcd.kube-system.svc.cluster.local"
    # - "etcd.kube-system.svc"
    # - "etcd.kube-system"
    # - "etcd"
    # peerCertSANs:
    # - "10.100.0.1"
    # - "10.100.0.2"
    # extraArgs:
    #   listen-client-urls: "http://10.100.0.1:2379"

  # external:
  #   endpoints:
  #   - "10.100.0.1:2379"
  #   - "10.100.0.2:2379"
  #   caFile: "/etcd/kubernetes/pki/etcd/etcd-ca.crt"
  #   certFile: "/etcd/kubernetes/pki/etcd/etcd.crt"
  #   keyFile: "/etcd/kubernetes/pki/etcd/etcd.key"

#dns:
  # imageRepository: "{{ .Configs.K8s.Coredns.ImageRepository }}"
  # imageTag: "{{ .Configs.K8s.Coredns.ImageTag }}"

networking:
  dnsDomain: "cluster.local"
  serviceSubnet: "{{ .Configs.K8s.ServiceSubnet }}" # "10.96.0.0/16"
  podSubnet: "{{ .Configs.K8s.PodSubnet }}" # "10.244.0.0/24"

apiServer:
  timeoutForControlPlane: "4m0s"
  extraArgs:
    # service-cluster-ip-range: <IPv4 CIDR>,<IPv6 CIDR>
    bind-address: "0.0.0.0"
    authorization-mode: "Node,RBAC"
    enable-admission-plugins: "AlwaysPullImages,ServiceAccount,NamespaceLifecycle,NodeRestriction,LimitRanger,ResourceQuota,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,PodNodeSelector,PodSecurity"
    audit-log-path: "/var/log/apiserver/audit.log"
    profiling: "false"
    request-timeout: "120s"
    service-account-lookup: "true"
    tls-min-version: "VersionTLS12"
    tls-cipher-suites: "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305"
    audit-log-format: "json"
    audit-log-maxbackup: "2"
    audit-log-maxsize: "200"
    audit-policy-file: "/etc/kubernetes/audit/audit-policy.yaml"
    audit-webhook-config-file: "/etc/kubernetes/audit/audit-webhook.yaml"
    feature-gates: "RotateKubeletServerCertificate,TTLAfterFinished,SeccompDefault,CSIStorageCapacity"
  extraVolumes:
  - name: k8s-audit
    hostPath: /etc/kubernetes/audit
    mountPath: /etc/kubernetes/audit
    pathType: DirectoryOrCreate
    readOnly: false
  # certSANs:
  # - "localhost"
  # - "127.0.0.1"
  # - "::1"
  # - "0:0:0:0:0:0:0:1"
  # - "kubernetes.default.svc.cluster.local"
  # - "kubernetes.default.svc"
  # - "kubernetes.default"
  # - "kubernetes"

controllerManager:
  extraArgs:
    # node-cidr-mask-size-ipv4: "24"
    # node-cidr-mask-size-ipv6: "64"
    # cluster-cidr: <IPv4 CIDR>,<IPv6 CIDR>
    # service-cluster-ip-range: <IPv4 CIDR>,<IPv6 CIDR>
    bind-address: "127.0.0.1"
    cluster-signing-duration: "87600h"
    profiling: "false"
    terminated-pod-gc-threshold: "50"
    use-service-account-credentials: "true"
    node-cidr-mask-size: "{{ .Configs.K8s.NodeCidrMaskSize }}"
  extraVolumes:
  - name: "host-time"
    hostPath: "/etc/localtime"
    mountPath: "/etc/localtime"
    readOnly: true
    pathType: File

scheduler:
  extraArgs:
    bind-address: "127.0.0.1"
    profiling:    "false"
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

# bootstrapTokens:
# - token: "9a08jv.c0izixklcxtmnze7"
#   description: "kubeadm bootstrap token"
#   ttl: "24h"
# - token: "783bde.3f89s0fje9f38fhf"
#   description: "another bootstrap token"
#   usages:
#   - authentication
#   - signing
#   groups:
#   - system:bootstrappers:kubeadm:default-node-token

localAPIEndpoint:
  advertiseAddress: "0.0.0.0"
  bindPort: 6443

nodeRegistration:
  # name: "ec2-10-100-0-1"
  criSocket: "unix:///var/run/containerd/containerd.sock"
  imagePullPolicy: "IfNotPresent"
  ignorePreflightErrors:
  - "IsPrivilegedUser"
  - "FileExisting-crictl"
  - "ImagePull"
  taints:
  - key: "kubeadmNode"
    value: "someValue"
    effect: "NoSchedule"
  kubeletExtraArgs:
    network-plugin: "cni"
    cgroup-driver: "systemd"
    node-ip: "{{ .Host.Internal }}"
    hostname-override: "{{ .Host.Hostname }}"

certificateKey: "{{ .Configs.K8s.CertificateKey }}"
skipPhases:
- "addon/kube-proxy"

---
# see https://kubernetes.io/zh-cn/docs/reference/config-api/kube-proxy-config.v1alpha1/
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration

# bindAddress: "0.0.0.0"
# healthzBindAddress: "0.0.0.0:10256"
# metricsBindAddress: "127.0.0.1:10249"
# bindAddressHardFail: false
enableProfiling: true
clusterCIDR: "{{ .Configs.K8s.PodSubnet }}"
# hostnameOverride: ""
# oomScoreAdj: -999
mode: "ipvs"
# portRange: "0-0"
# configSyncPeriod: "5s"
# showHiddenMetricsForVersion: ""

#featureGates:
#  RotateKubeletServerCertificate: true
#  TTLAfterFinished: true
#  SeccompDefault: true

iptables:
  masqueradeBit: 14
  syncPeriod: "30s"
  minSyncPeriod: "0s"
  masqueradeAll: false
  # localhostNodePorts: true

ipvs:
  # scheduler: ""
  syncPeriod: "30s"
  minSyncPeriod: "0s"
  excludeCIDRs:
  # - "172.16.0.0/24"
  {{- range .Configs.K8s.IPVSExcludeCIDRs }}
  - "{{ . }}"
  {{- end }}
  strictARP: true
  tcpTimeout: "0"
  tcpFinTimeout: "0"
  udpTimeout: "0"

# clientConnection:
#   kubeconfig: ""
#   acceptContentTypes: "application/json"
#   contentType: "application/json"
#   qps: 100
#   burst: 10

# conntrack:
#   maxPerCore: 0
#   min: 0
#   tcpEstablishedTimeout: "2s"
#   tcpCloseWaitTimeout: "60s"

# nodePortAddresses:
# - "127.0.0.0/8"

# winkernel:
#   networkName: ""
#   sourceVip: ""
#   enableDSR: true
#   rootHnsEndpointName: ""
#   forwardHealthCheckVip: true

# detectLocalMode: "LocalModeClusterCIDR"
# detectLocal:
#   bridgeInterface: ""
#   interfaceNamePrefix: ""

---
# see https://kubernetes.io/zh-cn/docs/reference/config-api/kubelet-config.v1beta1/
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration

# address: "0.0.0.0"
# port: 10250
# healthzBindAddress: "127.0.0.1"
# healthzPort: 10248
# enableServer: true
staticPodPath: "/etc/kubernetes/manifests"
# syncFrequency: "1m"
# fileCheckFrequency: "20s"
# httpCheckFrequency: "20s"
# staticPodURL: ""
readOnlyPort: 0
# tlsCertFile: ""
# tlsPrivateKeyFile: ""
# tlsMinVersion: ""
rotateCertificates: true
# serverTLSBootstrap: false
# registryPullQPS: 5
# registryBurst: 10
eventRecordQPS: 1
# eventBurst: 100
# enableDebuggingHandlers: true
# enableContentionProfiling: false
# oomScoreAdj: -999
clusterDomain: "cluster.local"
streamingConnectionIdleTimeout: "5m"
# nodeStatusUpdateFrequency: "10s"
# nodeStatusReportFrequency: "5m"
# nodeLeaseDurationSeconds: 40
# imageMinimumGCAge: "2m"
# imageMaximumGCAge: "0s"
# imageGCHighThresholdPercent: 85
# imageGCLowThresholdPercent: 80
# volumeStatsAggPeriod: "1m"
# kubeletCgroups: ""
# systemCgroups: ""
# cgroupRoot: ""
# cgroupsPerQOS: true
cgroupDriver: "systemd"
# cpuManagerPolicy: "None"
# cpuManagerReconcilePeriod: "10s"
# memoryManagerPolicy: "none"
# topologyManagerPolicy: "none"
# topologyManagerScope: "container"
# runtimeRequestTimeout: "2m"
# hairpinMode: "promiscuous-bridge"
maxPods: 110
# podCIDR: ""
podPidsLimit: -1
# resolvConf: "/etc/resolv.conf"
# runOnce: false
# cpuCFSQuota: true
# cpuCFSQuotaPeriod: "100ms"
# nodeStatusMaxImages: 50
# maxOpenFiles: 1000000
# contentType: "application/vnd.kubernetes.protobuf"
# kubeAPIQPS: 50
# kubeAPIBurst: 100
# serializeImagePulls: true
# maxParallelImagePulls: 0
evictionPressureTransitionPeriod: "30s"
evictionMaxPodGracePeriod: 120
# podsPerCore: 0
# enableControllerAttachDetach: true
protectKernelDefaults: true
makeIPTablesUtilChains: true
# failSwapOn: true
containerLogMaxSize: "5Mi"
containerLogMaxFiles: 3
# configMapAndSecretChangeDetectionStrategy: "Watch"
# reservedSystemCPUs: ""
# showHiddenMetricsForVersion: ""
# systemReservedCgroup: ""
# kubeReservedCgroup: ""
# volumePluginDir: "/usr/libexec/kubernetes/kubelet-plugins/volume/exec/"
# providerID: ""
# kernelMemcgNotification: false
# enableSystemLogHandler: true
# enableSystemLogQuery: false
# shutdownGracePeriod: "0s"
# shutdownGracePeriodCriticalPods: "0s"
# enableProfilingHandler: true
# enableDebugFlagsHandler: true
# seccompDefault: false
# memoryThrottlingFactor: 0.8
# registerNode: true
# localStorageCapacityIsolation: true
containerRuntimeEndpoint: "unix:///var/run/containerd/containerd.sock"

#featureGates:
#  RotateKubeletServerCertificate: true
#  TTLAfterFinished: true
#  SeccompDefault: true

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

tlsCipherSuites:
- "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256"
- "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
- "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305"

# clusterDNS:
# - "8.8.8.8"
# - "114.114.114.114"

# cpuManagerPolicyOptions:
#   key-1: "value-1"
#   key-2: "value-2"

# topologyManagerPolicyOptions:
#   key-1: "value-1"
#   key-2: "value-2"

# qosReserved:
#   key-1: "value-1"
#   key-2: "value-2"

# evictionMinimumReclaim:
#   key-1: "value-1"
#   key-2: "value-2"

# enforceNodeAllocatable:
# - "value-1"
# - "value-2"

# allowedUnsafeSysctls:
# - "value-1"
# - "value-2"

# staticPodURLHeader:
#   key-1:
#   - "value-1"
#   - "value-2"
#   key-2:
#   - "value-3"
#   - "value-4"

# memorySwap:
#   swapBehavior: "LimitedSwap"

# authentication:
#   x509:
#     clientCAFile: ""
#   webhook:
#     enabled: true
#     cacheTTL: "2m"
#   anonymous:
#     enabled: false

# authorization:
#   mode: "Webhook"
#   webhook:
#     cacheAuthorizedTTL: "5m"
#     cacheUnauthorizedTTL: "30s"

# logging:
#   format: "text"
#   verbosity: 0

# shutdownGracePeriodByPodPriority:
# - priority: 0
#   shutdownGracePeriodSeconds: 0
# - priority: 0
#   shutdownGracePeriodSeconds: 0

# reservedMemory:
# - numaNode: 0
#   limits:

# registerWithTaints:
# - key: "kubeadmNode"
#   value: "someValue"
#   effect: "NoSchedule"

# tracing:
#   endpoint: ""
#   samplingRatePerMillion: 0

---
# see https://kubernetes.io/zh-cn/docs/reference/config-api/kubeadm-config.v1beta4/
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration

caCertPath: "/etc/kubernetes/pki/ca.crt"

nodeRegistration:
  # name: ""
  criSocket: "unix:///var/run/containerd/containerd.sock"
  imagePullPolicy: "IfNotPresent"
  ignorePreflightErrors:
  - "IsPrivilegedUser"
  - "FileExisting-crictl"
  - "ImagePull"
  taints:
  - key: "kubeadmNode"
    value: "someValue"
    effect: "NoSchedule"
  kubeletExtraArgs:
    network-plugin: "cni"
    cgroup-driver: "systemd"
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
    apiServerEndpoint: "{{ .Configs.K8s.ControlPlaneEndpoint }}"
  #   caCertHashes:
  #   - ""
  #   - ""
  # file:
  #  kubeConfigPath: ""

skipPhases:
- "addon/kube-proxy"

#---
# see https://kubernetes.io/zh-cn/docs/reference/config-api/kubeadm-config.v1beta4/
#apiVersion: kubeadm.k8s.io/v1beta3
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