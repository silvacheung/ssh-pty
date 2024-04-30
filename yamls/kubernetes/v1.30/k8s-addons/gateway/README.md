# 在集群中启用GatewayAPI

## - 参考[GatewayAPI](https://kubernetes.io/zh-cn/docs/concepts/services-networking/gateway/)

## - Gateway API 资源不是由 Kubernetes 原生实现的, 用户需要安装或者按照所选实现的安装说明进行操作

## - 步骤 (以HAPROXY为例)

- (1)安装标准[`Gateway API CRD`](https://gateway-api.sigs.k8s.io/guides/#installing-gateway-api)

```shell
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
```

或者安装实验性[`Gateway API CRD`](https://gateway-api.sigs.k8s.io/guides/#installing-gateway-api),`TCPRoute`、`TLSRoute`
、`UDPRoute`、`GRPCRoute`必须使用试验性CRD

```shell
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/experimental-install.yaml
```

- (2)安装[HAPROXY入口控制器](https://www.haproxy.com/documentation/kubernetes-ingress/gateway-api/enable-gateway-api/)

```shell
helm repo add haproxytech https://haproxytech.github.io/helm-charts

helm repo update haproxytech

kubectl create namespace haproxy-controller

helm upgrade --install haproxy-kubernetes-ingress haproxytech/kubernetes-ingress --namespace haproxy-controller -f - <<EOF
controller:
  autoscaling:
    enabled: true
  serviceMonitor:
    enabled: true
  kubernetesGateway:
    enabled: true
    gatewayControllerName: haproxy.org/gateway-controller 

  service:
    nodePorts:
      http: 31080
      https: 31443
      stat: 31024
      prometheus: 31060
    tcpPorts:
      - name: tcp8000
        protocol: TCP
        port: 8000
        nodePort: 32080
        targetPort: 8000
EOF
```

- (3)使用标准`Gateway API`[定义GatewayClass](https://www.haproxy.com/documentation/kubernetes-ingress/gateway-api/enable-gateway-api/#define-a-gatewayclass)
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
 namespace: haproxy-controller
 name: haproxy-ingress-gatewayclass
spec:
 controllerName: haproxy.org/gateway-controller
```

部署网关类

```shell
kubectl apply -f gatewayclass-haproxy-ingress.yaml
```

- (4)使用标准`Gateway API`[定义Gateway](https://www.haproxy.com/documentation/kubernetes-ingress/gateway-api/enable-gateway-api/#define-a-gateway)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gateway-haproxy-8000
  namespace: default
spec:
  gatewayClassName: haproxy-ingress-gatewayclass
  listeners:
    - allowedRoutes:
        kinds:
          - group: gateway.networking.k8s.io
            kind: TCPRoute
        namespaces:
          from: All
      name: tcp8000
      port: 8000
      protocol: TCP
```

部署网关

```shell
kubectl apply -f gateway-haproxy-8000.yaml
```


- (5)使用标准`Gateway API`[定义TCPRoute](https://www.haproxy.com/documentation/kubernetes-ingress/gateway-api/enable-gateway-api/#define-routes)

```yaml
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TCPRoute
metadata:
  name: route-haproxy-8000-svc-target
  namespace: default
spec:
  parentRefs:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: gateway-haproxy-8000
      namespace: default
  rules:
    - backendRefs:
        - group: ''
          kind: Service
          name: target-service
          port: 80
          weight: 10
```

部署路由

```shell
kubectl apply -f route-haproxy-8000-svc-target.yaml
```

- (6)要使用其他的`Gateway API`[参考](https://kubernetes.io/zh-cn/docs/concepts/services-networking/gateway/)