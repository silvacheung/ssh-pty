#!/usr/bin/env bash
set -e

HA_PORT="{{ .Configs.LB.Frontend.Bind }}"
HA_PORT="${HA_PORT##*:}"

mkdir -p /etc/haproxy
mkdir -p /etc/keepalived

# 写入Haproxy配置文件
echo "写入Haproxy配置文件"
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
# kube-apiserver frontend which proxys to the control plane nodes
#---------------------------------------------------------------------
frontend f-kube-api-server
  bind  {{ .Configs.LB.Frontend.Bind }} #*:8080
  mode  tcp
  option  tcplog
  default_backend b-kube-api-server

#---------------------------------------------------------------------
# round robin balancing for kube-apiserver
#---------------------------------------------------------------------
backend b-kube-api-server
  option  httpchk GET /healthz
  http-check  expect  status 200
  mode  tcp
  option  ssl-hello-chk
  balance leastconn #roundrobin
  {{- $backends := .Configs.LB.Backend }}
  {{- $cpePort:= .Configs.K8s.ControlPlaneEndpoint.Port }}
  {{- range $host := .Hosts }}
  {{- range $backend := $backends }}
  {{- if eq $host.Hostname $backend }}
  server {{ $host.Hostname }} {{ $host.Address }}:{{ if gt (len $cpePort) 0 }}{{ $cpePort }}{{ else }}6443{{ end }} check
  {{- end }}
  {{- end }}
  {{- end }}

#---------------------------------------------------------------------
# haproxy stats dashboard
#---------------------------------------------------------------------
frontend stats
  mode http
  bind {{ .Configs.LB.StatsUI.Bind }} #*：8080
  stats enable
  stats auth {{ .Configs.LB.StatsUI.Auth }} #admin:123456
  stats refresh 10s
  stats realm "Welcome to the haproxy load balancer status page"
  stats uri /stats
EOF

# 写入Keepalived配置文件
echo "写入Keepalived配置文件"
cat > /etc/keepalived/keepalived.conf << EOF
! /etc/keepalived/keepalived.conf
! Configuration File for keepalived
global_defs {
  notification_email {
  }
  router_id LVS_DEVEL
  vrrp_skip_check_adv_addr
  vrrp_garp_interval 1
  vrrp_gna_interval 1
  max_auto_priority 90
}

vrrp_script check_haproxy_vip {
  script "/etc/keepalived/check-apiserver.sh"
  interval 3
  weight -2
  fall 10
  rise 2
}

vrrp_instance haproxy-vip {
  state {{ if eq .Host.Hostname .Configs.LB.Master }}MASTER{{ else }}BACKUP{{ end }}
  interface {{ .Host.NetIF }}
  virtual_router_id 51
  priority {{ if eq .Host.Hostname .Configs.LB.Master }}101{{ else }}100{{ end }}
  advert_int 1
  authentication {
    auth_type PASS
    auth_pass 1111
  }
  unicast_src_ip {{ .Host.Internal }}
  unicast_peer {
    {{- $this := .Host }}
    {{- $master := .Configs.LB.Master }}
    {{- $backups := .Configs.LB.Backup }}
    {{- range $host := .Hosts }}
    {{- if eq $host.Hostname $master }}
    {{- if eq $host.Hostname $this.Hostname}}{{- else }}
    {{ $host.Internal }}
    {{- end }}
    {{- end }}
    {{- range $backup := $backups }}
    {{- if eq $host.Hostname $backup }}
    {{- if eq $host.Hostname $this.Hostname}}{{- else }}
    {{ $host.Internal }}
    {{- end }}
    {{- end }}
    {{- end }}
    {{- end }}
  }
  virtual_ipaddress {
    {{ .Configs.LB.VirtualIP }}
  }
  track_script {
    check_haproxy_vip
  }
}
EOF

# 写入Keepalived检测脚本
echo "写入Keepalived检测脚本"
cat >/etc/keepalived/check-apiserver.sh<<EOF
#!/bin/sh

errorExit() {
    echo "*** $*" 1>&2
    exit 1
}

curl --silent --max-time 2 --insecure https://localhost:6443/ -o /dev/null || errorExit "Error GET https://localhost:6443/"
if ip addr | grep -q {{ .Configs.LB.VirtualIP }}; then
    curl --silent --max-time 2 --insecure https://{{ .Configs.LB.VirtualIP }}:${HA_PORT}/ -o /dev/null || errorExit "Error GET https://{{ .Configs.LB.VirtualIP }}:${HA_PORT}/"
fi
EOF

chmod +x /etc/keepalived/check-apiserver.sh