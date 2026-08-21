#!/usr/bin/env bash
# ==============================================================================
# Proxmox VE System Audit, Process Cleanup & Health Inspector (self-nas)
# ==============================================================================
# - 불필요한 레거시 데몬(구버전 glances 등) 및 임시 프로세스 완전 정리
# - 패키지 캐시 및 시스템 저널 로그 정리 (journalctl 100MB 제한)
# - LXC 107 Docker 미사용 찌꺼기 캐시 정리
# - 전체 6대 컨테이너/VM 및 5대 디스크 자원 상태 종합 리포트 출력
# ==============================================================================

set -e

GREEN='\033[1;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}[ERROR]${NC} 이 스크립트는 Proxmox 호스트의 root 권한으로 실행해야 합니다."
    exit 1
fi

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}    Proxmox VE 시스템 자원 점검 및 불필요 프로세스 정리  ${NC}"
echo -e "${GREEN}====================================================${NC}"

# 1. 불필요한 레거시 프로세스 및 데몬 정리
log_info "1. 불필요한 레거시 백그라운드 서비스 정리 중..."
if systemctl is-active --quiet glances-server.service 2>/dev/null; then
    systemctl stop glances-server.service 2>/dev/null || true
    systemctl disable glances-server.service 2>/dev/null || true
    rm -f /etc/systemd/system/glances-server.service
    systemctl daemon-reload
    log_ok "구버전 glances-server 데몬 정리 완료."
fi

# pkill로 남아있는 중복 파이썬 glances 프로세스 강제 정리
pkill -f "glances -w" 2>/dev/null || true

# 2. 패키지 캐시 및 저널 로그 청소
log_info "2. 호스트 시스템 캐시 및 로그 다이어트 중..."
apt-get autoremove -y -qq 2>/dev/null || true
apt-get clean 2>/dev/null || true
journalctl --vacuum-size=100M &>/dev/null || true
log_ok "호스트 시스템 캐시 및 로그 정리 완료."

# 3. LXC 107 (Homepage/Uptime Kuma) Docker 찌꺼기 캐시 청소
if pct status 107 &>/dev/null; then
    log_info "3. LXC 107 Docker 미사용 빌드 캐시 청소 중..."
    pct exec 107 -- docker system prune -f &>/dev/null || true
    log_ok "LXC 107 Docker 캐시 정리 완료."
fi

# 4. 종합 상태 리포트 출력
echo ""
echo -e "${CYAN}====================================================${NC}"
echo -e "${CYAN}             📊 전체 시스템 종합 진단 리포트            ${NC}"
echo -e "${CYAN}====================================================${NC}"

echo -e "${YELLOW}[1] 🖥️ 실행 중인 VM 및 LXC 컨테이너 현황:${NC}"
pct list
qm list

echo ""
echo -e "${YELLOW}[2] 🧠 호스트 메모리(RAM) 사용 현황:${NC}"
free -h | awk 'NR<=2 {print $0}'

echo ""
echo -e "${YELLOW}[3] 💾 물리 스토리지 파티션 용량 현황:${NC}"
df -h | grep -E "(/dev/mapper/pve-root|/mnt/pve/nas-backups|/mnt/intel-ssd)" || df -h /

echo ""
echo -e "${YELLOW}[4] 🌐 외부 열림 포트 및 리스닝 데몬 (포트 충돌 점검):${NC}"
ss -tulpn | grep -E "(8006|5000|9090|61208|3000|3001|2283|4747|8096|53)" | awk '{print $1, $5, $7}' | sort -u

echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN} ✅ 모든 불필요한 프로세스와 캐시가 깔끔하게 정리되었습니다! ${NC}"
echo -e "${GREEN}====================================================${NC}"
