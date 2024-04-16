#!/usr/bin/env bash

# set ntp server
# clear old server and disable pool
sed -i '/^server/d' /etc/chrony/chrony.conf
sed -i 's/^pool /#pool /g' /etc/chrony/chrony.conf

# 检查或者添加NtpSever，多个server执行多次即可，以下是使用阿里云和腾讯的NtpServer
{{- range .Configs.NtpServer }}
grep -q '^server {{ . }}' /etc/chrony/chrony.conf||sed '1a server {{ . }} iburst' -i /etc/chrony/chrony.conf
{{- end }}

# 设置timezone
timedatectl set-timezone {{ .Configs.Timezone }}
timedatectl set-ntp true

# 启动chrony并立即校正
systemctl enable chrony.service && systemctl restart chrony.service
chronyc makestep > /dev/null && chronyc sources