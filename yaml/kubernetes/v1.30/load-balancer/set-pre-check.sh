#!/usr/bin/env bash

set -e

echo "验证发行系统 >> /etc/issue"
OS="$(head -n 1 /etc/issue | awk '{split($1, arr, " "); print arr[1]}' | tr '[:upper:]' '[:lower:]')"
if [ "${OS}" != "debian" ];then
  echo "验证发行系统 >> 仅支持debian!"
  exit 1
fi
