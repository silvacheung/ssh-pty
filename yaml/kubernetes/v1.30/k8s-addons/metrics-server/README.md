# From [metrics-server (sigs)](https://kubernetes-sigs.github.io/metrics-server/)

# From [metrics-server (github)](https://github.com/kubernetes-sigs/metrics-server/tree/master/charts/metrics-server)

## 通过helm安装

```shell
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/

helm upgrade --install metrics-server metrics-server/metrics-server \
  --set image.repository=k8s.nju.edu.cn/metrics-server/metrics-server \
  --set addonResizer.image.repository=k8s.nju.edu.cn/autoscaling/addon-resizer \
  --set addonResizer.enabled=false \
  --set replicas=3 \
  --set metrics.enabled=false \
  --set serviceMonitor.enabled=false \
  --set args={"--kubelet-insecure-tls"}

```

# From [prometheus](https://artifacthub.io/packages/helm/prometheus-community/prometheus)

## 通过helm安装

- (1)创建部署cert-manager
```shell
helm repo add jetstack https://charts.jetstack.io

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.14.5 \
  --set installCRDs=true
```

- (2)部署kube-prometheus-stack

```shell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# 如果遇到错误需要安装更新版本的helm
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --set kube-state-metrics.image.registry=k8s.nju.edu.cn \
  --set prometheusOperator.admissionWebhooks.patch.image.registry=k8s.nju.edu.cn \
  --set prometheusOperator.admissionWebhooks.certManager.enabled=true \
  --set grafana.adminPassword=gfa@123456 \
  --set prometheus.extraSecret.name=xxx
```