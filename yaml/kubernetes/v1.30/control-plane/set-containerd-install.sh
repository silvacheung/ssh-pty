#!/usr/bin/env bash

set -e

CRI_DIR="{{ get "host.workdir" }}"

CONTAINERD_ARCH="{{ get "config.containerd.arch" }}"
CONTAINERD_VERSION="{{ get "config.containerd.version" }}"

RUNC_ARCH=${CONTAINERD_ARCH}
RUNC_VERSION="{{ get "config.containerd.runc_version" }}"

CNI_ARCH=${CONTAINERD_ARCH}
CNI_VERSION="{{ get "config.containerd.cni_version" }}"

if [ "$(systemctl is-active containerd)" == "active" ]; then
  echo "安装Container >> containerd运行中"
  exit 0
fi

mkdir -p "${CRI_DIR}"

CONTAINERD_FILE=containerd-${CONTAINERD_VERSION}-linux-${CONTAINERD_ARCH}.tar.gz
if [ ! -e ${CRI_DIR}/${CONTAINERD_FILE} ]; then
  echo "安装Container >> 下载${CONTAINERD_FILE}"
  curl -fsSL -o ${CRI_DIR}/${CONTAINERD_FILE} https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/${CONTAINERD_FILE} || rm -f ${CRI_DIR}/${CONTAINERD_FILE} || exit 1
fi

CONTAINERD_SHA256=${CONTAINERD_FILE}.sha256sum
if [ ! -e ${CRI_DIR}/${CONTAINERD_SHA256} ]; then
  echo "安装Container >> 下载${CONTAINERD_SHA256}"
  curl -fsSL -o ${CRI_DIR}/${CONTAINERD_SHA256} https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/${CONTAINERD_SHA256} || rm -f ${CRI_DIR}/${CONTAINERD_SHA256} || exit 1
fi

echo "安装Container >> 校验${CONTAINERD_SHA256}"
cd ${CRI_DIR} && sha256sum -c ${CONTAINERD_SHA256}

RUNC_FILE=runc.${RUNC_ARCH}
if [ ! -e ${CRI_DIR}/${RUNC_FILE} ]; then
  echo "安装Container >> 下载${RUNC_FILE}"
  curl -fsSL -o ${CRI_DIR}/${RUNC_FILE} https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/${RUNC_FILE} || rm -f ${CRI_DIR}/${RUNC_FILE} || exit 1
fi

RUNC_ASC=${RUNC_FILE}.asc
if [ ! -e ${CRI_DIR}/${RUNC_ASC} ]; then
  echo "安装Container >> 下载${RUNC_ASC}"
  curl -fsSL -o ${CRI_DIR}/${RUNC_ASC} https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/${RUNC_ASC} || rm -f ${CRI_DIR}/${RUNC_ASC} || exit 1
fi

#RUNC_KEYRING=runc.keyring
#if [ ! -e ${CRI_DIR}/runc.keyring ]; then
#  echo "安装Container >> 下载${RUNC_KEYRING}"
#  curl -fsSL -o ${CRI_DIR}/runc.keyring https://github.com/opencontainers/runc/blob/main/runc.keyring || rm -f ${CRI_DIR}/runc.keyring
#fi

echo "安装Container >> 校验${RUNC_ASC}"

CNI_FILE=cni-plugins-linux-${CNI_ARCH}-v${CNI_VERSION}.tgz
if [ ! -e ${CRI_DIR}/${CNI_FILE} ]; then
  echo "安装Container >> 下载${CNI_FILE}"
  curl -fsSL -o ${CRI_DIR}/${CNI_FILE} https://github.com/containernetworking/plugins/releases/download/v${CNI_VERSION}/${CNI_FILE} || rm -f ${CRI_DIR}/${CNI_FILE} || exit 1
fi

CNI_SHA256=${CNI_FILE}.sha256
if [ ! -e ${CRI_DIR}/${CNI_SHA256} ]; then
  echo "安装Container >> 下载${CNI_SHA256}"
  curl -fsSL -o ${CRI_DIR}/${CNI_SHA256} https://github.com/containernetworking/plugins/releases/download/v${CNI_VERSION}/${CNI_SHA256} || rm -f ${CRI_DIR}/${CNI_SHA256} || exit 1
fi

echo "安装Container >> 校验${CNI_SHA256}"
cd ${CRI_DIR} && sha256sum -c ${CNI_SHA256}

echo "安装Container >> 写入/etc/systemd/system/containerd.service"
cat > /etc/systemd/system/containerd.service << "EOF"
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

echo "安装Container >> 安装containerd/runc/cni"
tar Cxzvf /usr/local ${CRI_DIR}/${CONTAINERD_FILE}
install -m 755 ${CRI_DIR}/${RUNC_FILE} /usr/local/sbin/runc
mkdir -p /opt/cni/bin && tar Cxzvf /opt/cni/bin ${CRI_DIR}/${CNI_FILE}

systemctl daemon-reload
systemctl enable containerd --now

CONTAINERD_IS_ENABLED=$(systemctl is-enabled containerd.service)
if [ "$CONTAINERD_IS_ENABLED" == "enabled" ]; then
  echo "安装Container >> enabled"
else
  echo "安装Container >> not enabled"
  exit 1
fi

CONTAINERD_IS_ACTIVE=$(systemctl is-active containerd.service)
if [ "$CONTAINERD_IS_ACTIVE" == "active" ]; then
  echo "安装Container >> active"
else
  echo "安装Container >> not active"
  exit 1
fi