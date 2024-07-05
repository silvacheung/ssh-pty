#!/usr/bin/env bash

set -e

NET_IF=$(ip route | grep ' {{ get "host.internal" }} ' | grep 'proto kernel scope link src' | sed -e 's/^.*dev.//' -e 's/.proto.*//' | uniq)
if [ "${NET_IF}" == "" ]; then
  echo "获取主机网卡名 >> 失败"
  exit 1
fi

mkdir -p /etc/haproxy
mkdir -p /etc/keepalived

echo "写入配置文件 >> /etc/haproxy/haproxy.cfg"
cat > /etc/haproxy/haproxy.cfg << EOF
# /etc/haproxy/haproxy.cfg
#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
  log           127.0.0.1 local0
  chroot        /var/lib/haproxy
  pidfile       /var/run/haproxy.pid
  stats socket  /var/lib/haproxy/stats
  maxconn       4000
  daemon

#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
  mode                    http
  log                     global
  option                  httplog
  option                  dontlognull
  option                  http-server-close
  option  forwardfor      except 127.0.0.0/8
  option  redispatch
  retries                 3
  timeout http-request    10s
  timeout queue           20s
  timeout connect         5s
  timeout client          20s
  timeout server          20s
  timeout http-keep-alive 10s
  timeout check           10s
  maxconn                 4000

#---------------------------------------------------------------------
# kube-api-server frontend which proxys to the control plane nodes
#---------------------------------------------------------------------
frontend f-kube-api-server
  bind  *:{{ get "config.frontend" }}
  mode  tcp
  option  tcplog
  default_backend b-kube-api-server

#---------------------------------------------------------------------
# round robin balancing for kube-api-server
#---------------------------------------------------------------------
backend b-kube-api-server
  mode  tcp
  option  ssl-hello-chk
  balance roundrobin
  {{- range (get "config.backends") }}
  server {{ .hostname }} {{ .endpoint }} check inter 3s weight 100 fall 3 rise 3
  {{- end }}

#---------------------------------------------------------------------
# haproxy stats dashboard
#---------------------------------------------------------------------
#frontend stats
#  bind *:8080
#  mode http
#  stats enable
#  stats refresh 10s
#  stats auth admin:123456
#  stats realm "Welcome to the haproxy load balancer status page"
#  stats uri /stats
EOF

echo "写入配置文件 >> /etc/keepalived/keepalived.conf"
cat > /etc/keepalived/keepalived.conf << EOF
! /etc/keepalived/keepalived.conf
! Configuration File for keepalived
global_defs {
  router_id LVS_DEVEL
  vrrp_skip_check_adv_addr
  vrrp_garp_interval 1
  vrrp_gna_interval 1
  max_auto_priority 90
}

vrrp_script check_haproxy_vip {
  script "/etc/keepalived/check-api-server.sh"
  interval 1
  weight -10
  fall 3
  rise 3
}

vrrp_instance haproxy-vip {
  {{- if eq (get "hosts.0.hostname") (get "host.hostname") }}
  state MASTER
  priority 101
  {{- else }}
  state BACKUP
  priority 100
  {{- end }}
  interface ${NET_IF}
  virtual_router_id 51
  advert_int 1
  authentication {
    auth_type PASS
    auth_pass 1111
  }
  unicast_src_ip {{ get "host.internal" }}
  unicast_peer {
    {{- range (get "hosts") }}
    {{- if eq .hostname (get "host.hostname") }}{{- else }}
    {{ .internal }}
    {{- end }}
    {{- end }}
  }
  virtual_ipaddress {
    {{ get "config.virtual_ip" }}
  }
  track_script {
    check_haproxy_vip
  }
}
EOF

echo "写入检测脚本 >> /etc/keepalived/check-api-server.sh"
cat >/etc/keepalived/check-api-server.sh<<EOF
#!/bin/sh
curl -sfk --max-time 3 https://localhost:{{ get "config.frontend" }}/healthz -o /dev/null
EOF

chmod +x /etc/keepalived/check-api-server.sh