# 使用令牌访问集群API，参考[访问集群](https://kubernetes.io/zh-cn/docs/tasks/access-application-cluster/access-cluster/)

## 步骤
- (1)创建 Secret,请求默认 ServiceAccount 的令牌
```shell
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: default-token
  annotations:
    kubernetes.io/service-account.name: default
type: kubernetes.io/service-account-token
EOF
```

- (2)获取Secret中的令牌
```shell
API_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
TOKEN=$(kubectl get secret default-token -o jsonpath='{.data.token}' | base64 --decode)
curl $API_SERVER/api --header "Authorization: Bearer $TOKEN" --insecure
```


# 使用创建的集群访问配置文件访问集群API

## 1 创建用户证书，参考[如何为用户颁发证书](https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/#normal-user)
- (1)创建私钥   
```shell
K8S_USER="my-user"
openssl genrsa -out ${K8S_USER}.key 2048
openssl req -new -key ${K8S_USER}.key -out ${K8S_USER}.csr -subj "/CN=${K8S_USER}"
```

- (2)创建证书签名请求    
```shell
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: kube-config-${K8S_USER}
spec:
  request: $(cat ${K8S_USER}.csr | base64 | tr -d "\n")
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400000  # 1000 day
  usages:
  - client auth
EOF
```

- (3)查看和批准证书签名请求
```shell
kubectl get csr
kubectl certificate approve kube-config-${K8S_USER}
```

- (4)获取证书
```shell
kubectl get csr/kube-config-${K8S_USER} -o yaml
```
或者
```shell
kubectl get csr/kube-config-${K8S_USER} -o jsonpath='{.status.certificate}'| base64 -d > ${K8S_USER}.crt
```

- (5)创建角色和角色绑定,参考[使用RBAC授权](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- 注意！对于不同的场景需要选用不同的Role(限定namespace)/ClusterRole(全局)和RoleBinding/ClusterRoleBinding的组合
```shell
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
```


## 2 创建kube-config，参考[配置对多集群的访问](https://kubernetes.io/zh-cn/docs/tasks/access-application-cluster/configure-access-multiple-clusters/)
- (1)创建kube.config，然后按照`创建用户证书`为每一位用户创建证书并授权     
```shell
cat >kube.config<<EOF
apiVersion: v1
kind: Config
preferences: {}

clusters:
  - cluster:
    name: alpha

users:
  - name: user-backend
  - name: user-frontend
  - name: user-storage
  - name: user-testing

contexts:
  - context:
    name: dev-backend
  - context:
    name: dev-frontend
  - context:
    name: dev-storage
  - context:
    name: dev-testing
EOF
```

- (2)将集群详细信息添加到配置文件中     
```shell
kubectl config --kubeconfig=kube.config set-cluster alpha --server=https://${kubernetes-endpoint} --certificate-authority=/etc/kubernetes/pki/ca.crt --embed-certs
```
或者
```shell
kubectl config --kubeconfig=kube.config set-cluster alpha --server=https://${kubernetes-endpoint} --insecure-skip-tls-verify
```

- (3)将用户详细信息添加到配置文件中      
```shell
kubectl config --kubeconfig=kube.config set-credentials user-backend --client-certificate=user-backend.crt --client-key=user-backend.key --embed-certs=true
kubectl config --kubeconfig=kube.config set-credentials user-frontend --client-certificate=user-frontend.crt --client-key=user-frontend.key --embed-certs=true
kubectl config --kubeconfig=kube.config set-credentials user-storage --client-certificate=user-storage.crt --client-key=user-storage.key --embed-certs=true
kubectl config --kubeconfig=kube.config set-credentials user-testing --client-certificate=user-testing.crt --client-key=user-testing.key --embed-certs=true
```
或者
```shell
kubectl config --kubeconfig=kube.config set-credentials user-backend --username=${username} --password=${password}
kubectl config --kubeconfig=kube.config set-credentials user-frontend --username=${username} --password=${password}
kubectl config --kubeconfig=kube.config set-credentials user-storage --username=${username} --password=${password}
kubectl config --kubeconfig=kube.config set-credentials user-testing --username=${username} --password=${password}
```

- (4)将上下文详细信息添加到配置文件中      
```shell
kubectl config --kubeconfig=kube.config set-context dev-backend --cluster=alpha --namespace=backend --user=user-backend
kubectl config --kubeconfig=kube.config set-context dev-frontend --cluster=alpha --namespace=frontend --user=user-frontend
kubectl config --kubeconfig=kube.config set-context dev-storage --cluster=alpha --namespace=storage --user=user-storage
kubectl config --kubeconfig=kube.config set-context dev-testing --cluster=alpha --namespace=testing --user=user-testing
```

- (5)查看配置文件详细信息    
```shell
kubectl config --kubeconfig=kube.config view
```

- (6)设置当前要使用的上下文    
```shell
kubectl config --kubeconfig=kube.config use-context dev-backend
kubectl config --kubeconfig=kube.config use-context dev-frontend
kubectl config --kubeconfig=kube.config use-context dev-storage
kubectl config --kubeconfig=kube.config use-context dev-testing
```

- (7)使用 `--minify` 参数，来查看当前使用的上下文关联的配置信息    
```shell
kubectl config --kubeconfig=kube.config view --minify
```

- (8)检查当前的上下文用户属性
```shell
kubectl auth whoami
```

- (9)删除用户/删除集群/删除上下文    
```shell
kubectl --kubeconfig=config-demo config unset users.<name>
kubectl --kubeconfig=config-demo config unset clusters.<name>
kubectl --kubeconfig=config-demo config unset contexts.<name>
```

- (10)指定要使用的配置文件
```shell
kubectl --kubeconfig=kube.config <other command>
```
