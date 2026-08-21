#!/usr/bin/env bash
# ==============================================================================
# Homepage Dashboard 5-Disk Storage Tiering & Clean Row Layout (self-nas)
# ==============================================================================
# - 1층: CPU / RAM / UPTIME 시스템 핵심 자원 카드
# - 2층: 5대 물리 스토리지 (Intel 710, Intel 530, WD Gold, White 18T/8T) 통합 카드
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
NAS_IP="${NAS_IP:-192.168.1.132}"
CONF_FILE="/etc/pve/lxc/${CTID}.conf"

if ! pct status "$CTID" &>/dev/null; then
    log_err "LXC 컨테이너 ${CTID} 가 존재하지 않습니다."
    exit 1
fi

log_info "Proxmox 호스트 하드웨어 자원 및 5대 디스크 설정 주입 중..."

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

log_info "Homepage 대시보드 2단 분리(자원 / 스토리지) 레이아웃 적용 중..."

pct exec "$CTID" -- bash -c "
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq nfs-common

mkdir -p /opt/homepage/config /mnt/intel-ssd /mnt/gold /mnt/pds1 /mnt/pds2

# 1. NFS 락-프리 마운트 (용량 조회용)
cat << 'FSTAB_EOF' > /etc/fstab
${NAS_IP}:/volume1/video /mnt/gold nfs defaults,_netdev,vers=3,nolock,soft,timeo=30,intr,rsize=1048576,wsize=1048576 0 0
${NAS_IP}:/volume2/PDS1  /mnt/pds1 nfs defaults,_netdev,vers=3,nolock,soft,timeo=30,intr,rsize=1048576,wsize=1048576 0 0
${NAS_IP}:/volume3/PDS2  /mnt/pds2 nfs defaults,_netdev,vers=3,nolock,soft,timeo=30,intr,rsize=1048576,wsize=1048576 0 0
FSTAB_EOF

mount -a || true

# 2. settings.yaml (사이트 제목 & 테마)
cat << 'SETTINGS_EOF' > /opt/homepage/config/settings.yaml
title: Waceh NAS Dashboard
favicon: https://cdn-icons-png.flaticon.com/512/3208/3208726.png
theme: dark
color: slate
headerStyle: clean
language: ko
useEqualHeights: true
hideVersion: true
SETTINGS_EOF

# 3. widgets.yaml (1층: CPU/RAM/TIME + 2층: 5대 디스크 리스트 분리)
cat << 'WIDGETS_EOF' > /opt/homepage/config/widgets.yaml
- greeting:
    text_size: xl
    text: \"Waceh NAS & Media Hub\"

- search:
    provider: google
    target: _blank

- resources:
    label: \"🖥️ 서버 하드웨어 전체 자원 (i5-9500T 6C / 16GB RAM)\"
    cpu: true
    memory: true
    uptime: true

- resources:
    label: \"💾 5-Tier 물리 스토리지 풀 (SSD + HDD)\"
    disk:
      - /mnt/intel710
      - /mnt/intel530
      - /mnt/gold
      - /mnt/pds1
      - /mnt/pds2
WIDGETS_EOF

# 4. services.yaml (전체 외부 DDNS 링크 + 내부 초고속 상태 점검)
cat << 'SERVICES_EOF' > /opt/homepage/config/services.yaml
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

# 5. docker-compose.yml 업데이트 (5개 디스크 볼륨 마운트)
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
      - /:/mnt/intel530:ro
      - /mnt/intel-ssd:/mnt/intel710:ro
      - /mnt/gold:/mnt/gold:ro
      - /mnt/pds1:/mnt/pds1:ro
      - /mnt/pds2:/mnt/pds2:ro
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
      - /:/mnt/intel530:ro
      - /mnt/intel-ssd:/mnt/intel710:ro
      - /mnt/gold:/mnt/gold:ro
      - /mnt/pds1:/mnt/pds1:ro
      - /mnt/pds2:/mnt/pds2:ro
    environment:
      - PUID=0
      - PGID=0
      - HOMEPAGE_ALLOWED_HOSTS=*
COMPOSE_EOF
fi

cd /opt/homepage
docker compose up -d --force-recreate
"

log_ok "2단 분리 레이아웃 적용 완료!"
echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e " 🖥️ [1층] CPU / RAM / UPTIME 시스템 자원"
echo -e " 💾 [2층] 5-Tier 물리 스토리지 풀 (Intel 710/530, WD Gold, White 18T/8T)"
echo -e " 🌐 접속 주소: ${BLUE}http://waceh.asuscomm.com:3000${NC}"
echo -e "${GREEN}====================================================${NC}"
