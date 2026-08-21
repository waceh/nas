#!/usr/bin/env bash
# ==============================================================================
# Cockpit Web GUI & Storage S.M.A.R.T Manager Installer for Proxmox VE (self-nas)
# ==============================================================================
# - Proxmox 호스트(Debian 12)에 경량 Cockpit 시스템 및 스토리지 플러그인 설치
# - 5대 물리 디스크(710, 530, Gold, White 18T/8T) 온도 및 S.M.A.R.T 건강도 웹 GUI 제공
# - 웹 접속 포트: https://192.168.1.200:9090 (root 계정 로그인)
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

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}    Cockpit 웹 시스템 & 디스크 건강도 관리자 설치    ${NC}"
echo -e "${GREEN}====================================================${NC}"

log_info "1. Debian 12 패키지 저장소 갱신 중..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

log_info "2. Cockpit 및 스토리지(S.M.A.R.T) 패키지 설치 중..."
apt-get install -y -qq \
    cockpit \
    cockpit-storaged \
    smartmontools \
    udisks2 \
    lm-sensors

log_info "3. Cockpit 서비스 활성화 및 root 로그인 허용 설정 중..."
rm -f /etc/cockpit/disallowed-users
systemctl enable --now cockpit.socket
systemctl restart cockpit.socket cockpit udisks2 || true


log_ok "Cockpit 설치 및 서비스 기동 완료!"
echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e " 🖥️ Cockpit 웹 콘솔: ${BLUE}https://192.168.1.200:9090${NC} (또는 https://waceh.asuscomm.com:9090)"
echo -e " 🔑 로그인 계정:    Proxmox ${GREEN}root${NC} 계정 및 비밀번호"
echo -e " 💾 확인 가능 항목: 5대 디스크 실시간 온도, S.M.A.R.T 건강도, 불량 섹터, 시스템 로그"
echo -e "${GREEN}====================================================${NC}"
