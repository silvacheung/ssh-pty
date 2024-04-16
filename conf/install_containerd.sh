#!/usr/bin/env bash


# 检查是否启动
IS_ACTIVE=$(systemctl is-active containerd)
IS_ENABLED=$(systemctl is-enabled containerd)
if [[ "$IS_ACTIVE" == "active" && "$IS_ENABLED" == "enabled" ]]; then
	echo "containerd OK!"
	exit 0
fi

# 创建文件夹
rm -r ~/.k_8_s/cri
mkdir -p ~/.k_8_s/cri

# 安装containerd
CONTAINERD_OS=linux
CONTAINERD_ARCH=amd64
CONTAINERD_VERSION=1.7.13 # 1.7.15

# curl -L -o ~/.k_8_s/cri/containerd-${CONTAINERD_VERSION}-${CONTAINERD_OS}-${CONTAINERD_ARCH}.tar.gz https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-${CONTAINERD_OS}-${CONTAINERD_ARCH}.tar.gz
curl -L -o ~/.k_8_s/cri/containerd-${CONTAINERD_VERSION}-${CONTAINERD_OS}-${CONTAINERD_ARCH}.tar.gz https://kubernetes-release.pek3b.qingstor.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-${CONTAINERD_OS}-${CONTAINERD_ARCH}.tar.gz

tar Cxzvf /usr/local ~/.k_8_s/cri/containerd-${CONTAINERD_VERSION}-${CONTAINERD_OS}-${CONTAINERD_ARCH}.tar.gz

# containerd配置文件
CONTAINERD_TOML_FILE=/etc/containerd/config.toml
cat >>$CONTAINERD_TOML_FILE<<EOF
version = 2
root = "/var/lib/containerd"
state = "/run/containerd"
[grpc]
  address = "/run/containerd/containerd.sock"
  uid = 0
  gid = 0
  max_recv_message_size = 16777216
  max_send_message_size = 16777216

[ttrpc]
  address = ""
  uid = 0
  gid = 0

[debug]
  address = ""
  uid = 0
  gid = 0
  level = ""

[metrics]
  address = ""
  grpc_histogram = false

[cgroup]
  path = ""

[timeouts]
  "io.containerd.timeout.shim.cleanup" = "5s"
  "io.containerd.timeout.shim.load" = "5s"
  "io.containerd.timeout.shim.shutdown" = "3s"
  "io.containerd.timeout.task.state" = "2s"

[plugins]
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
    runtime_type = "io.containerd.runc.v2"
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
      SystemdCgroup = true
  [plugins."io.containerd.grpc.v1.cri"]
    sandbox_image = "{{ .Configs.Containerd.SandBoxImage }}"
    [plugins."io.containerd.grpc.v1.cri".cni]
      bin_dir = "/opt/cni/bin"
      conf_dir = "/etc/cni/net.d"
      max_conf_num = 1
      conf_template = ""
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        {{- if gt (len .Configs.Containerd.Mirrors) 0 }}
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = [{{- range .Configs.Containerd.Mirrors }}"{{ . }}", {{- end }}"https://registry-1.docker.io"]
        {{ else }}
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://registry-1.docker.io"]
        {{- end}}
        {{- range $value := .Configs.Containerd.InsecureRegistries }}
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."{{$value}}"]
          endpoint = ["http://{{$value}}"]
        {{- end}}

        {{- if .Auths }}
        [plugins."io.containerd.grpc.v1.cri".registry.configs]
          {{- range $repo, $entry := .Configs.Containerd.Auths }}
          [plugins."io.containerd.grpc.v1.cri".registry.configs."{{$repo}}".auth]
            username = "{{$entry.Username}}"
            password = "{{$entry.Password}}"
            [plugins."io.containerd.grpc.v1.cri".registry.configs."{{$repo}}".tls]
              ca_file = "{{$entry.CAFile}}"
              cert_file = "{{$entry.CertFile}}"
              key_file = "{{$entry.KeyFile}}"
              insecure_skip_verify = {{$entry.SkipTLSVerify}}
          {{- end}}
        {{- end}}
EOF

# containerd单元文件
CONTAINERD_UNIT_FILE=/etc/systemd/system/containerd.service
CONTAINERD_IS_ACTIVE=$(systemctl is-active containerd.service)
CONTAINERD_IS_ENABLED=$(systemctl is-enabled containerd.service)
if [ "$CONTAINERD_IS_ACTIVE" == "active" ]; then
	systemctl disable containerd.service
	systemctl stop containerd.service
	cat /dev/null > $CONTAINERD_UNIT_FILE
fi

cat > $CONTAINERD_UNIT_FILE << "EOF"
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/bin/containerd

Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=1048576
# Comment TasksMax if your systemd version does not supports it.
# Only systemd 226 and above support this version.
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF

# 启动containerd
systemctl daemon-reload
systemctl enable containerd --now

# 检查是否启动
IS_ACTIVE=$(systemctl is-active containerd)
IS_ENABLED=$(systemctl is-enabled containerd)
if [[ "$IS_ACTIVE" == "active" && "$IS_ENABLED" == "enabled" ]]; then
	echo "containerd OK!"
else
	echo "containerd Bad!"
fi

# 安装runc
RUNC_ARCH=amd64
RUNC_VERSION=1.1.12

# curl -L -o ~/.k_8_s/cri/runc.${RUNC_ARCH} https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.${RUNC_ARCH}
curl -L -o ~/.k_8_s/cri/runc.${RUNC_ARCH} https://kubernetes-release.pek3b.qingstor.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.${RUNC_ARCH}

install -m 755 ~/.k_8_s/cri/runc.${RUNC_ARCH} /usr/local/sbin/runc

# 安装CNI插件
#CNI_PLG_OS=linux
#CNI_PLG_ARCH=amd64
#CNI_PLG_VERSION=1.4.1

# curl -L -o ~/.k_8_s/cri/cni-plugins-${CNI_PLG_OS}-${CNI_PLG_ARCH}-v${CNI_PLG_VERSION}.tgz https://github.com/containernetworking/plugins/releases/download/v${CNI_PLG_VERSION}/cni-plugins-${CNI_PLG_OS}-${CNI_PLG_ARCH}-v${CNI_PLG_VERSION}.tgz
#curl -L -o ~/.k_8_s/cri/cni-plugins-linux-amd64-v1.4.1.tgz https://kubernetes-release.pek3b.qingstor.com/containernetworking/plugins/releases/download/v1.4.1/cni-plugins-linux-amd64-v1.4.1.tgz

#mkdir -p /opt/cni/bin
#tar Cxzvf /opt/cni/bin ~/.k_8_s/cri/cni-plugins-${CNI_PLG_OS}-${CNI_PLG_ARCH}-v${CNI_PLG_VERSION}.tgz

# 安装crictl-tools
CRICTL_OS=linux
CRICTL_ARCH=amd64
CRICTL_VERSION=1.29.0

#curl -L -o ~/.k_8_s/cri/crictl-v${CRICTL_VERSION}-${CRICTL_OS}-${CRICTL_ARCH}.tar.gz https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CRICTL_VERSION}/crictl-v${CRICTL_VERSION}-${CRICTL_OS}-${CRICTL_ARCH}.tar.gz
curl -L -o ~/.k_8_s/cri/crictl-v${CRICTL_VERSION}-${CRICTL_OS}-${CRICTL_ARCH}.tar.gz https://kubernetes-release.pek3b.qingstor.com/cri-tools/releases/download/v${CRICTL_VERSION}/crictl-v${CRICTL_VERSION}-${CRICTL_OS}-${CRICTL_ARCH}.tar.gz

mkdir -p /usr/bin && tar -zxf ~/.k_8_s/cri/crictl-v${CRICTL_VERSION}-${CRICTL_OS}-${CRICTL_ARCH}.tar.gz -C /usr/bin