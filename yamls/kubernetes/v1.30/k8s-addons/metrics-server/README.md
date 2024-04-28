# From [metrics-server (sigs)](https://kubernetes-sigs.github.io/metrics-server/)
# From [metrics-server (github)](https://github.com/kubernetes-sigs/metrics-server/tree/master/charts/metrics-server)

## 通过helm安装
```shell
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/

helm upgrade --install metrics-server metrics-server/metrics-server \
  --set image.repository=registry.cn-hangzhou.aliyuncs.com/google_containers/metrics-server \
  --set addonResizer.image.repository=registry.k8s.io/autoscaling/addon-resizer \
  --set addonResizer.enabled=false \
  --set replicas=3 \
  --set metrics.enabled=true \
  --set serviceMonitor.enabled=true \
  --set args={"--kubelet-insecure-tls"}

```