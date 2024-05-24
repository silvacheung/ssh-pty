#!/usr/bin/env bash

set -e

{{- if eq (get "config.k8s.control_plane_endpoint.balancer") "kube-vip" }}

NET_IF=$(ip route | grep ' {{ get "host.address" }} ' | grep 'proto kernel scope link src' | sed -e 's/^.*dev.//' -e 's/.proto.*//' | uniq)
if [ "${NET_IF}" == "" ]; then
  NET_IF=$(ip route | grep ' {{ get "host.internal" }} ' | grep 'proto kernel scope link src' | sed -e 's/^.*dev.//' -e 's/.proto.*//' | uniq)
fi

if [ "${NET_IF}" == "" ]; then
  echo "获取主机网卡名失败"
  exit 1
fi

# see https://github.com/kubernetes/kubeadm/blob/main/docs/ha-considerations.md#options-for-software-load-balancing
# gen: docker run --network host --rm ghcr.io/kube-vip/kube-vip:v0.8.0 manifest pod --interface enp3s0 --address 172.16.67.204 --controlplane --services --arp --leaderElection --enableLoadBalancer
echo "创建kube-vip静态Pod部署清单"
cat > /etc/kubernetes/manifests/kube-vip.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  name: kube-vip
  namespace: kube-system
spec:
  containers:
  - args:
    - manager
    env:
    - name: vip_arp
      value: "true"
    - name: port
      value: "6443"
    - name: vip_nodename
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
    - name: vip_interface
      value: ${NET_IF}
    - name: vip_cidr
      value: "24"
    - name: dns_mode
      value: first
    - name: vip_ddns
      value: "false"
    - name: cp_enable
      value: "true"
    - name: cp_namespace
      value: kube-system
    - name: svc_enable
      value: "true"
    - name: svc_leasename
      value: plndr-svcs-lock
    - name: vip_leaderelection
      value: "true"
    - name: vip_leasename
      value: plndr-cp-lock
    - name: vip_leaseduration
      value: "5"
    - name: vip_renewdeadline
      value: "3"
    - name: vip_retryperiod
      value: "1"
    - name: lb_enable
      value: "true"
    - name: lb_port
      value: "{{ get "config.k8s.control_plane_endpoint.port" }}"
    - name: lb_fwdmethod
      value: local
    - name: address
      value: {{ get "config.k8s.control_plane_endpoint.address" }}
    - name: prometheus_server
      value: :2112
    #image: ghcr.io/kube-vip/kube-vip:v0.8.0
    image: registry.cn-chengdu.aliyuncs.com/silva-cheung/kube-vip:v0.8.0
    imagePullPolicy: IfNotPresent
    name: kube-vip
    resources: {}
    securityContext:
      capabilities:
        add:
        - NET_ADMIN
        - NET_RAW
        - SYS_TIME
    volumeMounts:
    - mountPath: /etc/kubernetes/admin.conf
      name: kube-config
  hostAliases:
  - hostnames:
    - kubernetes
    ip: 127.0.0.1
  hostNetwork: true
  volumes:
  - hostPath:
      path: /etc/kubernetes/admin.conf
    name: kube-config
status: {}
EOF
{{- end }}