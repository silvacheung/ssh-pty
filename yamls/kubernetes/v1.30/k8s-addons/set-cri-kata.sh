#!/usr/bin/env bash
set -e

KATA_RABC_YAML=~/k8s-addons/kata/kata-rbac.yaml
KATA_DEPLOY_YAML=~/k8s-addons/kata/kata-deploy.yaml
KATA_RT_CLASS_YAML=~/k8s-addons/kata/kata-runtime-classes.yaml

mkdir -p ~/k8s-addons/kata

# see https://github.com/kata-containers/kata-containers/blob/main/tools/packaging/kata-deploy/README.md
# kubectl apply -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/kata-rbac/base/kata-rbac.yaml
cat >${KATA_RABC_YAML}<<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kata-deploy-sa
  namespace: kube-system
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: kata-deploy-role
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "patch"]
- apiGroups: ["node.k8s.io"]
  resources: ["runtimeclasses"]
  verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: kata-deploy-rb
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kata-deploy-role
subjects:
- kind: ServiceAccount
  name: kata-deploy-sa
  namespace: kube-system
EOF

# 这个地址在文件中没有,需要去将kata-deploy-stable.yaml改为kata-deploy.yaml
# kubectl apply -f https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/kata-deploy/base/kata-deploy-stable.yaml
cat >${KATA_DEPLOY_YAML}<<EOF
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kata-deploy
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: kata-deploy
  template:
    metadata:
      labels:
        name: kata-deploy
    spec:
      serviceAccountName: kata-deploy-sa
      hostPID: true
      containers:
        - name: kube-kata
          image: quay.io/kata-containers/kata-deploy:latest
          imagePullPolicy: Always
          lifecycle:
            preStop:
              exec:
                command: ["bash", "-c", "/opt/kata-artifacts/scripts/kata-deploy.sh cleanup"]
          command: ["bash", "-c", "/opt/kata-artifacts/scripts/kata-deploy.sh install"]
          env:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: DEBUG
              value: "false"
            - name: SHIMS
              value: "clh cloud-hypervisor dragonball fc qemu qemu-nvidia-gpu qemu-sev qemu-snp qemu-tdx stratovirt"
            - name: DEFAULT_SHIM
              value: "qemu"
            - name: CREATE_RUNTIMECLASSES
              value: "false"
            - name: CREATE_DEFAULT_RUNTIMECLASS
              value: "false"
            - name: ALLOWED_HYPERVISOR_ANNOTATIONS
              value: ""
            - name: SNAPSHOTTER_HANDLER_MAPPING
              value: ""
            - name: AGENT_HTTPS_PROXY
              value: ""
            - name: AGENT_NO_PROXY
              value: ""
          securityContext:
            privileged: true
          volumeMounts:
            - name: crio-conf
              mountPath: /etc/crio/
            - name: containerd-conf
              mountPath: /etc/containerd/
            - name: kata-artifacts
              mountPath: /opt/kata/
            - name: local-bin
              mountPath: /usr/local/bin/
      volumes:
        - name: crio-conf
          hostPath:
            path: /etc/crio/
        - name: containerd-conf
          hostPath:
            path: /etc/containerd/
        - name: kata-artifacts
          hostPath:
            path: /opt/kata/
            type: DirectoryOrCreate
        - name: local-bin
          hostPath:
            path: /usr/local/bin/
  updateStrategy:
    rollingUpdate:
      maxUnavailable: 1
    type: RollingUpdate
EOF

# kata RuntimeClass 资源创建参考
cat >${KATA_RT_CLASS_YAML}<<EOF
---
kind: RuntimeClass
apiVersion: node.k8s.io/v1
metadata:
  name: kata-clh
handler: kata-clh
overhead:
  podFixed:
    memory: "130Mi"
    cpu: "250m"
scheduling:
  nodeSelector:
    katacontainers.io/kata-runtime: "true"
---
kind: RuntimeClass
apiVersion: node.k8s.io/v1
metadata:
  name: kata-cloud-hypervisor
handler: kata-cloud-hypervisor
overhead:
  podFixed:
    memory: "130Mi"
    cpu: "250m"
scheduling:
  nodeSelector:
    katacontainers.io/kata-runtime: "true"
---
kind: RuntimeClass
apiVersion: node.k8s.io/v1
metadata:
  name: kata-dragonball
handler: kata-dragonball
overhead:
  podFixed:
    memory: "130Mi"
    cpu: "250m"
scheduling:
  nodeSelector:
    katacontainers.io/kata-runtime: "true"
---
kind: RuntimeClass
apiVersion: node.k8s.io/v1
metadata:
  name: kata-fc
handler: kata-fc
overhead:
  podFixed:
    memory: "130Mi"
    cpu: "250m"
scheduling:
  nodeSelector:
    katacontainers.io/kata-runtime: "true"
---
kind: RuntimeClass
apiVersion: node.k8s.io/v1
metadata:
  name: kata-qemu-nvidia-gpu
handler: kata-qemu-nvidia-gpu
overhead:
  podFixed:
    memory: "160Mi"
    cpu: "250m"
scheduling:
  nodeSelector:
    katacontainers.io/kata-runtime: "true"
---
kind: RuntimeClass
apiVersion: node.k8s.io/v1
metadata:
  name: kata-qemu-se
handler: kata-qemu-se
overhead:
  podFixed:
    memory: "2048Mi"
    cpu: "1.0"
scheduling:
  nodeSelector:
    katacontainers.io/kata-runtime: "true"
---
kind: RuntimeClass
apiVersion: node.k8s.io/v1
metadata:
  name: kata-qemu-sev
handler: kata-qemu-sev
overhead:
  podFixed:
    memory: "2048Mi"
    cpu: "1.0"
scheduling:
  nodeSelector:
    katacontainers.io/kata-runtime: "true"
---
kind: RuntimeClass
apiVersion: node.k8s.io/v1
metadata:
  name: kata-qemu-snp
handler: kata-qemu-snp
overhead:
  podFixed:
    memory: "2048Mi"
    cpu: "1.0"
scheduling:
  nodeSelector:
    katacontainers.io/kata-runtime: "true"
---
kind: RuntimeClass
apiVersion: node.k8s.io/v1
metadata:
  name: kata-qemu-tdx
handler: kata-qemu-tdx
overhead:
  podFixed:
    memory: "2048Mi"
    cpu: "1.0"
scheduling:
  nodeSelector:
    katacontainers.io/kata-runtime: "true"
---
kind: RuntimeClass
apiVersion: node.k8s.io/v1
metadata:
  name: kata-qemu
handler: kata-qemu
overhead:
  podFixed:
    memory: "160Mi"
    cpu: "250m"
scheduling:
  nodeSelector:
    katacontainers.io/kata-runtime: "true"
---
kind: RuntimeClass
apiVersion: node.k8s.io/v1
metadata:
  name: kata-remote
handler: kata-remote
overhead:
  podFixed:
    memory: "120Mi"
    cpu: "250m"
scheduling:
  nodeSelector:
    katacontainers.io/kata-runtime: "true"
---
kind: RuntimeClass
apiVersion: node.k8s.io/v1
metadata:
  name: kata-stratovirt
handler: kata-stratovirt
overhead:
  podFixed:
    memory: "130Mi"
    cpu: "250m"
scheduling:
  nodeSelector:
    katacontainers.io/kata-runtime: "true"
EOF

#开始部署
kubectl apply -f ${KATA_RABC_YAML}
kubectl apply -f ${KATA_DEPLOY_YAML}
kubectl -n kube-system wait --timeout=10m --for=condition=Ready -l name=kata-deploy pod
