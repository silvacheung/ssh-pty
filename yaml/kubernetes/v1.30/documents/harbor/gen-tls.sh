#!/usr/bin/env bash
D_NAME="harbor-registry"
DOMAIN="${D_NAME}.com"

openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -sha512 -days 3650 \
 -subj "/C=CN/ST=Sichuan/L=Chengdu/O=Harbor/OU=Harbor/CN=${DOMAIN}" \
 -key ca.key \
 -out ca.crt

openssl genrsa -out ${DOMAIN}.key 4096
openssl req -sha512 -new \
    -subj "/C=CN/ST=Sichuan/L=Chengdu/O=Harbor/OU=Harbor/CN=${DOMAIN}" \
    -key ${DOMAIN}.key \
    -out ${DOMAIN}.csr

cat > v3.ext <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1=${DOMAIN}
DNS.2=${D_NAME}
EOF

openssl x509 -req -sha512 -days 3650 \
    -extfile v3.ext \
    -CA ca.crt -CAkey ca.key -CAcreateserial \
    -in ${DOMAIN}.csr \
    -out ${DOMAIN}.crt

openssl x509 -inform PEM -in ${DOMAIN}.crt -out ${DOMAIN}.cert