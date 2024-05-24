#!/usr/bin/env bash

set -e

{{- if eq (get "config.k8s.control_plane_endpoint.balancer") "haproxy" }}

mkdir -p /etc/haproxy
mkdir -p /etc/keepalived

NET_IF=$(ip route | grep ' {{ get "host.address" }} ' | grep 'proto kernel scope link src' | sed -e 's/^.*dev.//' -e 's/.proto.*//' | uniq)
if [ "${NET_IF}" == "" ]; then
  NET_IF=$(ip route | grep ' {{ get "host.internal" }} ' | grep 'proto kernel scope link src' | sed -e 's/^.*dev.//' -e 's/.proto.*//' | uniq)
fi

if [ "${NET_IF}" == "" ]; then
  echo "获取主机网卡名失败"
  exit 1
fi

echo "写入Haproxy配置文件"
cat > /etc/haproxy/haproxy.cfg << EOF
# /etc/haproxy/haproxy.cfg
#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
  log           127.0.0.1 local0
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
  bind  *:{{ get "config.k8s.control_plane_endpoint.port" }}
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
  {{- range (get "hosts") }}
  server {{ .hostname }} {{ .internal }}:6443 check inter 3s weight 100 fall 3 rise 3
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

echo "写入Keepalived配置文件"
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
    {{ get "config.k8s.control_plane_endpoint.address" }}/24
  }
  track_script {
    check_haproxy_vip
  }
}
EOF

# 写入Keepalived检测脚本
echo "写入Keepalived检测脚本"
cat >/etc/keepalived/check-api-server.sh<<EOF
#!/bin/sh
curl -sfk --max-time 3 https://localhost:{{ get "config.k8s.control_plane_endpoint.port" }}/healthz -o /dev/null
EOF

chmod +x /etc/keepalived/check-api-server.sh

# see https://github.com/kubernetes/kubeadm/blob/main/docs/ha-considerations.md#options-for-software-load-balancing
echo "创建Haproxy静态Pod部署清单"
cat > /etc/kubernetes/manifests/haproxy.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: haproxy
  namespace: kube-system
  creationTimestamp: null
spec:
  hostNetwork: true
  containers:
  - image: registry.cn-chengdu.aliyuncs.com/silva-cheung/haproxy:2.9
    name: haproxy
    resources: {}
    livenessProbe:
      failureThreshold: 5
      httpGet:
        scheme: HTTPS
        host: localhost
        port: {{ get "config.k8s.control_plane_endpoint.port" }}
        path: /healthz
    volumeMounts:
    - name: haproxy-config
      mountPath: /usr/local/etc/haproxy/haproxy.cfg
      readOnly: true
  volumes:
  - name: haproxy-config
    hostPath:
      path: /etc/haproxy/haproxy.cfg
      type: FileOrCreate
EOF

# see https://github.com/kubernetes/kubeadm/blob/main/docs/ha-considerations.md#options-for-software-load-balancing
echo "创建Keepalived静态Pod部署清单"
cat > /etc/kubernetes/manifests/keepalived.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: keepalived
  namespace: kube-system
  creationTimestamp: null
spec:
  hostNetwork: true
  containers:
  - image: registry.cn-chengdu.aliyuncs.com/silva-cheung/keepalived:2.0.20
    name: keepalived
    resources: {}
    securityContext:
      capabilities:
        add:
        - NET_ADMIN
        - NET_BROADCAST
        - NET_RAW
    volumeMounts:
    - name: keepalived-config
      mountPath: /usr/local/etc/keepalived/keepalived.conf
    - name: keepalived-check
      mountPath: /etc/keepalived/check-api-server.sh
  volumes:
  - name: keepalived-config
    hostPath:
      path: /etc/keepalived/keepalived.conf
  - name: keepalived-check
    hostPath:
      path: /etc/keepalived/check-api-server.sh
EOF
{{- end }}