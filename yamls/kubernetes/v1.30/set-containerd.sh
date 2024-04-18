#!/usr/bin/env bash
CRI_DIR=~/.k_8_s/cri
CONTAINERD_FILE=containerd-{{ .Configs.Containerd.Version }}-linux-{{ .Configs.Containerd.Arch }}.tar.gz
CONTAINERD_SHA256=${CONTAINERD_FILE}.sha256sum

# 创建
if [ ! -d ${CRI_DIR} ]; then
	mkdir -p ${CRI_DIR}
fi

# 下载
if [[ ! -f ${CRI_DIR}/${CONTAINERD_FILE} || ! -f ${CRI_DIR}/${CONTAINERD_SHA256} ]]; then
  echo "下载containerd和sha256sum"
  curl -fsSL -o ${CRI_DIR}/${CONTAINERD_FILE} https://github.com/containerd/containerd/releases/download/v{{ .Configs.Containerd.Version }}/${CONTAINERD_FILE}
  if [ $($?) != 0 ]; then exit $($?) fi
  curl -fsSL -o ${CRI_DIR}/${CONTAINERD_SHA256} https://github.com/containerd/containerd/releases/download/v{{ .Configs.Containerd.Version }}/${CONTAINERD_SHA256}
fi

#SHA256_SUM=$(sha256sum "${CONTAINERD_FILE}" | awk '{print $1}')
#SHA256_STD=$(cat "${CRI_DIR}/${CONTAINERD_SHA256}")
if [ -f ${CRI_DIR}/${CONTAINERD_FILE} && -f ${CRI_DIR}/${CONTAINERD_SHA256} ]; then
  if [ $(sha256sum -c "${CRI_DIR}/${CONTAINERD_SHA256}") == "${CONTAINERD_FILE}: OK"]; then

  fi
fi

# 检查是否启动
IS_ACTIVE=$(systemctl is-active containerd)
IS_ENABLED=$(systemctl is-enabled containerd)
if [[ "$IS_ACTIVE" == "active" && "$IS_ENABLED" == "enabled" ]]; then
	echo "containerd OK!"
	exit 0
fi

# 创建文件夹
if [ ! -d ~/.k_8_s/cri ]; then
	mkdir -p ~/.k_8_s/cri
fi

# 安装containerd
curl -fsSL -o ~/.k_8_s/cri/containerd-{{ .Configs.Containerd.Version }}-linux-{{ .Configs.Containerd.Arch }}.tar.gz https://github.com/containerd/containerd/releases/download/v{{ .Configs.Containerd.Version }}/containerd-{{ .Configs.Containerd.Version }}-linux-{{ .Configs.Containerd.Arch }}.tar.gz

tar Cxzvf /usr/local ~/.k_8_s/cri/containerd-{{ .Configs.Containerd.Version }}-linux-{{ .Configs.Containerd.Arch }}.tar.gz

# containerd配置文件
if [ -e /etc/containerd/config.toml ]; then
	cat /dev/null > /etc/containerd/config.toml
fi

cat >>/etc/containerd/config.toml<<EOF
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
        {{- range $key, $value := .Configs.Containerd.Mirrors }}
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."{{ $key }}"]
          endpoint = ["{{ $value }}"{{- if eq $key "docker.io" }}, "https://registry-1.docker.io"{{- end }}]
        {{- end }}
        {{ else }}
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://registry-1.docker.io"]
        {{- end}}

        {{- range $value := .Configs.Containerd.InsecureRegistries }}
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."{{$value}}"]
          endpoint = ["http://{{$value}}"]
        {{- end}}

        {{- if .Configs.Containerd.Auths }}
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
	exit 1
fi

# 安装runc
curl -fsSL -o ~/.k_8_s/cri/runc.{{ .Configs.Runc.Arch }} https://github.com/opencontainers/runc/releases/download/v{{ .Configs.Runc.Version }}/runc.{{ .Configs.Runc.Arch }}

install -m 755 ~/.k_8_s/cri/runc.{{ .Configs.Runc.Arch }} /usr/local/sbin/runc

# 安装CNI插件
curl -fsSL -o ~/.k_8_s/cri/cni-plugins-linux-{{ .Configs.CNIPlugins.Arch }}-v{{ .Configs.CNIPlugins.Version }}.tgz https://github.com/containernetworking/plugins/releases/download/v{{ .Configs.CNIPlugins.Version }}/cni-plugins-linux-{{ .Configs.CNIPlugins.Arch }}-v{{ .Configs.CNIPlugins.Version }}.tgz

mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin ~/.k_8_s/cri/cni-plugins-linux-{{ .Configs.CNIPlugins.Arch }}-v{{ .Configs.CNIPlugins.Version }}.tgz

# 安装crictl-tools
curl -fsSL -o ~/.k_8_s/cri/crictl-v{{ .Configs.Crictl.Version }}-linux-{{ .Configs.Crictl.Arch }}.tar.gz https://github.com/kubernetes-sigs/cri-tools/releases/download/v{{ .Configs.Crictl.Version }}/crictl-v{{ .Configs.Crictl.Version }}-linux-{{ .Configs.Crictl.Arch }}.tar.gz

mkdir -p /usr/bin && tar -zxf ~/.k_8_s/cri/crictl-v{{ .Configs.Crictl.Version }}-linux-{{ .Configs.Crictl.Arch }}.tar.gz -C /usr/bin
