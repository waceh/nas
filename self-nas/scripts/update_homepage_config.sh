#!/usr/bin/env bash
# ==============================================================================
# Homepage Dashboard Layout & 1-Row 3-Col Bookmarks Updater (self-nas)
# ==============================================================================
# - 1층: 💾 4-Tier 물리 스토리지 (이미지/위젯 에러 없는 순수 텍스트 5열 카드)
# - 2층: 🎬 미디어 서비스 (1줄 3칸)
# - 3층: 🛠️ 인프라 & 스토리지 (1줄 2칸)
# - 4층: 🌐 Developer | Social | YouTube (1줄 3칸 나란히 배치)
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

CTID="${CTID:-107}"
CONF_FILE="/etc/pve/lxc/${CTID}.conf"

if ! pct status "$CTID" &>/dev/null; then
    log_err "LXC 컨테이너 ${CTID} 가 존재하지 않습니다."
    exit 1
fi

log_info "Proxmox 호스트 하드웨어 자원 설정 확인 중..."

NEED_REBOOT=0

# 1. 호스트 물리 SSD 전체 루트(/) 바인드 마운트 주입
if ! grep -q "mp0:" "$CONF_FILE"; then
    echo "mp0: /,mp=/mnt/intel-ssd,ro=1" >> "$CONF_FILE"
    NEED_REBOOT=1
fi

# 2. 호스트 실제 전체 CPU(6코어) 및 전체 16GB RAM 정보 주입
if ! grep -q "proc/meminfo" "$CONF_FILE"; then
cat << 'PVE_EOF' >> "$CONF_FILE"
lxc.mount.entry: /proc/meminfo proc/meminfo none bind,ro,create=file 0 0
lxc.mount.entry: /proc/stat proc/stat none bind,ro,create=file 0 0
lxc.mount.entry: /proc/cpuinfo proc/cpuinfo none bind,ro,create=file 0 0
PVE_EOF
    NEED_REBOOT=1
fi

# 바인드 마운트 활성화를 위한 재부팅
if [ "$NEED_REBOOT" -eq 1 ]; then
    log_info "호스트 하드웨어 바인드 마운트 활성화를 위해 LXC ${CTID} 재부팅 중..."
    pct reboot "$CTID"
    sleep 5
fi

log_info "Homepage 대시보드 및 1줄 3칸 북마크(Developer | Social | YouTube) 적용 중..."

pct exec "$CTID" -- bash -c "
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

mkdir -p /opt/homepage/config

# 1. settings.yaml (스토리지 5열, 미디어 3열, 인프라 2열, 북마크 1줄 3열)
cat << 'SETTINGS_EOF' > /opt/homepage/config/settings.yaml
title: Waceh NAS Dashboard
favicon: https://cdn-icons-png.flaticon.com/512/3208/3208726.png
theme: dark
color: slate
headerStyle: clean
language: ko
useEqualHeights: true
hideVersion: true

layout:
  4-Tier 물리 스토리지:
    style: row
    columns: 5
  미디어 서비스:
    style: row
    columns: 3
  인프라 & 스토리지:
    style: row
    columns: 2
  Developer:
    style: row
    columns: 1
  Social:
    style: row
    columns: 1
  YouTube:
    style: row
    columns: 1
SETTINGS_EOF

# 2. widgets.yaml (상단 헤더: 인사말 + CPU/RAM/TIME + 검색바)
cat << 'WIDGETS_EOF' > /opt/homepage/config/widgets.yaml
- greeting:
    text_size: xl
    text: \"Waceh NAS & Media Hub\"

- resources:
    label: \"🖥️ 서버 하드웨어 전체 자원 (i5-9500T 6C / 16GB RAM)\"
    cpu: true
    memory: true
    uptime: true

- search:
    provider: google
    target: _blank
WIDGETS_EOF

# 3. services.yaml (1층: 텍스트 스토리지 5개 | 2층: 미디어 3개 | 3층: 인프라 2개)
cat << 'SERVICES_EOF' > /opt/homepage/config/services.yaml
- 4-Tier 물리 스토리지:
    - Host OS SSD:
        description: Intel 710 100G (OS 24.5G 여유)
    - 고속 컨테이너 풀:
        description: Intel 530 120G (LXC/DB 풀)
    - 라이프 & 미디어 허브:
        description: WD Gold 4TB (사진·음악 3.4T 여유)
    - PDS1 대용량 미디어:
        description: WD White 18TB (영화 6.8T 사용)
    - PDS2 보조 엔터:
        description: WD White 8TB (7.0T 여유)

- 미디어 서비스:
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

- 인프라 & 스토리지:
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

# 4. bookmarks.yaml (1줄 3칸: Developer | Social | YouTube)
cat << 'BOOKMARKS_EOF' > /opt/homepage/config/bookmarks.yaml
- Developer:
    - GitHub:
        - abbr: GH
          icon: github.png
          href: https://github.com/waceh

- Social:
    - Instagram:
        - abbr: IG
          icon: instagram.png
          href: https://www.instagram.com/legato____

- YouTube:
    - YouTube:
        - abbr: YT
          icon: youtube.png
          href: https://www.youtube.com/@mtk-ey
BOOKMARKS_EOF

# 5. custom.css (2층-3층-4층 사이의 과도한 공백 제거 및 컴팩트 스타일링)
cat << 'CSS_EOF' > /opt/homepage/config/custom.css
/* 그룹 및 카드 간 상하 여백 슬림화 */
.services-group, .group, section, div[class*="gap-"] {
  margin-bottom: 0.75rem !important;
}

/* 텍스트 디스크 카드 높이 및 패딩 컴팩트 정돈 */
div[class*="service-card"] {
  padding: 0.75rem !important;
}
CSS_EOF

# 6. docker-compose.yml 업데이트
if [ -f /opt/homepage/.htpasswd ] && [ -f /opt/homepage/nginx.conf ]; then
cat << 'COMPOSE_EOF' > /opt/homepage/docker-compose.yml
services:
  homepage:
    image: ghcr.io/gethomepage/homepage:latest
    container_name: homepage
    restart: unless-stopped
    expose:
      - 3000
    volumes:
      - /opt/homepage/config:/app/config
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - PUID=0
      - PGID=0
      - HOMEPAGE_ALLOWED_HOSTS=*

  auth-proxy:
    image: nginx:alpine
    container_name: auth-proxy
    restart: unless-stopped
    ports:
      - 3000:3000
    volumes:
      - /opt/homepage/nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - /opt/homepage/.htpasswd:/etc/nginx/.htpasswd:ro
    depends_on:
      - homepage
COMPOSE_EOF
else
cat << 'COMPOSE_EOF' > /opt/homepage/docker-compose.yml
services:
  homepage:
    image: ghcr.io/gethomepage/homepage:latest
    container_name: homepage
    restart: unless-stopped
    ports:
      - 3000:3000
    volumes:
      - /opt/homepage/config:/app/config
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - PUID=0
      - PGID=0
      - HOMEPAGE_ALLOWED_HOSTS=*
COMPOSE_EOF
fi

cd /opt/homepage
docker compose down
docker compose up -d --force-recreate
"

log_ok "1줄 3칸 북마크(Developer | Social | YouTube) 적용 완료!"
echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e " 💾 [1층]: 4-Tier 물리 스토리지 (깔끔한 텍스트 1줄 5칸)"
echo -e " 🎬 [2층]: 미디어 서비스 (1줄 3칸)"
echo -e " 🛠️ [3층]: 인프라 & 스토리지 (1줄 2칸)"
echo -e " 🌐 [4층]: Developer (GitHub) | Social (Instagram) | YouTube (1줄 3칸)"
echo -e " 🌐 접속 주소: ${BLUE}http://waceh.asuscomm.com:3000${NC}"
echo -e "${GREEN}====================================================${NC}"
