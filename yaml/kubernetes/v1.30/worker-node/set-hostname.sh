#!/usr/bin/env bash

set -e

echo "设置主机名称 >> {{ get "host.hostname" }}"
hostnamectl set-hostname {{ get "host.hostname" }} && sed -i '/^127.0.1.1/s/.*/127.0.1.1      {{ get "host.hostname" }}/g' /etc/hosts