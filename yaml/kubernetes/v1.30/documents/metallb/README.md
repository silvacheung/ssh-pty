# 配合转发可以实现外部访问主机指定端口转发到metallb的虚拟IP上
```shell
sudo iptables -t nat -A PREROUTING -p tcp --dport 8880 -j DNAT --to-destination 20.0.0.100:8080
sudo iptables -t nat -A POSTROUTING -p tcp -d 20.0.0.100 --dport 8080 -j MASQUERADE
```