#!/usr/bin/env bash
# ==============================================================================
# AdGuard Home Proxmox Native LXC Installer (self-nas)
# ==============================================================================
# - LXC 102 생성 (Debian 12, 1 Core, 512MB RAM, 4GB SSD on local-530)
# - Go 단일 바이너리 Native systemd 서비스 초경량 설치 (RAM 40MB)
# - 집안 전체 기기 광고/추적기 차단 & 로컬 DNS (nas.home 등) 제공
# ==============================================================================

set -e

GREEN='\033[1;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $1"; }

if [ "$(id -u)" -ne 0 ]; then
    log_err "이 스크립트는 Proxmox 호스트의 root 권한으로 실행해야 합니다."
    exit 1
fi

CTID="${CTID:-102}"
HOSTNAME="${HOSTNAME:-adguard-home}"
CORES="${CORES:-1}"
RAM="${RAM:-512}"
SWAP="${SWAP:-256}"
DISK_SIZE="${DISK_SIZE:-4}"
STORAGE="${STORAGE:-local-530}"
BRIDGE="${BRIDGE:-vmbr0}"
IP_ADDR="${IP_ADDR:-192.168.1.102/24}"
GATEWAY="${GATEWAY:-192.168.1.1}"

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}      AdGuard Home LXC 102 자동 설치기              ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo "컨테이너 ID: ${CTID}"
echo "호스트명: ${HOSTNAME}"
echo "IP 주소: ${IP_ADDR}"
echo "스토리지 풀: ${STORAGE}"
echo "===================================================="

# 1. Debian 12 템플릿 준비
TEMPLATE=$(pveam list local | grep -E "debian-12-standard" | awk '{print $1}' | head -n 1 || true)
if [ -z "$TEMPLATE" ]; then
    log_info "Debian 12 표준 템플릿 다운로드 중..."
    pveam update
    pveam download local debian-12-standard_12.7-1_amd64.tar.zst || pveam download local $(pveam available | grep debian-12 | awk '{print $2}' | head -n 1)
    TEMPLATE=$(pveam list local | grep -E "debian-12-standard" | awk '{print $1}' | head -n 1)
fi

# 2. 기존 컨테이너 확인 및 강제 정리
if pct status "$CTID" &>/dev/null; then
    log_info "기존 CTID ${CTID} 컨테이너 강제 정리 중..."
    pct stop "$CTID" --force &>/dev/null || true
    pct destroy "$CTID" --purge --force &>/dev/null || true
fi

# 3. LXC 102 생성 (Intel 530 SSD local-530 위)
log_info "LXC ${CTID} (${HOSTNAME}) 생성 중..."
pct create "$CTID" "$TEMPLATE" \
  --hostname "$HOSTNAME" \
  --cores "$CORES" \
  --memory "$RAM" \
  --swap "$SWAP" \
  --rootfs "${STORAGE}:${DISK_SIZE}" \
  --net0 name=eth0,bridge="${BRIDGE}",ip="${IP_ADDR}",gw="${GATEWAY}" \
  --unprivileged 0 \
  --features nesting=1 \
  --tags "network,dns,adblock" \
  --onboot 1

pct start "$CTID"
log_ok "LXC ${CTID} 생성 및 시작 완료!"

# 4. 네트워크 대기
sleep 5

# 5. Native AdGuard Home 설치 (LXC 내부)
log_info "LXC 내부 AdGuard Home 초경량 Native 바이너리 설치 중..."
pct exec "$CTID" -- bash -c "
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl ca-certificates tar

# systemd-resolved DNS 53 포트 충돌 방지
if systemctl is-active --quiet systemd-resolved; then
    systemctl stop systemd-resolved
    systemctl disable systemd-resolved
fi

# 공식 Native AdGuard Home 자동 설치
curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v
"

# 6. 호스트 부팅 순서 설정 (DNS이므로 가장 먼저 기동)
pct set "$CTID" --startup "order=1,up=5,down=5"

echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}     AdGuard Home (${CTID}) 설치 완료!              ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e " 1. 초기 셋업 마법사 접속: ${BLUE}http://${IP_ADDR%/*}:3000${NC}"
echo -e " 2. DNS 서버 IP:           ${GREEN}${IP_ADDR%/*}${NC} (포트 53)"
echo -e " 3. 초기 설정 마법사에서 관리자 계정 생성 후 바로 사용 가능합니다."
echo -e " 4. 공유기(ASUS) LAN DNS에 ${GREEN}${IP_ADDR%/*}${NC} 를 등록하면 집안 전체 기기 광고가 자동 차단됩니다."
echo -e "${GREEN}====================================================${NC}"
