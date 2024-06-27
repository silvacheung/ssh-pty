# 使用openssl生成TLS证书

- (1)安装openssl

```shell
apt install -y openssl
```

- (2)生成CA证书和密钥

```shell
# 直接生成
# /C=: 国家名称(Country)，使用两个字母的ISO代码，例如US或CN
# /ST=: 州或省份名称(State or Province)
# /L=: 地理位置(Locality)，通常是城市名称
# /O=: 组织名称(Organization)，例如公司或机构的全称。
# /OU=: 组织单位名称(Organizational Unit)，是组织内部的部门或者小组
# /CN=: 通用名称(Common Name)，在SSL证书中，这通常是完全合格的域名（FQDN），例如www.example.com，在个人证书中，它可能是个人的名字
# /emailAddress=: 电子邮件地址(Email)，用于联系证书所有者
# 如果想以后读取私钥文件时不需要输入密码，将`-passout pass:ca123456`替换成`-nodes`
openssl req -newkey rsa:2048 -aes256 -sha512 -passout pass:ca123456 -keyout ca.key -x509 -days 365 -out ca.crt -subj "/C=CN/ST=XX/L=XX/O=XX/OU=XX/CN=XX/emailAddress=XX"

# 分步生成
openssl genrsa -aes256 -passout pass:ca123456 -out ca.key 2048
openssl req -sha512 -new -x509 -days 365 -key ca.key -passin pass:ca123456 -out ca.crt -subj "/C=CN/ST=XX/L=XX/O=XX/OU=XX/CN=XX/emailAddress=XX"

# 将加密的密钥转成未加密的密钥，避免每次读取都要求输入密码
openssl rsa -in ca.key -out ca.key.unsecure -passin pass:ca123456
```

- (3.1)生成服务器密钥和证书签名请求

```shell
# 直接生成
# 如果想以后读取私钥文件时不需要输入密码，将`-passout pass:svr123456`替换成`-nodes`
openssl req -newkey rsa:2048 -aes256 -sha512 -passout pass:svr123456 -keyout server.key -out server.csr -subj "/C=CN/ST=XX/L=XX/O=XX/OU=XX/CN=XX/emailAddress=XX"

# 分步生成
openssl genrsa -aes256 -passout pass:svr123456 -out server.key 2048
openssl req -sha512 -new -key server.key -passin pass:svr123456 -out server.csr -subj "/C=CN/ST=XX/L=XX/O=XX/OU=XX/CN=XX/emailAddress=XX"

# 将加密的密钥转成未加密的密钥，避免每次读取都要求输入密码
openssl rsa -in server.key -out server.key.unsecure -passin pass:svr123456
```

- (3.2)生成服务器`x509 v3`扩展文件

```shell
cat > server-v3.ext <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1=www.example1.com
DNS.2=www.example2.com
DNS.3=www.example3.com
EOF
```

- (3.3)使用CA证书及密钥和v3.ext拓展文件对服务器证书进行签名

```shell
openssl x509 -req -sha512 -days 365 -extfile server-v3.ext -in server.csr -CA ca.crt -CAkey ca.key -passin pass:ca123456 -CAcreateserial -out server.crt
```

- (4.1)生成客户端密钥和证书签名请求

```shell
# 直接生成
# 如果想以后读取私钥文件时不需要输入密码，将`-passout pass:cli123456`替换成`-nodes`
openssl req -newkey rsa:2048 -aes256 -sha512 -passout pass:cli123456 -keyout client.key -out client.csr -subj "/C=CN/ST=XX/L=XX/O=XX/OU=XX/CN=XX/emailAddress=XX"

# 分步生成
openssl genrsa -aes256 -passout pass:cli123456 -out client.key 2048
openssl req -sha512 -new -key client.key -passin pass:cli123456 -out client.csr -subj "/C=CN/ST=XX/L=XX/O=XX/OU=XX/CN=XX/emailAddress=XX"

# 将加密的密钥转成未加密的密钥，避免每次读取都要求输入密码
openssl rsa -in client.key -out client.key.unsecure -passin pass:cli123456
```

- (4.2)生成客户端`x509 v3`扩展文件

```shell
cat > client-v3.ext <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1=www.example1.com
DNS.2=www.example2.com
DNS.3=www.example3.com
EOF
```

- (4.3)使用CA证书及密钥和v3.ext拓展文件对客户端证书进行签名

```shell
openssl x509 -req -sha512 -days 365 -extfile client-v3.ext -in client.csr -CA ca.crt -CAkey ca.key -passin pass:ca123456 -CAcreateserial -out client.crt
```

- (5.1)生成对等密钥和证书签名请求(对等证书就是即可以做服务端证书也可以做客户端证书)

```shell
# 直接生成
# 如果想以后读取私钥文件时不需要输入密码，将`-passout pass:peer123456`替换成`-nodes`
openssl req -newkey rsa:2048 -aes256 -sha512 -passout pass:peer123456 -keyout peer.key -out peer.csr -subj "/C=CN/ST=XX/L=XX/O=XX/OU=XX/CN=XX/emailAddress=XX"

# 分步生成
openssl genrsa -aes256 -passout pass:peer123456 -out peer.key 2048
openssl req -sha512 -new -key peer.key -passin pass:peer123456 -out peer.csr -subj "/C=CN/ST=XX/L=XX/O=XX/OU=XX/CN=XX/emailAddress=XX"

# 将加密的密钥转成未加密的密钥，避免每次读取都要求输入密码
openssl rsa -in peer.key -out peer.key.unsecure -passin pass:peer123456
```

- (5.2)生成对等`x509 v3`扩展文件

```shell
cat > peer-v3.ext <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1=www.example1.com
DNS.2=www.example2.com
DNS.3=www.example3.com
EOF
```

- (5.3)使用CA证书及密钥和v3.ext拓展文件对对端证书进行签名

```shell
openssl x509 -req -sha512 -days 365 -extfile peer-v3.ext -in peer.csr -CA ca.crt -CAkey ca.key -passin pass:ca123456 -CAcreateserial -out peer.crt
```

- (6)验证生成证书是否和配置相符
```shell
openssl x509 -in ca.crt -text -noout
openssl x509 -in server.crt -text -noout
openssl x509 -in client.crt -text -noout
openssl x509 -in peer.crt -text -noout
```