#!/usr/bin/env bash
# ==============================================================================
# Homepage Dashboard Configuration & Multi-Disk Monitor Updater (self-nas)
# ==============================================================================
# - 4-Tier 5대 디스크(Intel 530 SSD, WD Gold 4T, WD White 18T/8T) 실시간 용량 게이지 연동
# - Waceh NAS 대시보드 테마 및 외부 DDNS 직통 링크 유지
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
NAS_IP="${NAS_IP:-192.168.1.132}"

if ! pct status "$CTID" &>/dev/null; then
    log_err "LXC 컨테이너 ${CTID} 가 존재하지 않습니다. 먼저 setup_homepage_lxc.sh 로 설치하세요."
    exit 1
fi

log_info "Homepage LXC (${CTID})에 4-Tier 디스크 모니터링 및 대시보드 업데이트 적용 중..."

pct exec "$CTID" -- bash -c "
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq nfs-common

mkdir -p /opt/homepage/config /mnt/gold /mnt/pds1 /mnt/pds2

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

# 3. widgets.yaml (CPU/RAM + 4단 디스크 실시간 사용량 게이지)
cat << 'WIDGETS_EOF' > /opt/homepage/config/widgets.yaml
- greeting:
    text_size: xl
    text: \"Waceh NAS & Media Hub\"
- search:
    provider: google
    target: _blank
- resources:
    label: \"시스템 자원\"
    cpu: true
    memory: true
- resources:
    label: \"Intel 530 SSD (컨테이너/DB)\"
    disk: /
- resources:
    label: \"WD Gold 4TB (사진·영상·음악)\"
    disk: /mnt/gold
- resources:
    label: \"WD White 18TB (PDS1 콜드 미디어)\"
    disk: /mnt/pds1
- resources:
    label: \"WD White 8TB (PDS2 콜드 미디어)\"
    disk: /mnt/pds2
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

# 5. docker-compose.yml에 디스크 볼륨 마운트 반영
# (보안 프록시가 있으면 유지, 없으면 표준형)
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

log_ok "Homepage 디스크 모니터링 위젯 및 대시보드 업데이트 완료!"
echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e " 📊 대시보드 모니터링 디스크 목록:"
echo -e "   - Intel 530 SSD (/)"
echo -e "   - WD Gold 4TB (/mnt/gold)"
echo -e "   - WD White 18TB (/mnt/pds1)"
echo -e "   - WD White 8TB (/mnt/pds2)"
echo -e " 🌐 접속 주소: ${BLUE}http://waceh.asuscomm.com:3000${NC}"
echo -e "${GREEN}====================================================${NC}"
