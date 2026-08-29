#!/bin/bash
set -e

echo "=== Proxmox 네트워크 설정 적용 시작 ==="

# 1. /etc/network/interfaces 파일 직접 작성
cat << 'NET_EOF' > /etc/network/interfaces
auto lo
iface lo inet loopback

iface nic0 inet manual
iface nic1 inet manual
iface nic2 inet manual

# 1. 공유기 1·2번 포트 본딩 (2.5G + 2.5G 초고속 대역폭)
auto bond0
iface bond0 inet manual
	bond-slaves nic1 nic2
	bond-miimon 100
	bond-mode balance-alb

# 2. 홈 네트워크 메인 브리지 (192.168.1.200)
auto vmbr0
iface vmbr0 inet static
	address 192.168.1.200/24
	gateway 192.168.1.1
	bridge-ports bond0
	bridge-stp off
	bridge-fd 0

# 3. 맥북 3번 포트 1:1 직결 전용 브리지 (10.10.10.1)
auto vmbr1
iface vmbr1 inet static
	address 10.10.10.1/24
	bridge-ports nic0
	bridge-stp off
	bridge-fd 0
NET_EOF

# 2. 네트워크 즉시 리로드
ifreload -a

echo "=== ✅ 설정이 완벽하게 적용되었습니다! ==="
