#!/usr/bin/env bash

set -e

CLUSTER_NAME="{{ get "config.k8s.cluster_name" }}"
CLUSTER_ENDPOINT="{{ get "config.k8s.control_plane_endpoint.domain" }}:{{ get "config.k8s.control_plane_endpoint.port" }}"
K8S_USER="admin"
CONF_DIR="${HOME}/kubernetes"

mkdir -p ${CONF_DIR}

kubectl delete CertificateSigningRequest/kube-config-${K8S_USER} > /dev/null 2>&1 || true
kubectl delete ClusterRoleBinding/kube-config-${K8S_USER} > /dev/null 2>&1 || true
kubectl delete ClusterRole/kube-config-${K8S_USER} > /dev/null 2>&1 || true

# (1)创建私钥
openssl genrsa -out ${CONF_DIR}/${K8S_USER}.key 2048
openssl req -new -key ${CONF_DIR}/${K8S_USER}.key -out ${CONF_DIR}/${K8S_USER}.csr -subj "/CN=${K8S_USER}"

# (2)创建证书签名请求
kubectl apply -f - <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: kube-config-${K8S_USER}
spec:
  request: $(cat ${CONF_DIR}/${K8S_USER}.csr | base64 | tr -d "\n")
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 864000000  # 10000 day
  usages:
  - client auth
EOF

# (3)批准证书签名请求
kubectl certificate approve kube-config-${K8S_USER}

# (4)获取证书
kubectl get csr/kube-config-${K8S_USER} -o jsonpath='{.status.certificate}'| base64 -d > ${CONF_DIR}/${K8S_USER}.crt

# (5)创建角色和角色绑定
kubectl apply -f - <<EOF
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kube-config-${K8S_USER}
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
- nonResourceURLs: ["*"]
  verbs: ["*"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kube-config-${K8S_USER}
subjects:
- kind: User
  name: ${K8S_USER}
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: kube-config-${K8S_USER}
  apiGroup: rbac.authorization.k8s.io
EOF

# (6)创建kube.config
cat >${CONF_DIR}/${K8S_USER}.config<<EOF
apiVersion: v1
kind: Config
preferences: {}

clusters:
  - cluster:
    name: ${CLUSTER_NAME}

users:
  - name: ${K8S_USER}

contexts:
  - context:
    name: kubernetes-${K8S_USER}
EOF

# (7)将集群详细信息添加到配置文件中
kubectl config --kubeconfig=${CONF_DIR}/${K8S_USER}.config set-cluster ${CLUSTER_NAME} --server=https://${CLUSTER_ENDPOINT} --certificate-authority=/etc/kubernetes/pki/ca.crt --embed-certs
kubectl config --kubeconfig=${CONF_DIR}/${K8S_USER}.config set-credentials ${K8S_USER} --client-certificate=${CONF_DIR}/${K8S_USER}.crt --client-key=${CONF_DIR}/${K8S_USER}.key --embed-certs=true
kubectl config --kubeconfig=${CONF_DIR}/${K8S_USER}.config set-context kubernetes-${K8S_USER} --cluster=${CLUSTER_NAME} --namespace=default --user=${K8S_USER}
kubectl config --kubeconfig=${CONF_DIR}/${K8S_USER}.config use-context kubernetes-${K8S_USER}