#!/usr/bin/env bash

set -e

mkdir -p /etc/containerd

# default config gen cmd: `containerd config default > config.toml`
echo "写入配置文件 >> /etc/containerd/config.toml"
cat > /etc/containerd/config.toml <<EOF
version = 2
root = "/var/lib/containerd"
state = "/run/containerd"
[grpc]
  address = "/run/containerd/containerd.sock"
  uid = 0
  gid = 0
  max_recv_message_size = 16777216
  max_send_message_size = 16777216

[ttrpc]
  address = ""
  uid = 0
  gid = 0

[debug]
  address = ""
  uid = 0
  gid = 0
  level = ""

[metrics]
  address = ""
  grpc_histogram = false

[cgroup]
  path = ""

[timeouts]
  "io.containerd.timeout.shim.cleanup" = "5s"
  "io.containerd.timeout.shim.load" = "5s"
  "io.containerd.timeout.shim.shutdown" = "3s"
  "io.containerd.timeout.task.state" = "3s"

[plugins]
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
    runtime_type = "io.containerd.runc.v2"
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
      SystemdCgroup = true
  [plugins."io.containerd.grpc.v1.cri"]
    {{- if get "config.containerd.sand_box_image" }}
    sandbox_image = "{{ get "config.containerd.sand_box_image" }}"
    {{- else }}
    sandbox_image = "registry.k8s.io/pause:3.9"
    {{- end }}
    [plugins."io.containerd.grpc.v1.cri".cni]
      bin_dir = "/opt/cni/bin"
      conf_dir = "/etc/cni/net.d"
      max_conf_num = 1
      conf_template = ""
    [plugins."io.containerd.grpc.v1.cri".registry]
      config_path = "/etc/containerd/certs.d"

      {{- range $namespace, $auth := (get "config.containerd.auths") }}
      [plugins."io.containerd.grpc.v1.cri".registry.configs."{{ $namespace }}".auth]
        username = "{{- if $auth.username }}{{ $auth.username }}{{- end }}"
        password = "{{- if $auth.password }}{{ $auth.password }}{{- end }}"
        auth = "{{- if $auth.auth }}{{ $auth.auth }}{{- end }}"
        identitytoken = "{{- if $auth.identity_token }}{{ $auth.identity_token }}{{- end }}"
      {{- end }}
EOF

echo "写入配置文件 >> /etc/containerd/certs.d/..."
{{- range $namespace, $registry := (get "config.containerd.certs_d") }}
mkdir -p /etc/containerd/certs.d/{{ $namespace }}
cat > /etc/containerd/certs.d/{{ $namespace }}/hosts.toml <<EOF
{{- if $registry.server }}
server = "{{ $registry.server }}"
{{- end }}
{{- range $registry.mirror }}
[host."{{ .address }}"]
  {{- if .capabilities }}
  capabilities = [{{- range $idx, $val := .capabilities }}{{- if eq $idx 0 }}"{{ $val }}"{{- else }}, "{{ $val }}"{{- end }}{{- end }}]
  {{- else }}
  capabilities = ["pull", "push", "resolve"]
  {{- end }}
  {{- if .override_path }}
  override_path = {{ .override_path }}
  {{- else }}
  override_path = false
  {{- end }}
  {{- if .skip_tls_verify }}
  skip_verify = {{ .skip_tls_verify }}
  {{- else }}
  skip_verify = false
  {{- end }}
  {{- if .ca_file }}
  ca = ["{{ .ca_file }}"]
  {{- end }}
  {{- if or .cert_file .key_file }}
  client = [["{{- if .cert_file }}{{ .cert_file }}{{- end }}", "{{- if .key_file }}{{ .key_file }}{{- end }}"]]
  {{- end }}
{{- end }}
{{- range $key, $values := $registry.header }}
[host."{{ $key }}".header]
  {{- range $values }}
  {{ . }}
  {{- end }}
{{- end }}
EOF
{{ end }}