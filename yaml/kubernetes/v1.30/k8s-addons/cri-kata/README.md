# From [kata-container deploy](https://github.com/kata-containers/kata-containers/blob/main/tools/packaging/kata-deploy/README.md)

## [kata-runtime-class.yaml]列出了一些`runtime class`的创建和支持，具体的需要根据自己的业务定制创建

## 部署顺序
```shell
kubectl apply -f kata-rbac.yaml
kubectl apply -f kata-deploy.yaml
kubectl -n kube-system wait --timeout=10m --for=condition=Ready -l name=kata-deploy pod
kubectl apply -f kata-runtime-class.yaml
```

## 部署kata容器应用[示例](https://raw.githubusercontent.com/kata-containers/kata-containers/main/tools/packaging/kata-deploy/examples/test-deploy-kata-qemu.yaml)
