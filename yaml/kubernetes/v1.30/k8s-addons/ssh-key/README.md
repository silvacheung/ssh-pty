# 使用root登录
- (1)修改配置文件允许root登录,禁止空密码登录
```shell
vi /etc/ssh/sshd_config

# 设置修改如下配置
# PermitRootLogin yes
# PasswordAuthentication yes
# PermitEmptyPasswords no
```

# 使用SSH密钥登录
- (1)修改配置文件允许密钥登录
```shell
vi /etc/ssh/sshd_config

# 设置修改如下配置
# PubkeyAuthentication yes
# AuthorizedKeysFile .ssh/authorized_keys
```

- (1)生成密钥并写入公钥到authorized_keys文件
```shell
# -m 格式
# -t 算法
# -b 位数
# -N 密码
# -C 备注
# -f 文件
ssh-keygen -m pem -t rsa -b 4096 -N 123456 -C "name of user" -f ~/.ssh/id_rsa
cat id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

- (3)其他主机即可以通过id_rsa密钥免密连接