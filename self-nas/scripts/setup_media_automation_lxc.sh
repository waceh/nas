#!/usr/bin/env bash
# ==============================================================================
# Full *Arr Media Automation Stack LXC Installer (self-nas)
# ==============================================================================
# - LXC 109 (Debian 12, 2 Core, 2048MB RAM, 8GB SSD Root on local-530)
# - 풀스택 구성:
#     1) 🍿 Jellyseerr (포트 5055): 넷플릭스 스타일 미디어 탐색 & 원클릭 요청 UI
#     2) 🤖 Radarr (포트 7878): 영화 자동 탐색, 한글 자막 매칭 및 26TB White(18TB) 자동 분류
#     3) 📺 Sonarr (포트 8989): 드라마/애니 방영 추적 및 26TB White(8TB) 자동 분류
#     4) 🔍 Prowlarr (포트 9696): 토렌트 인덱서/트래커 원클릭 자동 연동 허브
#     5) ⚡ qBittorrent (포트 8080): 스마트 버퍼링 다운로더 (WD Gold 4TB 1차 조각 쓰기 전담)
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

CTID="${CTID:-109}"
HOSTNAME="${HOSTNAME:-media-automation}"
CORES="${CORES:-2}"
RAM="${RAM:-2048}"
SWAP="${SWAP:-1024}"
DISK_SIZE="${DISK_SIZE:-8}"
STORAGE="${STORAGE:-local-530}"
BRIDGE="${BRIDGE:-vmbr0}"
IP_ADDR="${IP_ADDR:-192.168.1.109/24}"
GATEWAY="${GATEWAY:-192.168.1.1}"
NAS_IP="${NAS_IP:-192.168.1.132}"

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}  Jellyseerr + Radarr + Sonarr + Prowlarr + qBit    ${NC}"
echo -e "${GREEN}  미디어 완전 자동화 풀스택 배포기                  ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo "컨테이너 ID: ${CTID}"
echo "호스트명: ${HOSTNAME}"
echo "할당 RAM: ${RAM}MB (스택 최적화)"
echo "스토리지 풀: ${STORAGE}"
echo "NAS (NFS) IP: ${NAS_IP}"
echo "===================================================="

# 1. 기존 컨테이너 확인 (존재 시 메모리 확장 및 스택 업데이트 모드)
if pct status "$CTID" &>/dev/null; then
    log_info "기존 CTID ${CTID} 컨테이너 감지 ➔ 메모리(${RAM}MB) 확장 및 스택 업데이트 진행..."
    pct set "$CTID" --memory "$RAM" --swap "$SWAP" || true
    if [ "$(pct status "$CTID" | awk '{print $2}')" != "running" ]; then
        pct start "$CTID"
        sleep 3
    fi
else
    log_info "신규 LXC ${CTID} 생성 준비 중..."
    TEMPLATE=$(pveam list local | grep -E "debian-12-standard" | awk '{print $1}' | head -n 1 || true)
    if [ -z "$TEMPLATE" ]; then
        log_info "Debian 12 표준 템플릿 다운로드 중..."
        pveam update
        pveam download local debian-12-standard_12.7-1_amd64.tar.zst || pveam download local $(pveam available | grep debian-12 | awk '{print $2}' | head -n 1)
        TEMPLATE=$(pveam list local | grep -E "debian-12-standard" | awk '{print $1}' | head -n 1)
    fi

    pct create "$CTID" "$TEMPLATE" \
      --hostname "$HOSTNAME" \
      --cores "$CORES" \
      --memory "$RAM" \
      --swap "$SWAP" \
      --rootfs "${STORAGE}:${DISK_SIZE}" \
      --net0 name=eth0,bridge="${BRIDGE}",ip="${IP_ADDR}",gw="${GATEWAY}" \
      --unprivileged 0 \
      --features nesting=1,keyctl=1 \
      --tags "media,automation,arr-stack" \
      --onboot 1

    pct start "$CTID"
    log_ok "LXC ${CTID} 생성 완료!"
    sleep 5
fi

# 2. 패키지 및 Docker 엔진 점검 (LXC 내부)
log_info "LXC 내부 패키지 및 Docker 엔진 점검 중..."
pct exec "$CTID" -- bash -c "
# DNS 리졸버 보완
if ! grep -q '1.1.1.1' /etc/resolv.conf; then
    echo 'nameserver 1.1.1.1' >> /etc/resolv.conf
fi
if ! grep -q '8.8.8.8' /etc/resolv.conf; then
    echo 'nameserver 8.8.8.8' >> /etc/resolv.conf
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl ca-certificates gnupg nfs-common

if ! command -v docker &>/dev/null; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \$(. /etc/os-release && echo \"\$VERSION_CODENAME\") stable\" > /etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# NFS 마운트 디렉토리 및 앱 설정 폴더 생성
mkdir -p /mnt/temp /mnt/video /mnt/pds1 /mnt/pds2 \
         /opt/media-stack/jellyseerr_config \
         /opt/media-stack/radarr_config \
         /opt/media-stack/sonarr_config \
         /opt/media-stack/prowlarr_config \
         /opt/media-stack/qbittorrent_config/qBittorrent

# /etc/fstab 고성능 락프리 NFSv3 마운트 등록
if ! grep -q \"/mnt/temp\" /etc/fstab; then
    echo \"${NAS_IP}:/volume1/temp /mnt/temp nfs defaults,_netdev,vers=3,nolock,soft,timeo=30,intr 0 0\" >> /etc/fstab
fi
if ! grep -q \"/mnt/video\" /etc/fstab; then
    echo \"${NAS_IP}:/volume1/video /mnt/video nfs defaults,_netdev,vers=3,nolock,soft,timeo=30,intr 0 0\" >> /etc/fstab
fi
if ! grep -q \"/mnt/pds1\" /etc/fstab; then
    echo \"${NAS_IP}:/volume2/PDS1 /mnt/pds1 nfs defaults,_netdev,vers=3,nolock,soft,timeo=30,intr 0 0\" >> /etc/fstab
fi
if ! grep -q \"/mnt/pds2\" /etc/fstab; then
    echo \"${NAS_IP}:/volume3/PDS2 /mnt/pds2 nfs defaults,_netdev,vers=3,nolock,soft,timeo=30,intr 0 0\" >> /etc/fstab
fi

mount -a || true

mkdir -p /mnt/temp/torrents /mnt/video/downloads /mnt/pds1/Movies /mnt/pds2/TV || true
chmod -R 777 /mnt/temp /mnt/video /mnt/pds1 /mnt/pds2 /opt/media-stack 2>/dev/null || true

# qBittorrent 한국어 로케일 설정이 없으면 주입
if [ ! -f /opt/media-stack/qbittorrent_config/qBittorrent/qBittorrent.conf ]; then
cat << 'QBIT_CONF_EOF' > /opt/media-stack/qbittorrent_config/qBittorrent/qBittorrent.conf
[BitTorrent]
Session\DefaultSavePath=/downloads/temp
Session\Port=6881
Session\TempPath=/downloads/temp

[General]
Locale=ko

[Preferences]
General\Locale=ko
WebUI\Locale=ko
WebUI\Port=8080
QBIT_CONF_EOF
fi

# Docker Compose 풀스택 정의
cat << 'EOF' > /opt/media-stack/docker-compose.yml
services:
  # 1. Jellyseerr (미디어 탐색 및 원클릭 요청 UI)
  jellyseerr:
    image: fallenbagel/jellyseerr:latest
    container_name: jellyseerr
    restart: unless-stopped
    ports:
      - "5055:5055"
    environment:
      - LOG_LEVEL=debug
      - TZ=Asia/Seoul
    volumes:
      - /opt/media-stack/jellyseerr_config:/app/config

  # 2. Radarr (영화 자동 수집봇)
  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    restart: unless-stopped
    ports:
      - "7878:7878"
    environment:
      - PUID=0
      - PGID=0
      - UMASK=000
      - TZ=Asia/Seoul
    volumes:
      - /opt/media-stack/radarr_config:/config
      - /mnt/temp:/downloads/temp
      - /mnt/pds1:/pds1
      - /mnt/pds1:/movies
      - /mnt/pds2:/pds2
      - /mnt/video:/video

  # 3. Sonarr (TV 시리즈 / 드라마 자동 수집봇)
  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    restart: unless-stopped
    ports:
      - "8989:8989"
    environment:
      - PUID=0
      - PGID=0
      - UMASK=000
      - TZ=Asia/Seoul
    volumes:
      - /opt/media-stack/sonarr_config:/config
      - /mnt/temp:/downloads/temp
      - /mnt/pds1:/pds1
      - /mnt/pds1:/tv
      - /mnt/pds2:/pds2
      - /mnt/video:/video

  # 4. Prowlarr (토렌트 인덱서/트래커 자동 연동)
  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    restart: unless-stopped
    ports:
      - "9696:9696"
    environment:
      - PUID=0
      - PGID=0
      - UMASK=000
      - TZ=Asia/Seoul
    volumes:
      - /opt/media-stack/prowlarr_config:/config

  # 5. qBittorrent-nox (스마트 백그라운드 다운로더)
  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    restart: unless-stopped
    ports:
      - "8080:8080"
      - "6881:6881"
      - "6881:6881/udp"
    environment:
      - PUID=0
      - PGID=0
      - UMASK=000
      - TZ=Asia/Seoul
      - WEBUI_PORT=8080
      - TORRENTING_PORT=6881
    volumes:
      - /opt/media-stack/qbittorrent_config:/config
      - /mnt/temp:/downloads/temp
      - /mnt/video:/downloads/video
      - /mnt/pds1:/downloads/pds1
      - /mnt/pds2:/downloads/pds2
EOF
"

log_info "3. 풀스택 Docker 이미지 다운로드 및 서비스 기동 중..."
pct exec "$CTID" -- bash -c "
cd /opt/media-stack
docker compose pull
docker compose up -d --remove-orphans
"

pct set "$CTID" --startup "order=3,up=10,down=20"

IP_CLEAN="${IP_ADDR%/*}"

echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}  미디어 완전 자동화 풀스택 배포 완료!               ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e " 1. 🍿 Jellyseerr (요청 UI):   ${BLUE}http://${IP_CLEAN}:5055${NC}"
echo -e " 2. 🤖 Radarr     (영화 봇):   ${BLUE}http://${IP_CLEAN}:7878${NC}"
echo -e " 3. 📺 Sonarr     (드라마 봇): ${BLUE}http://${IP_CLEAN}:8989${NC}"
echo -e " 4. 🔍 Prowlarr   (토렌트 허브): ${BLUE}http://${IP_CLEAN}:9696${NC}"
echo -e " 5. ⚡ qBittorrent (다운로더): ${BLUE}http://${IP_CLEAN}:8080${NC}"
echo -e "${GREEN}====================================================${NC}"
