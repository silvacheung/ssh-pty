#!/usr/bin/env bash

set -e

{{- if ne (get "config.k8s.control_plane_endpoint.balancer") "" }}
exit 0
{{- end }}

# Haproxy安装将阻塞确认重名的配置文件
echo "重命名配置文件 >> /etc/haproxy/haproxy.cfg"
if [ -f /etc/haproxy/haproxy.cfg ]; then
  mv -f /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.000
fi

echo "重命名配置文件 >> /etc/keepalived/keepalived.conf"
if [ -f /etc/keepalived/keepalived.conf ]; then
  mv -f /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.000
fi

if [ ! "$(command -v haproxy)" ]; then
  echo "安装LoadBalancer >> haproxy"
	curl https://haproxy.debian.net/bernat.debian.org.gpg | gpg --dearmor > /usr/share/keyrings/haproxy.debian.net.gpg
	echo deb "[signed-by=/usr/share/keyrings/haproxy.debian.net.gpg]" http://haproxy.debian.net bookworm-backports-2.9 main > /etc/apt/sources.list.d/haproxy.list
	apt update
	apt -y install haproxy=2.9.\*
	systemctl daemon-reload
	systemctl enable haproxy --now
fi

if [ ! "$(command -v keepalived)" ]; then
  echo "安装LoadBalancer >> keepalived"
	apt update
	apt -y install keepalived
	systemctl daemon-reload
	systemctl enable keepalived --now
fi

if [[ "$(systemctl is-enabled haproxy)" == "enabled" && "$(systemctl is-enabled keepalived)" == "enabled" ]]; then
	echo "安装LoadBalancer >> enabled"
else
	echo "安装LoadBalancer >> not enabled"
	exit 1
fi

echo "回滚重命名文件 >> /etc/haproxy/haproxy.cfg"
if [ -f /etc/haproxy/haproxy.cfg.000 ]; then
  mv /etc/haproxy/haproxy.cfg.000 /etc/haproxy/haproxy.cfg
fi

echo "回滚重命名文件 >> /etc/keepalived/keepalived.conf"
if [ -f /etc/keepalived/keepalived.conf.000 ]; then
  mv /etc/keepalived/keepalived.conf.000 /etc/keepalived/keepalived.conf
fi

echo "安装LoadBalancer >> restart service"
systemctl daemon-reload
systemctl restart haproxy
systemctl restart keepalived

if [[ "$(systemctl is-active haproxy)" == "active" && "$(systemctl is-active keepalived)" == "active" ]]; then
	echo "安装LoadBalancer >> active"
else
	echo "安装LoadBalancer >> not active"
	exit 1
fi