#!/usr/bin/env bash
# ==============================================================================
# Homepage Dashboard Configuration Updater (self-nas)
# ==============================================================================
# - Waceh NAS 대시보드 문구 및 테마 적용
# - 미디어 + 인프라(Proxmox 8006, 헤놀로지 5000) 전체 외부 DDNS 직통 연결
# ==============================================================================

set -e

GREEN='\033[1;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $1"; }

if [ "$(id -u)" -ne 0 ]; then
    log_err "이 스크립트는 Proxmox 호스트의 root 권한으로 실행해야 합니다."
    exit 1
fi

CTID="${CTID:-107}"

if ! pct status "$CTID" &>/dev/null; then
    log_err "LXC 컨테이너 ${CTID} 가 존재하지 않습니다. 먼저 setup_homepage_lxc.sh 로 설치하세요."
    exit 1
fi

log_info "Homepage LXC (${CTID}) 대시보드 설정 업데이트 중..."

pct exec "$CTID" -- bash -c '
mkdir -p /opt/homepage/config

# 1. settings.yaml (사이트 제목 & 테마)
cat << "SETTINGS_EOF" > /opt/homepage/config/settings.yaml
title: Waceh NAS Dashboard
favicon: https://cdn-icons-png.flaticon.com/512/3208/3208726.png
theme: dark
color: slate
headerStyle: clean
language: ko
useEqualHeights: true
hideVersion: true
SETTINGS_EOF

# 2. widgets.yaml (상단 위젯 및 문구)
cat << "WIDGETS_EOF" > /opt/homepage/config/widgets.yaml
- greeting:
    text_size: xl
    text: "Waceh NAS & Media Hub"
- search:
    provider: google
    target: _blank
- resources:
    cpu: true
    memory: true
    disk: /
WIDGETS_EOF

# 3. services.yaml (전체 외부 DDNS 링크 + 내부 초고속 상태 점검)
cat << "SERVICES_EOF" > /opt/homepage/config/services.yaml
- 미디어 서비스 (Media Core):
    - Immich Photo:
        icon: immich.png
        href: http://waceh.asuscomm.com:2283
        description: AI 사진 백업 / 앨범 인식 (WD Gold 4TB)
        ping: http://192.168.1.103:2283
    - Gonic Music:
        icon: gonic.png
        href: http://waceh.asuscomm.com:4747
        description: 무손실 음악 스트리밍 / Amperfy (WD Gold 4TB)
        ping: http://192.168.1.104:4747
    - Jellyfin Video:
        icon: jellyfin.png
        href: http://waceh.asuscomm.com:8096
        description: iGPU QuickSync 4K 비디오 (WD White 18TB / 8TB)
        ping: http://192.168.1.105:8096

- 인프라 & 스토리지 (Infrastructure):
    - Proxmox VE:
        icon: proxmox.png
        href: https://waceh.asuscomm.com:8006
        description: 하이퍼바이저 호스트 (Intel 710 SSD OS)
        ping: https://192.168.1.200:8006
    - Xpenology DSM:
        icon: synology.png
        href: http://waceh.asuscomm.com:5000
        description: Pure Storage Core (Gold 4T + White 26T)
        ping: http://192.168.1.132:5000
SERVICES_EOF

# 불필요한 custom.js 정리
rm -f /opt/homepage/config/custom.js

# 4. docker compose restart
cd /opt/homepage && docker compose restart
'

log_ok "Homepage 대시보드 인프라 포함 전체 업데이트 완료!"
echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e " 1. 접속 URL: ${BLUE}http://waceh.asuscomm.com:3000${NC}"
echo -e " 2. 미디어 서비스: Immich(2283), Gonic(4747), Jellyfin(8096)"
echo -e " 3. 인프라 서비스: Proxmox(8006), Xpenology DSM(5000)"
echo -e "${GREEN}====================================================${NC}"
