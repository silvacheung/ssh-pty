#!/usr/bin/env bash
set -e

# K8S_CP_ENDPOINT="{{ .Configs.K8s.ControlPlaneEndpoint }}"
# K8S_CP_ENDPOINT_PORT="${K8S_CP_ENDPOINT##*:}"

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
	log			      127.0.0.1 local0
	chroot			  /var/lib/haproxy
	pidfile			  /var/run/haproxy.pid
	stats socket  /var/lib/haproxy/stats
	maxconn			  4000
	daemon

#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
	mode                    http
	log                     global
	option                  httplog
	option			            dontlognull
	option                  http-server-close
	option	    forwardfor 	except 127.0.0.0/8
	option			redispatch
	retries                 3
	timeout	http-request    10s
	timeout queue           20s
	timeout connect         5s
	timeout client          20s
	timeout server          20s
	timeout http-keep-alive 10s
	timeout check           10s
	maxconn			            4000

#---------------------------------------------------------------------
# kube-apiserver frontend which proxys to the control plane nodes
#---------------------------------------------------------------------
frontend kube-apiserver
    bind *:9443
    mode tcp
    option tcplog
    default_backend kube-apiserver

#---------------------------------------------------------------------
# round robin balancing for kube-apiserver
#---------------------------------------------------------------------
backend kube-apiserver
    option httpchk GET /healthz
    http-check expect status 200
    mode tcp
    option ssl-hello-chk
    # balance     roundrobin
    balance     leastconn
    {{- $cps := .Configs.K8s.ControlPlanes }}
    {{- range $host := .Hosts }}
    {{- range $hostname := $cps }}
    {{- if eq $host.Hostname $hostname }}
    server {{ $host.Hostname }} {{ $host.Address }}:6443 check
    {{- end }}
    {{- end }}
    {{- end }}

#---------------------------------------------------------------------
# haproxy stats dashboard
#---------------------------------------------------------------------
frontend stats
	mode http
	bind *:{{.HaproxyStatsPort}}
	stats enable
	stats auth admin:123456
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
	vrrp_garp_interval 0
	vrrp_gna_interval 0
}

vrrp_script check_haproxy_vip {
	! script "</dev/tcp/127.0.0.1/9443"
	script "/etc/keepalived/check-apiserver.sh"
	interval 3
	weight -2
	fall 10
	rise 2
}

vrrp_instance haproxy-vip {
    state {{- if .Host.Hostname eq .LB.MASTER }}MASTER{{else}}BACKUP{{- end }}
    interface {{ .Host.NetIF }}
    virtual_router_id 51
    priority {{- if .Host.Hostname eq .LB.MASTER }}101{{else}}100{{- end }}
	  advert_int 1
    authentication {
      auth_type PASS
      auth_pass 1111
    }
    unicast_src_ip {{ .Host.Address }}
    unicast_peer {
      {{ $lbMaster := .LB.Master }}
      {{ $lbBackup := .LB.Backup }}
      {{- range $host := .Hosts }}
      {{- if $host.Hostname eq $lbMaster}}
      {{ $host.Address }}
      {{- end }}
      {{- range $backup := $lbBackup }}
      {{- if $host.Hostname eq $backup }}
      {{ $host.Address }}
      {{- end }}
      {{- end }}
      {{- end }}
    }
    virtual_ipaddress {
      {{ .LB.VirtualIP }}
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

curl --silent --max-time 2 --insecure https://localhost:${APISERVER_DEST_PORT}/ -o /dev/null || errorExit "Error GET https://localhost:${APISERVER_DEST_PORT}/"
if ip addr | grep -q ${APISERVER_VIP}; then
    curl --silent --max-time 2 --insecure https://${APISERVER_VIP}:${APISERVER_DEST_PORT}/ -o /dev/null || errorExit "Error GET https://${APISERVER_VIP}:${APISERVER_DEST_PORT}/"
fi
EOF