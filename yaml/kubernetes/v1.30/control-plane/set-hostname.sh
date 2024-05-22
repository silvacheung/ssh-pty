#!/usr/bin/env bash

set -e

# set hostname
hostnamectl set-hostname {{ get "host.hostname" }} && sed -i '/^127.0.1.1/s/.*/127.0.1.1      {{ get "host.hostname" }}/g' /etc/hosts && cat /etc/hostname