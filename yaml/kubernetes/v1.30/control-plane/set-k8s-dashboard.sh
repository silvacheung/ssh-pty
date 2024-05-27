#!/usr/bin/env bash

set -e

# 安装dashboard
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
  --create-namespace \
  --namespace kubernetes-dashboard

# 创建dashboard用户
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dashboard-admin-user
  namespace: kubernetes-dashboard

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: dashboard-admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: dashboard-admin-user
    namespace: kubernetes-dashboard

---
apiVersion: v1
kind: Secret
metadata:
  name: dashboard-admin-user
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: "dashboard-admin-user"
type: kubernetes.io/service-account-token
EOF

# 删除dashboard代理服务
kubectl delete -n kubernetes-dashboard service/kubernetes-dashboard-kong-proxy
kubectl delete -n kubernetes-dashboard service/kubernetes-dashboard-kong-manager

# 创建dashboard代理服务
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  labels:
    kubernetes.io/service-ipam: cilium.io
  name: kubernetes-dashboard-kong-proxy
  namespace: kubernetes-dashboard
spec:
  allocateLoadBalancerNodePorts: false
  externalTrafficPolicy: Local
  healthCheckNodePort: 30276
  internalTrafficPolicy: Cluster
  ports:
    - name: kong-proxy-tls
      port: 8443
      protocol: TCP
      targetPort: 8443
  selector:
    app.kubernetes.io/component: app
    app.kubernetes.io/instance: kubernetes-dashboard
    app.kubernetes.io/name: kong
  sessionAffinity: None
  type: LoadBalancer
EOF