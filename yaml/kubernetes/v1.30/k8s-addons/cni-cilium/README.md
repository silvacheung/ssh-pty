## 安装步骤
### 1. 执行`cni-cilium.sh`安装cilium
### 2. 执行`kubectl patch -n kube-system service/hubble-ui --patch-file hubble-patch.yaml`,补丁会将`hubble-ui`的服务类型改为`NodePort`,并且会在固定的`31081`端口访问hubble的可视化图