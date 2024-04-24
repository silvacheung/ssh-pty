#!/usr/bin/env bash
set -e

# 本机/控制面板/工作节点
{{- $host := .Host }}
{{- $cps := .Configs.K8s.ControlPlanes }}
{{- $wns:= .Configs.K8s.WorkerNodes }}

# 控制面板
{{- range $idx, $master := $cps }}
{{- if eq $host.Hostname $master }}
{{- if eq $idx 0 }}
kubeadm init --upload-certs --config /etc/kubernetes/kubeadm-config.yaml
{{- else }}
kubeadm join --config /etc/kubernetes/kubeadm-config.yaml
{{- end }}
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
{{- end }}
{{- end }}

# 工作节点
{{- range $idx, $worker := $wns }}
  {{- if eq $host.Hostname $worker }}
    {{- $isMaster := false }}
    {{- range $master := $cps }}
      {{- if eq $host.Hostname $master }}
      {{- $isMaster = true }}
      {{- end }}
    {{- end }}
    {{- if $isMaster }}
kubectl taint nodes {{ $host.Hostname }} node-role.kubernetes.io/control-plane=:NoSchedule-
kubectl label --overwrite node {{ $host.Hostname }} node-role.kubernetes.io/worker-node=
    {{- else }}
kubeadm join --config /etc/kubernetes/kubeadm-config.yaml
#kubectl taint nodes {{ $host.Hostname }} node-role.kubernetes.io/control-plane=:NoSchedule-
#kubectl label --overwrite node {{ $host.Hostname }} node-role.kubernetes.io/worker-node=
    {{- end }}
  {{- end }}
{{- end }}
