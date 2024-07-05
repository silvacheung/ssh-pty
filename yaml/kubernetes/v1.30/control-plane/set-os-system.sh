#!/usr/bin/env bash

echo "设置系统数据 >> 禁用交换分区"
swapoff -a
sed -i /^[^#]*swap*/s/^/\#/g /etc/fstab
for swap in $(systemctl --type swap --all | grep -E ".swap[[:space:]]+loaded" | awk '{print $1}')
do
	systemctl mask "$swap"
done

echo "设置系统数据 >> 禁用SELinux"
# 永久禁用SELinux(必须按顺序执行)
if [ -f /etc/selinux/config ]; then
  sed -ri 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
  sed -ri 's/SELINUX=permissive/SELINUX=disabled/' /etc/selinux/config
fi

# 临时禁用SELinux(必须按顺序执行)
setenforce 0
getenforce

echo "设置系统数据 >> /etc/sysctl.conf"
# sysctl net
# net.ipv4.tcp_tw_recycle高版本内核已删除
# https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=4396e46187ca5070219b81773c4e65088dac50cc
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
echo 'net.bridge.bridge-nf-call-arptables = 1' >> /etc/sysctl.conf
echo 'net.bridge.bridge-nf-call-ip6tables = 1' >> /etc/sysctl.conf
echo 'net.bridge.bridge-nf-call-iptables = 1' >> /etc/sysctl.conf
echo 'net.ipv4.ip_local_reserved_ports = 30000-32767' >> /etc/sysctl.conf
echo 'net.core.netdev_max_backlog = 65535' >> /etc/sysctl.conf
echo 'net.core.rmem_max = 67108864' >> /etc/sysctl.conf
echo 'net.core.wmem_max = 67108864' >> /etc/sysctl.conf
echo 'net.core.somaxconn = 32768' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_max_syn_backlog = 1048576' >> /etc/sysctl.conf
echo 'net.ipv4.neigh.default.gc_thresh1 = 1024' >> /etc/sysctl.conf
echo 'net.ipv4.neigh.default.gc_thresh2 = 4096' >> /etc/sysctl.conf
echo 'net.ipv4.neigh.default.gc_thresh3 = 8192' >> /etc/sysctl.conf
echo 'net.ipv6.neigh.default.gc_thresh1 = 1024' >> /etc/sysctl.conf
echo 'net.ipv6.neigh.default.gc_thresh2 = 4096' >> /etc/sysctl.conf
echo 'net.ipv6.neigh.default.gc_thresh3 = 8192' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_retries2 = 15' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_max_tw_buckets = 1048576' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_max_orphans = 65535' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_keepalive_time = 600' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_keepalive_intvl = 30' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_keepalive_probes = 10' >> /etc/sysctl.conf
echo 'net.ipv4.udp_rmem_min = 131072' >> /etc/sysctl.conf
echo 'net.ipv4.udp_wmem_min = 131072' >> /etc/sysctl.conf
echo 'net.ipv4.conf.all.rp_filter = 0' >> /etc/sysctl.conf
echo 'net.ipv4.conf.default.rp_filter = 0' >> /etc/sysctl.conf
echo 'net.ipv4.conf.all.arp_accept = 1' >> /etc/sysctl.conf
echo 'net.ipv4.conf.default.arp_accept = 1' >> /etc/sysctl.conf
echo 'net.ipv4.conf.all.arp_ignore = 1' >> /etc/sysctl.conf
echo 'net.ipv4.conf.default.arp_ignore = 1' >> /etc/sysctl.conf
echo 'net.core.rmem_default = 655350' >> /etc/sysctl.conf
echo 'net.core.wmem_default = 655350' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_syncookies = 1' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_tw_reuse = 1' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_tw_recycle = 0' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_fin_timeout = 10' >> /etc/sysctl.conf
echo 'net.ipv4.ip_local_port_range = 32768 65000' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_rmem = 4096 87380 67108864' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_wmem = 4096 65536 67108864' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_mtu_probing = 1' >> /etc/sysctl.conf
echo 'net.core.default_qdisc = cake' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_congestion_control = bbr' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_fastopen = 3' >> /etc/sysctl.conf
echo 'net.ipv4.neigh.default.gc_stale_time = 120' >> /etc/sysctl.conf
echo 'net.ipv4.conf.default.arp_announce = 2' >> /etc/sysctl.conf
echo 'net.ipv4.conf.lo.arp_announce = 2' >> /etc/sysctl.conf
echo 'net.ipv4.conf.all.arp_announce = 2' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_synack_retries = 3' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_slow_start_after_idle = 0' >> /etc/sysctl.conf
echo 'net.netfilter.nf_conntrack_buckets = 262144' >> /etc/sysctl.conf
echo 'net.netfilter.nf_conntrack_max = 1048576' >> /etc/sysctl.conf
echo 'net.netfilter.nf_conntrack_tcp_timeout_established = 1800' >> /etc/sysctl.conf
echo 'net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120' >> /etc/sysctl.conf
echo 'net.netfilter.nf_conntrack_tcp_timeout_time_wait = 120' >> /etc/sysctl.conf
echo 'net.netfilter.nf_conntrack_tcp_timeout_close_wait = 120' >> /etc/sysctl.conf
echo 'vm.max_map_count = 262144' >> /etc/sysctl.conf
echo 'vm.swappiness = 0' >> /etc/sysctl.conf
echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf
echo 'vm.panic_on_oom = 0' >> /etc/sysctl.conf
echo 'fs.file-max = 1024000' >> /etc/sysctl.conf
echo 'fs.inotify.max_user_instances = 524288' >> /etc/sysctl.conf
echo 'fs.inotify.max_user_watches = 524288' >> /etc/sysctl.conf
echo 'fs.pipe-max-size = 4194304' >> /etc/sysctl.conf
echo 'fs.aio-max-nr = 262144' >> /etc/sysctl.conf
echo 'fs.nr_open = 52706963' >> /etc/sysctl.conf
echo 'kernel.pid_max = 655350' >> /etc/sysctl.conf
echo 'kernel.watchdog_thresh = 5' >> /etc/sysctl.conf
echo 'kernel.hung_task_timeout_secs = 5' >> /etc/sysctl.conf
echo 'kernel.sysrq = 1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.all.disable_ipv6 = 0' >> /etc/sysctl.conf
echo 'net.ipv6.conf.default.disable_ipv6 = 0' >> /etc/sysctl.conf
echo 'net.ipv6.conf.lo.disable_ipv6 = 0' >> /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.conf

# 修改已知问题
# see https://help.aliyun.com/zh/ecs/support/common-kernel-network-parameters-of-ecs-linux-instances-and-faq
# see https://help.aliyun.com/document_detail/118806.html#uicontrol-e50-ddj-w0y
# see https://help.aliyun.com/zh/ack/product-overview/before-you-start#13710b880fjly
sed -r -i "s@#{0,}?net.ipv4.tcp_tw_recycle ?= ?(0|1|2)@net.ipv4.tcp_tw_recycle = 0@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.tcp_tw_reuse ?= ?(0|1)@net.ipv4.tcp_tw_reuse = 1@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.conf.all.rp_filter ?= ?(0|1|2)@net.ipv4.conf.all.rp_filter = 0@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.conf.default.rp_filter ?= ?(0|1|2)@net.ipv4.conf.default.rp_filter = 0@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.ip_forward ?= ?(0|1)@net.ipv4.ip_forward = 1@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.bridge.bridge-nf-call-arptables ?= ?(0|1)@net.bridge.bridge-nf-call-arptables = 1@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.bridge.bridge-nf-call-ip6tables ?= ?(0|1)@net.bridge.bridge-nf-call-ip6tables = 1@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.bridge.bridge-nf-call-iptables ?= ?(0|1)@net.bridge.bridge-nf-call-iptables = 1@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.ip_local_reserved_ports ?= ?([0-9]{1,}-{0,1},{0,1}){1,}@net.ipv4.ip_local_reserved_ports = 30000-32767@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?vm.max_map_count ?= ?([0-9]{1,})@vm.max_map_count = 262144@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?vm.swappiness ?= ?([0-9]{1,})@vm.swappiness = 0@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?fs.inotify.max_user_instances ?= ?([0-9]{1,})@fs.inotify.max_user_instances = 524288@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?kernel.pid_max ?= ?([0-9]{1,})@kernel.pid_max = 655350@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?vm.overcommit_memory ?= ?(0|1|2)@vm.overcommit_memory = 0@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?fs.inotify.max_user_watches ?= ?([0-9]{1,})@fs.inotify.max_user_watches = 524288@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?fs.pipe-max-size ?= ?([0-9]{1,})@fs.pipe-max-size = 4194304@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.core.netdev_max_backlog ?= ?([0-9]{1,})@net.core.netdev_max_backlog = 65535@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.core.rmem_max ?= ?([0-9]{1,})@net.core.rmem_max = 67108864@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.core.wmem_max ?= ?([0-9]{1,})@net.core.wmem_max = 67108864@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.tcp_max_syn_backlog ?= ?([0-9]{1,})@net.ipv4.tcp_max_syn_backlog = 1048576@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.neigh.default.gc_thresh1 ?= ?([0-9]{1,})@net.ipv4.neigh.default.gc_thresh1 = 1024@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.neigh.default.gc_thresh2 ?= ?([0-9]{1,})@net.ipv4.neigh.default.gc_thresh2 = 4096@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.neigh.default.gc_thresh3 ?= ?([0-9]{1,})@net.ipv4.neigh.default.gc_thresh3 = 8192@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv6.neigh.default.gc_thresh1 ?= ?([0-9]{1,})@net.ipv6.neigh.default.gc_thresh1 = 1024@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv6.neigh.default.gc_thresh2 ?= ?([0-9]{1,})@net.ipv6.neigh.default.gc_thresh2 = 4096@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv6.neigh.default.gc_thresh3 ?= ?([0-9]{1,})@net.ipv6.neigh.default.gc_thresh3 = 8192@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.core.somaxconn ?= ?([0-9]{1,})@net.core.somaxconn = 32768@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.conf.eth0.arp_accept ?= ?(0|1)@net.ipv4.conf.eth0.arp_accept = 1@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.conf.all.arp_accept ?= ?([0-9]{1,})@net.ipv4.conf.all.arp_accept = 1@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.conf.default.arp_accept ?= ?([0-9]{1,})@net.ipv4.conf.default.arp_accept = 1@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?fs.aio-max-nr ?= ?([0-9]{1,})@fs.aio-max-nr = 262144@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.tcp_retries2 ?= ?([0-9]{1,})@net.ipv4.tcp_retries2 = 15@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.tcp_max_tw_buckets ?= ?([0-9]{1,})@net.ipv4.tcp_max_tw_buckets = 1048576@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.tcp_max_orphans ?= ?([0-9]{1,})@net.ipv4.tcp_max_orphans = 65535@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.tcp_keepalive_time ?= ?([0-9]{1,})@net.ipv4.tcp_keepalive_time = 600@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.tcp_keepalive_intvl ?= ?([0-9]{1,})@net.ipv4.tcp_keepalive_intvl = 30@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.tcp_keepalive_probes ?= ?([0-9]{1,})@net.ipv4.tcp_keepalive_probes = 10@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.udp_rmem_min ?= ?([0-9]{1,})@net.ipv4.udp_rmem_min = 131072@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.udp_wmem_min ?= ?([0-9]{1,})@net.ipv4.udp_wmem_min = 131072@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.conf.all.arp_ignore ?= ??(0|1|2)@net.ipv4.conf.all.arp_ignore = 1@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.conf.default.arp_ignore ?= ??(0|1|2)@net.ipv4.conf.default.arp_ignore = 1@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?kernel.watchdog_thresh ?= ?([0-9]{1,})@kernel.watchdog_thresh = 5@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?kernel.hung_task_timeout_secs ?= ?([0-9]{1,})@kernel.hung_task_timeout_secs = 5@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?fs.file-max ?= ?([0-9]{1,})@fs.file-max = 1024000@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?fs.nr_open ?= ?([0-9]{1,})@fs.nr_open = 52706963@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.core.rmem_default ?= ?([0-9]{1,})@net.core.rmem_default = 655350@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.core.wmem_default ?= ?([0-9]{1,})@net.core.wmem_default = 655350@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.tcp_syncookies ?= ?([0-9]{1,})@net.ipv4.tcp_syncookies = 1@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.tcp_fin_timeout ?= ?([0-9]{1,})@net.ipv4.tcp_fin_timeout = 10@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.ip_local_port_range ?= ?([0-9]{1,} [0-9]{1,}){1,}@net.ipv4.ip_local_port_range = 32768 65000@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.tcp_rmem ?= ?([0-9]{1,} [0-9]{1,} [0-9]{1,}){1,}@net.ipv4.tcp_rmem = 4096 87380 67108864@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.tcp_wmem ?= ?([0-9]{1,} [0-9]{1,} [0-9]{1,}){1,}@net.ipv4.tcp_wmem = 4096 65536 67108864@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.tcp_mtu_probing ?= ?([0-9]{1,})@net.ipv4.tcp_mtu_probing = 1@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.core.default_qdisc ?= ?([0-9,a-z,A-Z]{1,})@net.core.default_qdisc = cake@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.tcp_congestion_control ?= ?([0-9,a-z,A-Z]{1,})@net.ipv4.tcp_congestion_control = bbr@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.tcp_fastopen ?= ?([0-9]{1,})@net.ipv4.tcp_fastopen = 3@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?vm.panic_on_oom ?= ?([0-9]{1,})@vm.panic_on_oom = 0@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?kernel.sysrq ?= ?([0-9]{1,})@kernel.sysrq = 1@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.neigh.default.gc_stale_time ?= ?([0-9]{1,})@net.ipv4.neigh.default.gc_stale_time = 120@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.conf.default.arp_announce ?= ?([0-9]{1,})@net.ipv4.conf.default.arp_announce = 2@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.conf.lo.arp_announce ?= ?([0-9]{1,})@net.ipv4.conf.lo.arp_announce = 2@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.conf.all.arp_announce ?= ?([0-9]{1,})@net.ipv4.conf.all.arp_announce = 2@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.tcp_synack_retries ?= ?([0-9]{1,})@net.ipv4.tcp_synack_retries = 3@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.tcp_slow_start_after_idle ?= ?([0-9]{1,})@net.ipv4.tcp_slow_start_after_idle = 0@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.netfilter.nf_conntrack_buckets ?= ?([0-9]{1,})@net.netfilter.nf_conntrack_buckets = 262144@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.netfilter.nf_conntrack_max ?= ?([0-9]{1,})@net.netfilter.nf_conntrack_max = 1048576@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.netfilter.nf_conntrack_tcp_timeout_established ?= ?([0-9]{1,})@net.netfilter.nf_conntrack_tcp_timeout_established = 1800@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.netfilter.nf_conntrack_tcp_timeout_fin_wait ?= ?([0-9]{1,})@net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.netfilter.nf_conntrack_tcp_timeout_time_wait ?= ?([0-9]{1,})@net.netfilter.nf_conntrack_tcp_timeout_time_wait = 120@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.netfilter.nf_conntrack_tcp_timeout_close_wait ?= ?([0-9]{1,})@net.netfilter.nf_conntrack_tcp_timeout_close_wait = 120@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv6.conf.all.disable_ipv6 ?= ?([0-9]{1,})@net.ipv6.conf.all.disable_ipv6 = 0@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv6.conf.default.disable_ipv6 ?= ?([0-9]{1,})@net.ipv6.conf.default.disable_ipv6 = 0@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv6.conf.lo.disable_ipv6 ?= ?([0-9]{1,})@net.ipv6.conf.lo.disable_ipv6 = 0@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv6.conf.all.forwarding ?= ?([0-9]{1,})@net.ipv6.conf.all.forwarding = 1@g" /etc/sysctl.conf

TEM_FILE="$$.tmp"
awk ' !x[$0]++{print > "'$TEM_FILE'"}' /etc/sysctl.conf
mv $TEM_FILE /etc/sysctl.conf

echo "设置系统数据 >> /etc/security/limits.conf"
echo "* soft nofile 1048576" >> /etc/security/limits.conf
echo "* hard nofile 1048576" >> /etc/security/limits.conf
echo "* soft nproc 65536" >> /etc/security/limits.conf
echo "* hard nproc 65536" >> /etc/security/limits.conf
echo "* soft memlock unlimited" >> /etc/security/limits.conf
echo "* hard memlock unlimited" >> /etc/security/limits.conf

sed -r -i  "s@#{0,}?\* soft nofile ?([0-9]{1,})@\* soft nofile 1048576@g" /etc/security/limits.conf
sed -r -i  "s@#{0,}?\* hard nofile ?([0-9]{1,})@\* hard nofile 1048576@g" /etc/security/limits.conf
sed -r -i  "s@#{0,}?\* soft nproc ?([0-9]{1,})@\* soft nproc 65536@g" /etc/security/limits.conf
sed -r -i  "s@#{0,}?\* hard nproc ?([0-9]{1,})@\* hard nproc 65536@g" /etc/security/limits.conf
sed -r -i  "s@#{0,}?\* soft memlock ?([0-9]{1,}([TGKM]B){0,1}|unlimited)@\* soft memlock unlimited@g" /etc/security/limits.conf
sed -r -i  "s@#{0,}?\* hard memlock ?([0-9]{1,}([TGKM]B){0,1}|unlimited)@\* hard memlock unlimited@g" /etc/security/limits.conf

TEM_FILE="$$.tmp"
awk ' !x[$0]++{print > "'$TEM_FILE'"}' /etc/security/limits.conf
mv $TEM_FILE /etc/security/limits.conf

echo "设置系统数据 >> ulimit"
ulimit -n 655350

echo "设置系统数据 >> 关闭/禁用防火墙"
systemctl stop firewalld 1>/dev/null 2>/dev/null
systemctl disable firewalld 1>/dev/null 2>/dev/null
systemctl stop ufw 1>/dev/null 2>/dev/null
systemctl disable ufw 1>/dev/null 2>/dev/null

echo "设置系统数据 >> 加载br_netfilter"
mkdir -p /etc/modules-load.d
modinfo br_netfilter > /dev/null 2>&1
if [ $? -eq 0 ]; then
   modprobe br_netfilter
   echo 'br_netfilter' > /etc/modules-load.d/k8s-br_netfilter.conf
fi

echo "设置系统数据 >> 加载overlay"
modinfo overlay > /dev/null 2>&1
if [ $? -eq 0 ]; then
   modprobe overlay
   echo 'overlay' >> /etc/modules-load.d/k8s-br_netfilter.conf
fi

echo "设置系统数据 >> 加载ip_vs*"
modprobe ip_vs
modprobe ip_vs_rr
modprobe ip_vs_wrr
modprobe ip_vs_sh

cat > /etc/modules-load.d/kubeproxy-ipvs.conf << EOF
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
EOF

echo "设置系统数据 >> 加载nf_conntrack_ipv4/nf_conntrack"
modprobe nf_conntrack_ipv4 1>/dev/null 2>/dev/null
if [ $? -eq 0 ]; then
   echo 'nf_conntrack_ipv4' >> /etc/modules-load.d/kubeproxy-ipvs.conf
else
   modprobe nf_conntrack
   echo 'nf_conntrack' >> /etc/modules-load.d/kubeproxy-ipvs.conf
fi

echo "设置系统数据 >> 配置刷新生效"
# /etc/sysctl.conf
sysctl -p
# /etc/sysctl.d
sysctl --system
# 将缓冲区数据写入磁盘
sync
# 释放所有缓存
echo 3 > /proc/sys/vm/drop_caches

echo "设置系统数据 >> iptables"
update-alternatives --set iptables /usr/sbin/iptables-legacy >/dev/null 2>&1 || true
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy >/dev/null 2>&1 || true
update-alternatives --set arptables /usr/sbin/arptables-legacy >/dev/null 2>&1 || true
update-alternatives --set ebtables /usr/sbin/ebtables-legacy >/dev/null 2>&1 || true