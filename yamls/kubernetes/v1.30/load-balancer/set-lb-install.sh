#!/usr/bin/env bash

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

# haproxy重启
if [ "$(systemctl is-active haproxy)" != "active" ]; then
  systemctl daemon-reload
	systemctl start haproxy
else
  systemctl daemon-reload
	systemctl restart haproxy
fi

if [ "$(systemctl is-enabled haproxy)" != "enabled" ]; then
  systemctl daemon-reload
	systemctl enable haproxy
fi

# keepalived重启
if [ "$(systemctl is-active keepalived)" != "active" ]; then
  systemctl daemon-reload
	systemctl start keepalived
else
  systemctl daemon-reload
	systemctl restart keepalived
fi

if [ "$(systemctl is-enabled keepalived)" != "enabled" ]; then
  systemctl daemon-reload
	systemctl enable keepalived
fi

# 最后检查是否安装成功
if [[ "$(systemctl is-active haproxy)" == "active" && "$(systemctl is-enabled haproxy)" == "enabled" && "$(systemctl is-active keepalived)" == "active" && "$(systemctl is-enabled keepalived)" == "enabled" ]]; then
	echo "LB Is Running"
else
	echo "LB Not Running"
fi