#!/usr/bin/env bash
# ==============================================================================
# Homepage Dashboard Proxmox Native LXC Installer (self-nas)
# ==============================================================================
# - LXC 107 생성 (Debian 12, 1 Core, 512MB RAM, 4GB SSD Root on local-530)
# - Docker 및 Homepage 공식 최신 이미지 자동 배포
# - 1층: 💾 4-Tier 물리 스토리지 (GB/TB 단위 통일, Intel 710 LVM 70GB 예약 명시)
# - 2층: 🎬 미디어 서비스 (1줄 3칸)
# - 3층: 🛠️ 인프라 & 스토리지 (1줄 2칸)
# - 4층: 🌐 Developer & Social (GitHub, Instagram, YouTube 1줄 3칸 일렬 배치)
# - Immich, Gonic, Jellyfin, Proxmox, 헤놀로지 통합 대시보드 자동 사전구성
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
HOSTNAME="${HOSTNAME:-homepage-dashboard}"
CORES="${CORES:-1}"
RAM="${RAM:-512}"
SWAP="${SWAP:-256}"
DISK_SIZE="${DISK_SIZE:-4}"
STORAGE="${STORAGE:-local-530}"
BRIDGE="${BRIDGE:-vmbr0}"
IP_ADDR="${IP_ADDR:-192.168.1.107/24}"
GATEWAY="${GATEWAY:-192.168.1.1}"
NAS_IP="${NAS_IP:-192.168.1.132}"

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}      Homepage Dashboard LXC 자동 설치기            ${NC}"
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

# 3. LXC 107 생성 (Intel 530 SSD local-530 위)
log_info "LXC ${CTID} (${HOSTNAME}) 생성 중..."
pct create "$CTID" "$TEMPLATE" \
  --hostname "$HOSTNAME" \
  --cores "$CORES" \
  --memory "$RAM" \
  --swap "$SWAP" \
  --rootfs "${STORAGE}:${DISK_SIZE}" \
  --net0 name=eth0,bridge="${BRIDGE}",ip="${IP_ADDR}",gw="${GATEWAY}" \
  --unprivileged 0 \
  --features nesting=1,keyctl=1 \
  --mp0 /,mp=/mnt/intel-ssd,ro=1 \
  --tags "dashboard,web" \
  --onboot 1

# 호스트 전체 6코어 CPU 및 전체 16GB RAM 패스스루
cat << 'PVE_EOF' >> "/etc/pve/lxc/${CTID}.conf"
lxc.mount.entry: /proc/meminfo proc/meminfo none bind,ro,create=file 0 0
lxc.mount.entry: /proc/stat proc/stat none bind,ro,create=file 0 0
lxc.mount.entry: /proc/cpuinfo proc/cpuinfo none bind,ro,create=file 0 0
PVE_EOF

pct start "$CTID"
log_ok "LXC ${CTID} 생성 및 시작 완료!"

# 4. 네트워크 대기
sleep 5

# 5. 패키지 설치, NFS 용량 마운트 및 Homepage 구성 (LXC 내부)
log_info "LXC 내부 Docker 설치 및 Homepage 대시보드 사전 설정 중..."
pct exec "$CTID" -- bash -c "
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl ca-certificates gnupg

if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi

mkdir -p /opt/homepage/config

# 1. settings.yaml (스토리지 5열, 미디어 3열, 인프라 2열, 소셜 3열 완벽 통일)
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
  Developer & Social:
    style: row
    columns: 3
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

# 3. services.yaml (스토리지 5개, 미디어 3개, 인프라 2개, 소셜/개발자 3개 통합)
cat << 'SERVICES_EOF' > /opt/homepage/config/services.yaml
- 4-Tier 물리 스토리지:
    - Intel 710 100GB (24.5GB 여유):
        description: Host OS (Proxmox / LVM 70GB 예약)
    - Intel 530 120GB (98.0GB 여유):
        description: VM / LXC / DB 풀
    - WD Gold 4TB (3.4TB 여유):
        description: 사진(Immich), 음악(Gonic), 영상
    - WD White 18TB (9.2TB 여유):
        description: PDS1 (Cold Storage / Jellyfin)
    - WD White 8TB (7.0TB 여유):
        description: PDS2 (Cold Storage / Jellyfin)

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
        description: Pure Storage Core (Gold 4TB + White 26TB Btrfs)
        ping: http://192.168.1.132:5000

- Developer & Social:
    - GitHub:
        icon: github.png
        href: https://github.com/waceh
        description: github.com/waceh
    - Instagram:
        icon: instagram.png
        href: https://www.instagram.com/legato____
        description: @legato____
    - YouTube:
        icon: youtube.png
        href: https://www.youtube.com/@mtk-ey
        description: @mtk-ey
SERVICES_EOF

# 4. custom.css (슬림한 여백과 카드 정돈)
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

# 5. docker-compose.yml 생성
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

cd /opt/homepage
docker compose up -d --force-recreate
"

# 6. 호스트 부팅 및 종료 순서 설정
pct set "$CTID" --startup "order=2,up=5,down=10"

echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}     Homepage Dashboard (${CTID}) 설치 완료!         ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e " 1. 접속 URL: ${BLUE}http://${IP_ADDR%/*}:3000${NC} 또는 ${BLUE}http://waceh.asuscomm.com:3000${NC}"
echo -e " 2. 💾 [1층]: 4-Tier 물리 스토리지 (GB/TB 단위, 710 LVM 70GB 예약 명시)"
echo -e " 3. 🎬 [2층]: 미디어 서비스 (1줄 3칸)"
echo -e " 4. 🛠️ [3층]: 인프라 & 스토리지 (1줄 2칸)"
echo -e " 5. 🌐 [4층]: Developer & Social (GitHub | Instagram | YouTube 1줄 3칸)"
echo -e " 6. 설정 파일 위치: LXC ${CTID} 내부 ${GREEN}/opt/homepage/config/${NC}"
echo -e "${GREEN}====================================================${NC}"
