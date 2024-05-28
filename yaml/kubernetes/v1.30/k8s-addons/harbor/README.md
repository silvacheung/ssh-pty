# 部署Harbor仓库,[参考](https://github.com/goharbor/harbor-helm)

- (1)生成harbor的自签名证书,[参考](https://goharbor.io/docs/2.10.0/install-config/configure-https/)
```shell
D_NAME="harbor-registry"
DOMAIN="${D_NAME}.com"

openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -sha512 -days 3650 \
 -subj "/C=CN/ST=China/L=China/O=Harbor/OU=Personal/CN=${DOMAIN}" \
 -key ca.key \
 -out ca.crt
 
openssl genrsa -out yourdomain.com.key 4096
openssl req -sha512 -new \
    -subj "/C=CN/ST=China/L=China/O=Harbor/OU=Personal/CN=${DOMAIN}" \
    -key ${DOMAIN}.key \
    -out ${DOMAIN}.csr

cat > v3.ext <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1=${DOMAIN}
DNS.2=${D_NAME}
EOF

openssl x509 -req -sha512 -days 3650 \
    -extfile v3.ext \
    -CA ca.crt -CAkey ca.key -CAcreateserial \
    -in ${DOMAIN}.csr \
    -out ${DOMAIN}.crt

openssl x509 -inform PEM -in ${DOMAIN}.crt -out ${DOMAIN}.cert
```

- (2)部署harbor的secret
```shell
apiVersion: v1
kind: Secret
metadata:
  name: harbor-tls
  namespace: default
type: Opaque
data:
  ca.crt: $(cat ca.crt | base64 -w 0)
  tls.crt: $(cat ${DOMAIN}.crt | base64 -w 0)
  tls.key: $(cat ${DOMAIN}.key | base64 -w 0)
```

- (3)部署harbor的storageClass
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

- (4)部署harbor的PV
```shell
mkdir -p /mnt/harbor-registry
mkdir -p /mnt/harbor-jobservice
mkdir -p /mnt/harbor-database
mkdir -p /mnt/harbor-redis
mkdir -p /mnt/harbor-trivy
```

```yaml
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: harbor-registry
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /mnt/harbor-registry
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - xxx

---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: harbor-jobservice
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /mnt/harbor-jobservice
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - xxx

---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: harbor-database
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /mnt/harbor-database
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - xxx

---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: harbor-redis
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /mnt/harbor-redis
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - xxx

---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: harbor-trivy
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /mnt/harbor-trivy
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - xxx

```

- (5)配置harbor的[values.yaml](values.yaml)
- (6)部署harbor
```shell
helm repo add harbor https://helm.goharbor.io
helm install harbor-registry harbor/harbor -f values.yaml
```