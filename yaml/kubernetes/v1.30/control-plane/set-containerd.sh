#!/usr/bin/env bash

set -e

CRI_DIR="{{ get "host.workdir" }}"

CONTAINERD_ARCH="{{ get "config.containerd.arch" }}"
CONTAINERD_VERSION="{{ get "config.containerd.version" }}"

RUNC_ARCH=${CONTAINERD_ARCH}
RUNC_VERSION="{{ get "config.containerd.runc_version" }}"

CNI_ARCH=${CONTAINERD_ARCH}
CNI_VERSION="{{ get "config.containerd.cni_version" }}"

#CTL_ARCH=${CONTAINERD_ARCH}
#CTL_VERSION="{{ get "config.containerd.cri_ctl_version" }}"

CONTAINERD_TOML_FILE=/etc/containerd/config.toml
CONTAINERD_UNIT_FILE=/etc/systemd/system/containerd.service

# 是否已安装
if [ "$(systemctl is-active containerd)" == "active" ]; then
  echo "Containerd运行中,跳过安装Containerd"
  exit 0
fi

# 创建文件夹
mkdir -p "${CRI_DIR}"
mkdir -p /etc/containerd

# 下载containerd
CONTAINERD_FILE=containerd-${CONTAINERD_VERSION}-linux-${CONTAINERD_ARCH}.tar.gz
CONTAINERD_SHA256=${CONTAINERD_FILE}.sha256sum
if [ ! -e ${CRI_DIR}/${CONTAINERD_FILE} ]; then
  echo "下载Containerd"
  curl -fsSL -o ${CRI_DIR}/${CONTAINERD_FILE} https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/${CONTAINERD_FILE} || rm -f ${CRI_DIR}/${CONTAINERD_FILE} || exit 1
fi

if [ ! -e ${CRI_DIR}/${CONTAINERD_SHA256} ]; then
  echo "下载Containerd.sha256sum"
  curl -fsSL -o ${CRI_DIR}/${CONTAINERD_SHA256} https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/${CONTAINERD_SHA256} || rm -f ${CRI_DIR}/${CONTAINERD_SHA256} || exit 1
fi

echo "校验Containerd.sha256sum"
SHA256_SUM=$(sha256sum "${CRI_DIR}/${CONTAINERD_FILE}" | awk '{print $1}')
SHA256_STD=$(cat ${CRI_DIR}/${CONTAINERD_SHA256} | awk '{print $1}')
if [ "${SHA256_SUM}" != "${SHA256_STD}" ]; then
	echo "Containerd sha256sum not eq!"
  exit 1
fi

#下载runc
RUNC_FILE=runc.${RUNC_ARCH}
RUNC_ASC=${RUNC_FILE}.asc
if [ ! -e ${CRI_DIR}/${RUNC_FILE} ]; then
  echo "下载runc"
  curl -fsSL -o ${CRI_DIR}/${RUNC_FILE} https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/${RUNC_FILE} || rm -f ${CRI_DIR}/${RUNC_FILE} || exit 1
fi

if [ ! -e ${CRI_DIR}/${RUNC_ASC} ]; then
  echo "下载runc.asc"
  curl -fsSL -o ${CRI_DIR}/${RUNC_ASC} https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/${RUNC_ASC} || rm -f ${CRI_DIR}/${RUNC_ASC} || exit 1
fi

#if [ ! -e ${CRI_DIR}/runc.keyring ]; then
#  echo "下载runc.keyring"
#  curl -fsSL -o ${CRI_DIR}/runc.keyring https://github.com/opencontainers/runc/blob/main/runc.keyring || rm -f ${CRI_DIR}/runc.keyring
#fi
#
#echo "校验runc.asc"
#ASC_SUM=$(sha256sum runc.keyring > runc.keyring.sha256)
#ASC_OK="${RUNC_FILE}: OK"
#if [ "${ASC_SUM}" != "${ASC_OK}" ]; then
#	echo "校验runc md5 not eq!"
#	exit 1
#fi

#下载CNI
CNI_FILE=cni-plugins-linux-${CNI_ARCH}-v${CNI_VERSION}.tgz
CNI_SHA256=${CNI_FILE}.sha256
if [ ! -e ${CRI_DIR}/${CNI_FILE} ]; then
  echo "下载CNI"
  curl -fsSL -o ${CRI_DIR}/${CNI_FILE} https://github.com/containernetworking/plugins/releases/download/v${CNI_VERSION}/${CNI_FILE} || rm -f ${CRI_DIR}/${CNI_FILE} || exit 1
fi

if [ ! -e ${CRI_DIR}/${CNI_SHA256} ]; then
  echo "下载CNI.sha256"
  curl -fsSL -o ${CRI_DIR}/${CNI_SHA256} https://github.com/containernetworking/plugins/releases/download/v${CNI_VERSION}/${CNI_SHA256} || rm -f ${CRI_DIR}/${CNI_SHA256} || exit 1
fi

echo "校验CNI.sha256"
SHA256_SUM=$(sha256sum "${CRI_DIR}/${CNI_FILE}" | awk '{print $1}')
SHA256_STD=$(cat ${CRI_DIR}/${CNI_SHA256} | awk '{print $1}')
if [ "${SHA256_SUM}" != "${SHA256_STD}" ]; then
	echo "CNI sha256 not eq!"
  exit 1
fi

##下载CriCtl
#CTL_FILE=crictl-v${CTL_VERSION}-linux-${CTL_ARCH}.tar.gz
#CTL_SHA256=${CTL_FILE}.sha256
#if [ ! -e ${CRI_DIR}/${CTL_FILE} ]; then
#  echo "下载CTL"
#  curl -fsSL -o ${CRI_DIR}/${CTL_FILE} https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CTL_VERSION}/${CTL_FILE} || rm -f ${CRI_DIR}/${CTL_FILE} || exit 1
#fi
#
#if [ ! -e ${CRI_DIR}/${CTL_SHA256} ]; then
#  echo "下载CTL.sha256"
#  curl -fsSL -o ${CRI_DIR}/${CTL_SHA256} https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CTL_VERSION}/${CTL_SHA256} || rm -f ${CRI_DIR}/${CTL_SHA256} || exit 1
#fi
#
#echo "校验CTL.sha256"
#SHA256_SUM=$(sha256sum "${CRI_DIR}/${CTL_FILE}" | awk '{print $1}')
#SHA256_STD=$(cat ${CRI_DIR}/${CTL_SHA256})
#if [ "${SHA256_SUM}" != "${SHA256_STD}" ]; then
#	echo "CTL sha256 not eq!"
#	exit 1
#fi

#写入containerd配置文件
#输出默认配置文件(containerd config default > config.toml)
echo "写入containerd配置文件"
cat > ${CONTAINERD_TOML_FILE} <<EOF
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
    {{- if get "config.containerd.sand_box_image" }}
    sandbox_image = "{{ get "config.containerd.sand_box_image" }}"
    {{- else }}
    sandbox_image = "registry.k8s.io/pause:3.9"
    {{- end }}
    [plugins."io.containerd.grpc.v1.cri".cni]
      bin_dir = "/opt/cni/bin"
      conf_dir = "/etc/cni/net.d"
      max_conf_num = 1
      conf_template = ""
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        {{- if get "config.containerd.mirrors" }}
        {{- range $key, $value := (get "config.containerd.mirrors") }}
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."{{ $key }}"]
          endpoint = ["{{ $value }}"{{- if eq $key "docker.io" }}, "https://registry-1.docker.io"{{- end }}]
        {{- end }}
        {{ else }}
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://registry-1.docker.io"]
        {{- end}}

        {{- if get "config.containerd.auths" }}
        [plugins."io.containerd.grpc.v1.cri".registry.configs]
          {{- range $repo, $entry := (get "config.containerd.auths") }}
          [plugins."io.containerd.grpc.v1.cri".registry.configs."{{ $repo }}".auth]
            username = "{{ $entry.username }}"
            password = "{{ $entry.password }}"
            [plugins."io.containerd.grpc.v1.cri".registry.configs."{{ $repo }}".tls]
              ca_file = "{{ $entry.ca_file }}"
              cert_file = "{{ $entry.cert_file }}"
              key_file = "{{ $entry.key_file}}"
              insecure_skip_verify = {{ $entry.skip_tls_verify }}
          {{- end}}
        {{- end}}
EOF

#写入containerd单元文件
echo "写入containerd单元文件"
cat > ${CONTAINERD_UNIT_FILE} << "EOF"
# Copyright The containerd Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd

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

#安装containerd
echo "安装containerd"
tar Cxzvf /usr/local ${CRI_DIR}/${CONTAINERD_FILE}

#安装runc
echo "安装runc"
install -m 755 ${CRI_DIR}/${RUNC_FILE} /usr/local/sbin/runc

#安装CNI
echo "安装CNI"
mkdir -p /opt/cni/bin && tar Cxzvf /opt/cni/bin ${CRI_DIR}/${CNI_FILE}

##安装CTL
#mkdir -p /usr/bin && tar -zxf ${CRI_DIR}/${CTL_FILE} -C /usr/bin

#停止containerd
#CONTAINERD_IS_ACTIVE=$(systemctl is-active containerd.service)
#CONTAINERD_IS_ENABLED=$(systemctl is-enabled containerd.service)
#if [[ "$CONTAINERD_IS_ENABLED" == "enabled" && "$CONTAINERD_IS_ACTIVE" == "active" ]]; then
#  echo "停止containerd"
#	systemctl disable containerd.service
#	systemctl stop containerd.service
#fi

#启动containerd
echo "启动containerd"
systemctl daemon-reload
systemctl enable containerd --now

#检查是否启动
CONTAINERD_IS_ACTIVE=$(systemctl is-active containerd.service)
CONTAINERD_IS_ENABLED=$(systemctl is-enabled containerd.service)
if [[ "$CONTAINERD_IS_ENABLED" == "enabled" && "$CONTAINERD_IS_ACTIVE" == "active" ]]; then
  echo "Containerd Is Running"
  exit 0
else
  echo "Containerd Not Running"
  exit 1
fi