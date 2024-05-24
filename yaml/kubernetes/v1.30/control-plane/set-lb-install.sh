#!/usr/bin/env bash

set -e

{{- if eq (get "config.k8s.control_plane_endpoint.balancer") "" }}

# 重命名配置文件(否则haproxy安装将阻塞确认配置文件)
if [ -f /etc/haproxy/haproxy.cfg ]; then
  mv -f /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.000
fi

if [ -f /etc/keepalived/keepalived.conf ]; then
  mv -f /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.000
fi

# 安装haproxy
if [ ! "$(command -v haproxy)" ]; then
  echo "安装haproxy"
	curl https://haproxy.debian.net/bernat.debian.org.gpg | gpg --dearmor > /usr/share/keyrings/haproxy.debian.net.gpg
	echo deb "[signed-by=/usr/share/keyrings/haproxy.debian.net.gpg]" http://haproxy.debian.net bookworm-backports-2.9 main > /etc/apt/sources.list.d/haproxy.list
	apt update
	apt -y install haproxy=2.9.\*
	systemctl daemon-reload
	systemctl enable haproxy --now
fi

# 安装keepalived
if [ ! "$(command -v keepalived)" ]; then
  echo "安装keepalived"
	apt update
	apt -y install keepalived
	systemctl daemon-reload
	systemctl enable keepalived --now
fi

# 是否安装成功
if [[ "$(systemctl is-enabled haproxy)" == "enabled" && "$(systemctl is-enabled keepalived)" == "enabled" ]]; then
	echo "LB Is Enabled"
else
	echo "LB Not Enabled"
	exit 1
fi

# 覆盖默认配置文件
if [ -f /etc/haproxy/haproxy.cfg.000 ]; then
  mv /etc/haproxy/haproxy.cfg.000 /etc/haproxy/haproxy.cfg
fi

if [ -f /etc/keepalived/keepalived.conf.000 ]; then
  mv /etc/keepalived/keepalived.conf.000 /etc/keepalived/keepalived.conf
fi

# haproxy、keepalived重启
systemctl daemon-reload
systemctl restart haproxy
systemctl restart keepalived

# 是否成功运行
if [[ "$(systemctl is-active haproxy)" == "active" && "$(systemctl is-active keepalived)" == "active" ]]; then
	echo "LB Is Running"
else
	echo "LB Not Running"
	exit 1
fi

{{- end }}