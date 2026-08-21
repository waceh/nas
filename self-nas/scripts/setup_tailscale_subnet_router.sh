#!/usr/bin/env bash
# ==============================================================================
# Tailscale WireGuard Hybrid Subnet Router Installer for Proxmox VE (self-nas)
# ==============================================================================
# - Proxmox 호스트를 초고속 WireGuard 암호화 서브넷 라우터(192.168.1.0/24)로 구축
# - 외부 어디서나 Tailscale 앱 하나로 집안 내부 IP(192.168.1.xxx) 원터치 0초 접속
# - 관리자 핵심 포트(PVE 8006, DSM 5000, Cockpit 9090, SSH 22) 외부 완전 은폐
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
log_err()  { echo -e "${RED}[ERROR]${NC} $1"; }

if [ "$(id -u)" -ne 0 ]; then
    log_err "이 스크립트는 Proxmox 호스트의 root 권한으로 실행해야 합니다."
    exit 1
fi

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}  Proxmox VE Tailscale WireGuard 서브넷 라우터 구축  ${NC}"
echo -e "${GREEN}====================================================${NC}"

# 1. 커널 IP 포워딩 활성화
log_info "1. 커널 IP 포워딩(IPv4 Forwarding) 활성화 중..."
cat << 'SYSCTL_EOF' > /etc/sysctl.d/99-tailscale.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
SYSCTL_EOF

sysctl -p /etc/sysctl.d/99-tailscale.conf &>/dev/null || true
log_ok "커널 IP 포워딩 활성화 완료."

# 2. Tailscale 공식 패키지 설치
log_info "2. Tailscale 공식 저장소 등록 및 패키지 설치 중..."
export DEBIAN_FRONTEND=noninteractive
curl -fsSL https://tailscale.com/install.sh | sh

systemctl enable --now tailscaled

log_ok "Tailscale 데몬 설치 완료!"
echo ""
echo -e "${CYAN}====================================================${NC}"
echo -e "${CYAN}      🔑 Tailscale 로그인 및 서브넷 라우터 활성화       ${NC}"
echo -e "${CYAN}====================================================${NC}"
echo -e "아래 명령어를 실행하여 출력되는 URL로 로그인해 주세요:"
echo ""
echo -e "  ${YELLOW}tailscale up --advertise-routes=192.168.1.0/24 --accept-routes${NC}"
echo ""
echo -e "로그인 후 Tailscale 관리자 콘솔(https://login.tailscale.com/admin/machines)에서"
echo -e "해당 기기의 ${BLUE}[Subnet Routes]${NC} ➔ ${GREEN}[192.168.1.0/24] 체크(Approve)${NC} 해주시면 완료됩니다!"
echo -e "${CYAN}====================================================${NC}"
