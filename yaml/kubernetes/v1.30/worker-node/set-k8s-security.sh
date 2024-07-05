#!/usr/bin/env bash

echo "增强K8S安全性 >> 设置集群目录权限"

# control plane
chmod 700 -f /var/lib/etcd
chown root:root -f /var/lib/etcd

chmod 644 -f /etc/kubernetes
chown root:root -f /etc/kubernetes

chmod 600 -f -R /etc/kubernetes/
chown root:root -f -R /etc/kubernetes/*

chmod 644 -f /etc/kubernetes/manifests
chown root:root -f /etc/kubernetes/manifests

chmod 644 -f /etc/kubernetes/pki
chown root:root -f /etc/kubernetes/pki

# worker node
chmod 600 -f -R /etc/cni/net.d
chown root:root -f -R /etc/cni/net.d

chmod 550 -f -R /usr/bin/kube*
chown root:root -f -R /usr/bin/kube*

chmod 550 -f /usr/local/bin/helm
chown root:root -f /usr/local/bin/helm

chmod 700 -f -R /opt/cni
chown root:root -f -R /opt/cni

chmod 640 -f /var/lib/kubelet/config.yaml
chown root:root -f /var/lib/kubelet/config.yaml

chmod 640 -f -R /usr/lib/systemd/system/kubelet.service*
chown root:root -f -R /usr/lib/systemd/system/kubelet.service*