# k8s [metrics-server (sigs)](https://kubernetes-sigs.github.io/metrics-server/)

# 安装 [metrics-server (github)](https://github.com/kubernetes-sigs/metrics-server/tree/master/charts/metrics-server)

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
  --set args={"--kubelet-insecure-tls"} \
#  --set args[0]=--kubelet-insecure-tls
```

# 安装 [prometheus](https://artifacthub.io/packages/helm/prometheus-community/prometheus)

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

- (3)创建`storageClass`[`prometheus`、`grafana`、`alertmanager`、`thanosRuler`]
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: csi-nfs-prometheus
  annotations:
    nfs.io/storage-path: "nfs-prometheus"
provisioner: k8s-sigs.io/nfs-subdir-external-provisioner
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
allowedTopologies:
  - matchLabelExpressions:
      - key: kubernetes.io/os
        values:
          - linux
mountOptions:
  - "nfsvers=4"
parameters:
  archiveOnDelete: "true"
  onDelete: "retain"
  pathPattern: "${.PVC.namespace}/${.PVC.annotations.nfs.io/storage-path}"
```

- (4)部署kube-prometheus-stack

```shell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# 如果遇到错误需要安装更新版本的helm
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --create-namespace \
  --namespace prometheus-stack \
  --set kubeTargetVersionOverride=1.30.0 \
  --set namespaceOverride=prometheus-stack \
  --set kube-state-metrics.image.registry=k8s.nju.edu.cn \
  --set prometheusOperator.admissionWebhooks.patch.image.registry=k8s.nju.edu.cn \
  --set prometheusOperator.admissionWebhooks.certManager.enabled=true \
  --set prometheusOperator.admissionWebhooks.certManager.rootCert.duration=87840h0m0s \
  --set prometheusOperator.admissionWebhooks.certManager.admissionCert.duration=87840h0m0s \
  --set prometheusOperator.admissionWebhooks.deployment.enabled=true \
  --set prometheusOperator.admissionWebhooks.deployment.podDisruptionBudget.minAvailable=1 \
  --set prometheusOperator.networkPolicy.enabled=false \
  --set grafana.adminPassword=gfa@123456 \
  --set prometheus.prometheusSpec.enableAdminAPI=true \
  --set prometheus.networkPolicy.enabled=false \
  --set prometheus.podDisruptionBudget.enabled=true \
  --set prometheus.podDisruptionBudget.minAvailable=1 \
  --set alertmanager.podDisruptionBudget.enabled=true \
  --set alertmanager.podDisruptionBudget.minAvailable=1 \
  --set thanosRuler.enabled=true \
  --set thanosRuler.podDisruptionBudget.enabled=true \
  --set thanosRuler.podDisruptionBudget.minAvailable=1 \
  --set kubelet.serviceMonitor.attachMetadata.node=true \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=csi-nfs-prometheus \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]=ReadWriteOnce \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi \
  --set grafana.persistence.enabled=false \
  --set grafana.persistence.type=sts \
  --set grafana.persistence.storageClassName=csi-nfs-prometheus \
  --set grafana.persistence.accessModes[0]=ReadWriteOnce \
  --set grafana.persistence.size=20Gi \
  --set grafana.persistence.finalizers[0]=kubernetes.io/pvc-protection \
  --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.storageClassName=csi-nfs-prometheus \
  --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.accessModes[0]=ReadWriteOnce \
  --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage=50Gi \
  --set thanosRuler.thanosRulerSpec.storage.volumeClaimTemplate.spec.storageClassName=csi-nfs-prometheus \
  --set thanosRuler.thanosRulerSpec.storage.volumeClaimTemplate.spec.accessModes[0]=ReadWriteOnce \
  --set thanosRuler.thanosRulerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage=50Gi

# 设置prometheusTLS
# https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md#webconfigfilefields
#  --set prometheus.prometheusSpec.web.httpConfig.http2=true \
#  --set prometheus.prometheusSpec.web.tlsConfig.keySecret.key= \
#  --set prometheus.prometheusSpec.web.tlsConfig.keySecret.name= \
#  --set prometheus.prometheusSpec.web.tlsConfig.keySecret.optional= \
#  --set prometheus.prometheusSpec.web.tlsConfig.cert.secret= \
#  --set prometheus.prometheusSpec.web.tlsConfig.cert.configMap= \
#  --set prometheus.prometheusSpec.web.tlsConfig.clientAuthType= \
#  --set prometheus.prometheusSpec.web.tlsConfig.secret= \
#  --set prometheus.prometheusSpec.web.tlsConfig.configMap= \
#  --set prometheus.prometheusSpec.web.tlsConfig.minVersion=TLS12 \
#  --set prometheus.prometheusSpec.web.tlsConfig.maxVersion=TLS13 \

# 设置prometheus存储
#  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=csi-nfs-prometheus \
#  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]=ReadWriteOnce \
#  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi \

# 设置grafana存储
# https://github.com/grafana/helm-charts/issues/752
#  --set grafana.persistence.enabled=true \
#  --set grafana.persistence.type=sts \
#  --set grafana.persistence.storageClassName=csi-nfs-prometheus \
#  --set grafana.persistence.accessModes[0]=ReadWriteOnce \
#  --set grafana.persistence.size=20Gi \
#  --set grafana.persistence.finalizers[0]=kubernetes.io/pvc-protection \

# 设置alertmanager存储
#  --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.storageClassName=csi-nfs-prometheus \
#  --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.accessModes[0]=ReadWriteOnce \
#  --set alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage=50Gi \

# 设置thanosRuler存储
#  --set thanosRuler.thanosRulerSpec.storage.volumeClaimTemplate.spec.storageClassName=csi-nfs-prometheus \
#  --set thanosRuler.thanosRulerSpec.storage.volumeClaimTemplate.spec.accessModes[0]=ReadWriteOnce \
#  --set thanosRuler.thanosRulerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage=50Gi \
```