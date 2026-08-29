#!/bin/bash
# ==============================================================================
# 🌐 Proxmox VE Multi-NIC Bonding & MacBook Direct-Link Setup Script
# ==============================================================================
# - nic0 + nic2: 2Gbps 본딩 그룹 (bond0 / balance-alb) ➔ vmbr0 (192.168.1.200)
# - nic1: 맥북 1:1 직결 전용 브리지 ➔ vmbr1 (10.10.10.1/24)
# ==============================================================================

# ANSI 색상
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}======================================================${NC}"
echo -e "${CYAN}   🌐 Proxmox VE Multi-NIC Bonding & 직결 최적화 설정기 ${NC}"
echo -e "${CYAN}======================================================${NC}"

# Root 권한 체크
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}❌ 이 스크립트는 Proxmox 호스트 root 권한으로 실행해야 합니다.${NC}"
    exit 1
fi

# ifupdown2 패키지 확인
if ! which ifreload >/dev/null 2>&1; then
    echo -e "${YELLOW}📦 ifupdown2 패키지 설치 중...${NC}"
    apt-get update -y && apt-get install -y ifupdown2
fi

# 물리 이더넷 인터페이스 목록 감지
PHYS_IFACES=()
for iface in $(ls /sys/class/net/ 2>/dev/null); do
    if [[ "$iface" =~ ^(lo|vmbr|veth|fwpr|fwbr|tap|bond|tailscale|docker) ]]; then
        continue
    fi
    if [ -d "/sys/class/net/$iface/device" ] || [[ "$iface" =~ ^(en|eth|nic) ]]; then
        PHYS_IFACES+=("$iface")
    fi
done

IFS=$'\n' PHYS_IFACES=($(sort <<<"${PHYS_IFACES[*]}"))
unset IFS
NUM_IFACES=${#PHYS_IFACES[@]}

echo -e "${BLUE}🔍 감지된 물리 이더넷 인터페이스 ($NUM_IFACES 개):${NC}"
for iface in "${PHYS_IFACES[@]}"; do
    OPERSTATE=$(cat "/sys/class/net/$iface/operstate" 2>/dev/null || echo "unknown")
    SPEED=$(cat "/sys/class/net/$iface/speed" 2>/dev/null || echo "1000")
    echo -e "   - ${CYAN}${iface}${NC}: 상태 ${GREEN}${OPERSTATE}${NC} (${SPEED} Mbps)"
done

# 기존 네트워크 설정 백업
BACKUP_FILE="/etc/network/interfaces.bak.$(date +%Y%m%d_%H%M%S)"
echo -e "${BLUE}💾 기존 네트워크 설정 백업:${NC} $BACKUP_FILE"
cp /etc/network/interfaces "$BACKUP_FILE"

# nic0, nic1, nic2 명시적 최적 매핑
# - nic0, nic2: 공유기 본딩 그룹
# - nic1: 맥북 직결 포트
BOND_SLAVES="nic0 nic2"
DIRECT_IFACE="nic1"

# 만약 4개 이상의 인터페이스가 있다면(예: nic3 등) 추가 감지
if [[ " ${PHYS_IFACES[*]} " =~ " nic3 " ]]; then
    BOND_SLAVES="nic0 nic2 nic3"
fi

echo -e "\n${GREEN}📋 확정된 네트워크 구성:${NC}"
echo -e "   1. ${CYAN}공유기 2Gbps 본딩 그룹 (bond0)${NC}: $BOND_SLAVES (모드: balance-alb)"
echo -e "   2. ${CYAN}메인 브리지 (vmbr0)${NC}: 192.168.1.200/24 (게이트웨이: 192.168.1.1) ➔ bond0 연결"
echo -e "   3. ${CYAN}맥북 1:1 직결 브리지 (vmbr1)${NC}: 10.10.10.1/24 (게이트웨이 없음) ➔ $DIRECT_IFACE 연결"

echo -e "\n${YELLOW}새로운 /etc/network/interfaces 파일을 생성합니다...${NC}"

cat <<INTERFACES_EOF > /etc/network/interfaces
# Proxmox VE Multi-NIC Configuration
# Optimized for 2Gbps Home Bonding + MacBook Direct-Attach
# Generated on $(date)

auto lo
iface lo inet loopback

INTERFACES_EOF

for iface in "${PHYS_IFACES[@]}"; do
cat <<INTERFACES_EOF >> /etc/network/interfaces
iface $iface inet manual

INTERFACES_EOF
done

cat <<INTERFACES_EOF >> /etc/network/interfaces
# 1. 공유기 대역폭 2배 본딩 (balance-alb)
auto bond0
iface bond0 inet manual
	bond-slaves $BOND_SLAVES
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

# 3. 맥북 1:1 직결 전용 브리지 (10.10.10.1)
auto vmbr1
iface vmbr1 inet static
	address 10.10.10.1/24
	bridge-ports $DIRECT_IFACE
	bridge-stp off
	bridge-fd 0

INTERFACES_EOF

echo -e "${GREEN}✅ /etc/network/interfaces 생성 완료!${NC}"
echo -e "${BLUE}🔄 네트워크 설정을 적용합니다 (ifreload -a)...${NC}"

if ifreload -a; then
    echo -e "\n${GREEN}🎉 2Gbps 본딩 및 맥북 직결 포트 설정이 완벽하게 적용되었습니다!${NC}"
    echo -e "${CYAN}======================================================${NC}"
    echo -e "1. Proxmox 웹 콘솔: ${GREEN}https://192.168.1.200:8006${NC}"
    echo -e "2. 본딩 상태 확인: ${GREEN}cat /proc/net/bonding/bond0${NC}"
    echo -e "3. 맥북 1:1 직결 연결 안내:"
    echo -e "   - 맥북 [설정 ➔ 네트워크]에서 IP: ${CYAN}10.10.10.2${NC}, 서브넷: ${CYAN}255.255.255.0${NC} (라우터/DNS 비워둠)"
    echo -e "   - 맥북 터미널: ${CYAN}ping 10.10.10.1${NC}"
    echo -e "   - 맥북 Finder (Cmd+K): ${CYAN}smb://10.10.10.1${NC}"
    echo -e "${CYAN}======================================================${NC}"
else
    echo -e "${RED}⚠️ 네트워크 리로드 중 경고가 발생했습니다. 백업 복구 명령어:${NC}"
    echo -e "   cp $BACKUP_FILE /etc/network/interfaces && ifreload -a"
fi
