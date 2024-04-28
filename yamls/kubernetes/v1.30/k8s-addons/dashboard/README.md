# From [kubernetes-dashboard](https://github.com/kubernetes/dashboard#kubernetes-dashboard)

## 只能通过helm安装，安装步骤（最新的安装参考官方最新文档）
```shell
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/

helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
  --create-namespace \
  --namespace kubernetes-dashboard

```
kubectl patch -n kubernetes-dashboard   service/kubernetes-dashboard-web --patch-file ui-web.yaml
## 设置[访问dashboard](https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/creating-sample-user.md)
### 1. 执行`kubectl apply -f dashboard-user.yaml`以创建一个可以访问的用户
### 2. 执行`kubectl patch -n kubernetes-dashboard service/kubernetes-dashboard-kong-proxy --patch-file dashboard-patch.yaml`以创建一个补丁使我们可以以NodePort来访问web
### 3. 执行`kubectl -n kubernetes-dashboard create token dashboard-admin-user`则可以获取一个访问Token
### 4. 执行`kubectl get secret dashboard-admin-user -n kubernetes-dashboard -o jsonpath={".data.token"} | base64 -d`也可以获取一个Token,这个Token是存储在Secret中的长期持有Token
