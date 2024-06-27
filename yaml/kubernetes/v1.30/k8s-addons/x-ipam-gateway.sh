#!/usr/bin/env bash

set -e

{{- if get "config.ipam-gateway.enable" }}{{- else }}
exit 0
{{- end }}

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ipam-gateway

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ipam-gateway-sa
  namespace: ipam-gateway

---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: ipam-gateway
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
  - nonResourceURLs: ["*"]
    verbs: ["*"]

---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: ipam-gateway
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ipam-gateway
subjects:
  - kind: ServiceAccount
    name: ipam-gateway-sa
    namespace: ipam-gateway

---
apiVersion: v1
kind: Secret
metadata:
  name: secret-harbor
  namespace: ipam-gateway
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: eyJhdXRocyI6eyJyZWcuZHFjcGNpZGMuY246ODQ0MyI6eyJ1c2VybmFtZSI6ImRxYWRtaW4iLCJwYXNzd29yZCI6ImVlNGdGejROcG01bU5ZWiJ9fX0K

---
apiVersion: "cilium.io/v2alpha1"
kind: CiliumLoadBalancerIPPool
metadata:
  name: "ipam-svc"
spec:
  blocks:
    - cidr: "20.10.0.0/16"
  serviceSelector:
    matchLabels:
      "kubernetes.io/service-ipam": "cilium.io"

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ipam-svc-nginx-conf
  namespace: ipam-gateway
data:
  nginx.conf: |
    # see https://www.nginx.com/resources/wiki/start/topics/examples/full/
    user  nginx;
    worker_processes  auto;

    error_log  /var/log/nginx/error.log notice;
    pid        /var/run/nginx.pid;

    events {
        worker_connections  4096;
    }

    http {
        include       /etc/nginx/mime.types;
        default_type  application/octet-stream;
        log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                          '$status $body_bytes_sent "$http_referer" '
                          '"$http_user_agent" "$http_x_forwarded_for"';
        access_log  /var/log/nginx/access.log  main;
        sendfile        on;
        #tcp_nopush     on;
        keepalive_timeout  65;
        #gzip  on;

        include /etc/nginx/conf.d/http/*.conf;
    }

    stream {
        include /etc/nginx/conf.d/stream/*.conf;
    }

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: ipam-gateway
  namespace: ipam-gateway
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ipam-gateway
  template:
    metadata:
      name: ipam-gateway
      namespace: ipam-gateway
      labels:
        app: ipam-gateway
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: ipam-gateway
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: kubernetes.io/hostname
                    operator: In
                    values:
                      - <node-hostname>
      hostNetwork: true
      shareProcessNamespace: true
      serviceAccountName: ipam-gateway-sa
      imagePullSecrets:
        - name: secret-harbor
      containers:
        - image: reg.dqcpcidc.cn:8443/docker.io/nginx:1.27-alpine
          name: ipam-svc-nginx
          imagePullPolicy: IfNotPresent
          resources:
            requests:
              cpu: "200m"
              memory: "500Mi"
            limits:
              cpu: "500m"
              memory: "1Gi"
          volumeMounts:
            - name: nginx-conf
              mountPath: /etc/nginx/nginx.conf
              subPath: nginx.conf
              readOnly: true
            - name: nginx-http-conf-dir
              mountPath: /etc/nginx/conf.d/http
            - name: nginx-stream-conf-dir
              mountPath: /etc/nginx/conf.d/stream
        - image: reg.dqcpcidc.cn:8443/ipam-gateway/ipam-svc-controller:20240529.6
          name: ipam-svc-controller
          imagePullPolicy: IfNotPresent
          resources:
            requests:
              cpu: "200m"
              memory: "100Mi"
            limits:
              cpu: "500m"
              memory: "200Mi"
          volumeMounts:
            - name: nginx-http-conf-dir
              mountPath: /etc/nginx/conf.d/http
            - name: nginx-stream-conf-dir
              mountPath: /etc/nginx/conf.d/stream
      volumes:
        - name: nginx-conf
          configMap:
            name: ipam-svc-nginx-conf
        - name: nginx-http-conf-dir
          hostPath:
            path: /etc/nginx/conf.d/http
        - name: nginx-stream-conf-dir
          hostPath:
            path: /etc/nginx/conf.d/stream
EOF