#!/usr/bin/env bash
set -e

# set hostname
hostnamectl set-hostname {{ .Host.Hostname }} && sed -i '/^127.0.1.1/s/.*/127.0.1.1      {{ .Host.Hostname }}/g' /etc/hosts && cat /etc/hostname