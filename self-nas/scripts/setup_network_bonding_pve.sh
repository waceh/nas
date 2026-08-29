#!/bin/bash
set -e

echo "=== Proxmox 네트워크 설정 적용 시작 ==="

cat << 'NET_EOF' > /etc/network/interfaces
auto lo
iface lo inet loopback

iface nic0 inet manual
iface nic1 inet manual
iface nic2 inet manual

# 1. 홈 네트워크 메인 (2.5G 초고속 포트 nic2 연결)
auto vmbr0
iface vmbr0 inet static
	address 192.168.1.200/24
	gateway 192.168.1.1
	bridge-ports nic2
	bridge-stp off
	bridge-fd 0

# 2. 맥북 1:1 직결 전용 (1G 포트 nic0 연결)
auto vmbr1
iface vmbr1 inet static
	address 10.10.10.1/24
	bridge-ports nic0
	bridge-stp off
	bridge-fd 0
NET_EOF

ifreload -a

echo "=== ✅ 설정이 완벽하게 적용되었습니다! ==="
