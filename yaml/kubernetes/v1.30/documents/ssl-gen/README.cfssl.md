# 使用[cfssl](https://github.com/cloudflare/cfssl)生成TLS证书

- (1)安装cfssl

```shell
apt install -y golang-cfssl
```

- (2)初始化CA配置和证书签名请求

```shell
# 查看默认配置
cfssl print-defaults config > ca-config.json
cfssl print-defaults csr > ca-csr.json
cfssl print-defaults csr > server-csr.json
cfssl print-defaults csr > client-csr.json
cfssl print-defaults csr > peer-csr.json
```

ca-config.json

```json
{
  "signing": {
    "default": {
      "expiry": "168h"
    },
    "profiles": {
      "server": {
        "expiry": "8760h",
        "usages": [
          "signing",
          "key encipherment",
          "server auth"
        ]
      },
      "client": {
        "expiry": "8760h",
        "usages": [
          "signing",
          "key encipherment",
          "client auth"
        ]
      },
      "peer": {
        "expiry": "8760h",
        "usages": [
          "signing",
          "key encipherment",
          "server auth",
          "client auth"
        ]
      }
    }
  }
}
```

ca-csr.json

```json
{
  "CN": "Common Name",
  "hosts": [
    "example.net",
    "www.example.net"
  ],
  "key": {
    "algo": "ecdsa",
    "size": 256
  },
  "names": [
    {
      "C": "Country",
      "L": "Locality",
      "O": "Organization",
      "ST": "State or Province",
      "OU": "Organizational Unit"
    }
  ]
}
```

server-csr.json

```json
{
  "CN": "Common Name",
  "hosts": [
    "example.net",
    "www.example.net"
  ],
  "key": {
    "algo": "ecdsa",
    "size": 256
  },
  "names": [
    {
      "C": "Country",
      "L": "Locality",
      "O": "Organization",
      "ST": "State or Province",
      "OU": "Organizational Unit"
    }
  ]
}
```

client-csr.json

```json
{
  "CN": "Common Name",
  "hosts": [
    "example.net",
    "www.example.net"
  ],
  "key": {
    "algo": "ecdsa",
    "size": 256
  },
  "names": [
    {
      "C": "Country",
      "L": "Locality",
      "O": "Organization",
      "ST": "State or Province",
      "OU": "Organizational Unit"
    }
  ]
}
```

peer-csr.json

```json
{
  "CN": "Common Name",
  "hosts": [
    "example.net",
    "www.example.net"
  ],
  "key": {
    "algo": "ecdsa",
    "size": 256
  },
  "names": [
    {
      "C": "Country",
      "L": "Locality",
      "O": "Organization",
      "ST": "State or Province",
      "OU": "Organizational Unit"
    }
  ]
}
```

- (3)生成CA证书
```shell
cfssl gencert -initca ca-csr.json | cfssljson -bare ca -
```

- (4)生成服务器证书
```shell
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=server server-csr.json | cfssljson -bare server -
```

- (5)生成客户端证书
```shell
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=client client-csr.json | cfssljson -bare client -
```

- (6)生成对等证书
```shell
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=peer peer-csr.json | cfssljson -bare peer -
```

- (7)验证生成证书是否和配置相符
```shell
openssl x509 -in ca.pem -text -noout
openssl x509 -in server.pem -text -noout
openssl x509 -in client.pem -text -noout
openssl x509 -in peer.pem -text -noout
```
