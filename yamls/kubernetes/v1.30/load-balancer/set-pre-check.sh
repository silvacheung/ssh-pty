#!/usr/bin/env bash
set -e

OS="$(head -n 1 /etc/issue | awk '{split($1, arr, " "); print arr[1]}' | tr '[:upper:]' '[:lower:]')"
if [[ "${OS}" != "debian" && "${OS}" != "unbutu" ]];then
  echo "not supported os, only debian/unbutu!"
  exit 1
fi
