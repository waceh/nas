#!/bin/bash
set -e

echo "=== Proxmox 네트워크 설정 적용 시작 ==="

cat << 'NET_EOF' > /etc/network/interfaces
auto lo
iface lo inet loopback

iface nic0 inet manual
iface nic1 inet manual
iface nic2 inet manual

# 1. 포트 1 (nic0): 홈 네트워크 메인 (192.168.1.200)
auto vmbr0
iface vmbr0 inet static
	address 192.168.1.200/24
	gateway 192.168.1.1
	bridge-ports nic0
	bridge-stp off
	bridge-fd 0

# 2. 포트 2 (nic1): 헤놀로지 & 토렌트/미디어 다운로드 전용 2.5G 브리지
auto vmbr2
iface vmbr2 inet manual
	bridge-ports nic1
	bridge-stp off
	bridge-fd 0

# 3. 포트 3 (nic2): 맥북 1:1 직결 전용 초고속 통로 (10.10.10.1)
auto vmbr1
iface vmbr1 inet static
	address 10.10.10.1/24
	bridge-ports nic2
	bridge-stp off
	bridge-fd 0
NET_EOF

ifreload -a

echo "=== ✅ 완벽하게 적용되었습니다! ==="
