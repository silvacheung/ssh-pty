# 安装本地节点DNS-[nodelocaldns](https://kubernetes.io/zh-cn/docs/tasks/administer-cluster/nodelocaldns/)

## 按照官网步骤安装

```shell
# https://kubernetes.io/zh-cn/docs/tasks/administer-cluster/nodelocaldns/#configuration
# 把下面的变量更改为正确的值
kubedns=$(kubectl get svc kube-dns -n kube-system -o jsonpath={.spec.clusterIP})
domain=cluster.local
localdns=169.254.20.11

# 下载部署清单
wget https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/dns/nodelocaldns/nodelocaldns.yaml

# 如果 kube-proxy 运行在 IPTABLES 模式
sed -i "s/__PILLAR__LOCAL__DNS__/$localdns/g; s/__PILLAR__DNS__DOMAIN__/$domain/g; s/__PILLAR__DNS__SERVER__/$kubedns/g" nodelocaldns.yaml

# 如果 kube-proxy 运行在 IPVS 模式
sed -i "s/__PILLAR__LOCAL__DNS__/$localdns/g; s/__PILLAR__DNS__DOMAIN__/$domain/g; s/,__PILLAR__DNS__SERVER__//g; s/__PILLAR__CLUSTER__DNS__/$kubedns/g" nodelocaldns.yaml

# 如果 kube-proxy 运行在 IPVS 模式
# 需要修改 kubelet 的 --cluster-dns 参数为 NodeLocal DNSCache 正在侦听的 localdns 地址
# 否则，不需要修改 --cluster-dns 参数，因为 NodeLocal DNSCache 会同时侦听 kube-dns 服务的 IP 地址和 localdns 的地址
kubectl apply -f nodelocaldns.yaml
```

## 使用cilium作为CNI的时候需要使用此方式安装，[参考](https://docs.cilium.io/en/stable/network/kubernetes/local-redirect-policy/#node-local-dns-cache)

- (1) 前提：安装cilium时需要指定`localRedirectPolicy=true`

```shell
# 如果安装时未指定，则可以升级来重新设置
cilium upgrade --set localRedirectPolicy=true
```

- (2) 安装：按照cilium官网步骤进行安装即可，这里多了一步替换镜像

```shell
# 下载部署清单
wget https://raw.githubusercontent.com/cilium/cilium/1.15.5/examples/kubernetes-local-redirect/node-local-dns.yaml 
# 获取现在集群DNS
kubedns=$(kubectl get svc kube-dns -n kube-system -o jsonpath={.spec.clusterIP})
# 替换DNS和镜像仓库
sed -i "s/__PILLAR__DNS__SERVER__/$kubedns/g;" node-local-dns.yaml 
sed -i "s/registry.k8s.io/k8s.nju.edu.cn/g" node-local-dns.yaml
# 部署本地节点DNS
kubectl apply -f node-local-dns.yaml
```
