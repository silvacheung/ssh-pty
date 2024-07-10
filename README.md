# ssh_pty

# [debian mirror](https://www.debian.org/mirror/sponsors)

# 替换镜像源(指定替换)

```shell
cp sources.list sources.list.bak
sed -ri 's/deb.debian.org/mirrors.ustc.edu.cn/' /etc/apt/sources.list
sed -ri 's/security.debian.org/mirrors.ustc.edu.cn/' /etc/apt/sources.list
```

# 替换镜像源(正则替换)

```shell
cp sources.list sources.list.bak
sed -i 's/http[^*]*\/debian-security/http\:\/\/mirrors\.ustc\.edu\.cn\/debian-security/g' /etc/apt/sources.list
sed -i 's/http[^*]*\/debian/http\:\/\/mirrors\.ustc\.edu\.cn\/debian/g' /etc/apt/sources.list
```

# 镜像源[仓库授权](https://manpages.debian.org/testing/apt/apt_auth.conf.5.en.html)

```shell
cat > /etc/apt/auth.conf.d/auth.conf << EOF
machine example.org login admin password 123456
EOF
```

# 设置Harbor作为docker mirror

- (1) 添加Harbor的Docker镜像代理仓库
- (2) 添加Harbor的Docker镜像代理项目
- (3) 设置Docker registry mirror

```shell
cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": ["http://<harbor local proxy>"],
  "insecure-registries": ["http://<harbor local proxy>"]
}
EOF
```

- (4) 设置Harbor的本地代理配置(nginx)

```text
server {
    listen 80;

    location /v2/ {
        proxy_pass https://<harbor.example.org>/v2/<harbor project name>/;
        proxy_ssl_server_name on;
        proxy_set_header Authorization 'Basic <base64 harbor account:password>';
    }
}
```

# 重置集群

```shell
# cni remove
helm uninstall cilium -n kube-system

# k8s reset
kubeadm reset -f --cri-socket unix:///var/run/containerd/containerd.sock

# kubelet kubeadm kubectl
sudo apt-mark unhold kubelet kubeadm kubectl
sudo apt autoremove --purge kubelet kubeadm kubectl -y && apt autoremove -y && apt autoclean -y

# containerd
systemctl disable containerd && systemctl stop containerd

# load-balancer
apt autoremove --purge haproxy keepalived -y && apt autoremove -y && apt autoclean -y

# net
iptables -F
iptables -F -t nat
iptables -F -t mangle
iptables -X
iptables -X -t nat
ipvsadm -C

# vth
ip link del kube-ipvs0
ip link del nodelocaldns
ip link del cni0
ip link del cilium_host
ip link del cilium_vxlan
ip netns show 2>/dev/null | grep cni- | xargs -r -t -n 1 ip netns del

# vip
NET_IF=ip route | grep ' <host ip> ' | grep 'proto kernel scope link src' | sed -e 's/^.*dev.//' -e 's/.proto.*//' | uniq
ip addr del <vip-cidr> dev ${NET_IF}

# remove files
rm -rf /usr/local/bin/containerd*
rm -rf /usr/local/sbin/runc
rm -rf /usr/bin/crictl
rm -rf /usr/bin/ctr
rm -rf /etc/systemd/system/containerd.service
rm -rf /etc/containerd
rm -rf /etc/crictl.yaml
rm -rf /var/lib/containerd
rm -rf /run/containerd
rm -rf /var/lib/etcd
rm -rf /etc/kubernetes
rm -rf /var/log/pods
rm -rf /var/lib/kubelet
rm -rf /opt/cni
rm -rf /etc/cni
rm -rf /var/lib/cni
rm -rf /usr/local/bin/cilium
rm -rf /var/run/cilium
rm -rf ${HOME}/.kube
rm -rf /etc/haproxy
rm -rf /etc/keepalived
rm -rf /var/lib/haproxy
rm -rf /var/run/haproxy*

# reload
systemctl daemon-reload
```

# 需要单独挂盘的目录

- `/var/lib/containerd`
- `/var/lib/etcd`
- `/var/log`