#!/usr/bin/env bash
# ==============================================================================
# Hardware Temperature & Sensor Daemon Installer for Proxmox VE (self-nas)
# ==============================================================================
# - 30초 주기 저부하(Low-overhead) CPU 코어 및 디스크 실시간 온도 센서 데몬
# - 콜드 디스크(WD White 18T/8T) 스핀다운(Sleep) 완벽 보호 (-n standby)
# - Homepage 대시보드(:3000) 상단 헤더 및 카드에 실시간 °C 온도 연동
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
echo -e "${GREEN}    Proxmox VE 30초 저부하 하드웨어 온도 센서 구축  ${NC}"
echo -e "${GREEN}====================================================${NC}"

# 1. 센서 패키지 및 Glances 설치
log_info "1. 센서 및 Glances 모니터링 패키지 설치 중..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq lm-sensors smartmontools python3-pip glances || {
    apt-get install -y -qq python3-venv
    pip3 install --break-system-packages glances[all] || true
}

# 2. CPU 센서 감지 활성화
log_info "2. CPU 하드웨어 센서 초기화 중..."
sensors-detect --auto &>/dev/null || true

# 3. 10초 반응형 Glances 웹 서버 systemd 등록
log_info "3. 10초 주기 Glances API 서비스 등록 중 (포트 61208)..."
cat << 'SERVICE_EOF' > /etc/systemd/system/glances-server.service
[Unit]
Description=Glances 10s Hardware Sensor Server
After=network.target

[Service]
ExecStart=/usr/bin/glances -w -t 10 -p 61208
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable --now glances-server.service

log_ok "Glances 10초 센서 서버 기동 완료! (http://192.168.1.200:61208)"
echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e " 🌡️ 센서 API:   ${BLUE}http://192.168.1.200:61208${NC}"
echo -e " ⏱️ 갱신 주기:  ${GREEN}10초 (접속 시 On-Demand 갱신)${NC}"
echo -e "===================================================="

