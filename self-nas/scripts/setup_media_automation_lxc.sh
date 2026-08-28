#!/usr/bin/env bash
# ==============================================================================
# Jellyseerr & qBittorrent-nox Proxmox Native LXC Installer (self-nas)
# ==============================================================================
# - LXC 109 생성 (Debian 12, 2 Core, 1024MB RAM, 8GB SSD Root on local-530)
# - Docker 및 Jellyseerr + qBittorrent-nox 공식 최신 이미지 자동 배포
# - '스마트 버퍼링(Smart Buffering)' 아키텍처 자동 구성:
#     1) 1차 다운로드 버퍼: WD Gold 4TB (/volume1/temp -> /mnt/temp)
#     2) 최종 저장소: WD White 18TB/8TB (/volume2/PDS1, /volume3/PDS2 -> /mnt/pds1, /mnt/pds2)
#     ➔ 26TB White 대용량 하드의 불필요한 스핀업 방지 및 수명 극대화!
# - 웹 포트:
#     - Jellyseerr (미디어 탐색/원클릭 요청 UI): http://192.168.1.109:5055
#     - qBittorrent (스마트 백그라운드 다운로더): http://192.168.1.109:8080
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
RAM="${RAM:-1024}"
SWAP="${SWAP:-512}"
DISK_SIZE="${DISK_SIZE:-8}"
STORAGE="${STORAGE:-local-530}"
BRIDGE="${BRIDGE:-vmbr0}"
IP_ADDR="${IP_ADDR:-192.168.1.109/24}"
GATEWAY="${GATEWAY:-192.168.1.1}"
NAS_IP="${NAS_IP:-192.168.1.132}"

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}  Jellyseerr & qBittorrent LXC 자동 설치기         ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo "컨테이너 ID: ${CTID}"
echo "호스트명: ${HOSTNAME}"
echo "IP 주소: ${IP_ADDR}"
echo "스토리지 풀: ${STORAGE}"
echo "NAS (NFS) IP: ${NAS_IP}"
echo "===================================================="

# 1. Debian 12 템플릿 준비
TEMPLATE=$(pveam list local | grep -E "debian-12-standard" | awk '{print $1}' | head -n 1 || true)
if [ -z "$TEMPLATE" ]; then
    log_info "Debian 12 표준 템플릿 다운로드 중..."
    pveam update
    pveam download local debian-12-standard_12.7-1_amd64.tar.zst || pveam download local $(pveam available | grep debian-12 | awk '{print $2}' | head -n 1)
    TEMPLATE=$(pveam list local | grep -E "debian-12-standard" | awk '{print $1}' | head -n 1)
fi

# 2. 기존 컨테이너 확인 및 정리
if pct status "$CTID" &>/dev/null; then
    log_info "기존 CTID ${CTID} 컨테이너 정리 중..."
    pct stop "$CTID" --force &>/dev/null || true
    pct destroy "$CTID" --purge --force &>/dev/null || true
fi

# 3. LXC 109 생성 (Intel 530 SSD local-530 위)
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
  --tags "media,automation,download" \
  --onboot 1

pct start "$CTID"
log_ok "LXC ${CTID} 생성 및 시작 완료!"

# 4. 네트워크 안정화 대기
sleep 5

# 5. 패키지 설치 및 Docker + NFS + 스택 배포 (LXC 내부)
log_info "LXC 내부 Docker 설치 및 Jellyseerr + qBittorrent 스택 구성 중..."
pct exec "$CTID" -- bash -c "
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl ca-certificates gnupg nfs-common

# Docker 공식 저장소 설치
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
chmod a+r /etc/apt/keyrings/docker.gpg

echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \$(. /etc/os-release && echo \"\$VERSION_CODENAME\") stable\" > /etc/apt/sources.list.d/docker.list

apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# NFS 마운트 디렉토리 생성
mkdir -p /mnt/temp /mnt/video /mnt/pds1 /mnt/pds2 /opt/media-stack/jellyseerr_config /opt/media-stack/qbittorrent_config

# /etc/fstab NFS 자동 마운트 등록
if ! grep -q \"/mnt/temp\" /etc/fstab; then
    echo \"${NAS_IP}:/volume1/temp /mnt/temp nfs defaults,nofail,bg,intr,vers=4.1 0 0\" >> /etc/fstab
fi
if ! grep -q \"/mnt/video\" /etc/fstab; then
    echo \"${NAS_IP}:/volume1/video /mnt/video nfs defaults,nofail,bg,intr,vers=4.1 0 0\" >> /etc/fstab
fi
if ! grep -q \"/mnt/pds1\" /etc/fstab; then
    echo \"${NAS_IP}:/volume2/PDS1 /mnt/pds1 nfs defaults,nofail,bg,intr,vers=4.1 0 0\" >> /etc/fstab
fi
if ! grep -q \"/mnt/pds2\" /etc/fstab; then
    echo \"${NAS_IP}:/volume3/PDS2 /mnt/pds2 nfs defaults,nofail,bg,intr,vers=4.1 0 0\" >> /etc/fstab
fi

mount -a || true

# Docker Compose 스택 정의
cat << 'EOF' > /opt/media-stack/docker-compose.yml
services:
  # 1. Jellyseerr (넷플릭스 스타일 미디어 탐색 및 원클릭 요청 UI)
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

  # 2. qBittorrent-nox (스마트 백그라운드 다운로더)
  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    restart: unless-stopped
    ports:
      - "8080:8080"
      - "6881:6881"
      - "6881:6881/udp"
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Seoul
      - WEBUI_PORT=8080
      - TORRENTING_PORT=6881
    volumes:
      - /opt/media-stack/qbittorrent_config:/config
      # 1차 버퍼링 폴더 (WD Gold 4TB - 자잘한 조각 파일 쓰기 전담, 26TB White 하드 스핀다운 100% 보존)
      - /mnt/temp:/downloads/temp
      # 최종 미디어 폴더 (WD Gold 4TB / WD White 18TB / WD White 8TB)
      - /mnt/video:/downloads/video
      - /mnt/pds1:/downloads/pds1
      - /mnt/pds2:/downloads/pds2
EOF

cd /opt/media-stack
docker compose pull
docker compose up -d --remove-orphans
"

# 6. 부팅 우선순위 설정 (Order 3)
pct set "$CTID" --startup "order=3,up=10,down=20"

IP_CLEAN="${IP_ADDR%/*}"

echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}  Jellyseerr & qBittorrent 스택 구축이 완료되었습니다!   ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e " 1. 🍿 Jellyseerr (요청 UI):   ${BLUE}http://${IP_CLEAN}:5055${NC}"
echo -e "    - 초기 설정 시 Jellyfin URL: http://192.168.1.105:8096 입력"
echo -e " 2. ⚡ qBittorrent (다운로더): ${BLUE}http://${IP_CLEAN}:8080${NC}"
echo -e "    - 기본 계정: admin / 초기 임시 비밀번호는 컨테이너 로그 확인"
echo -e "      (로그 확인: pct exec ${CTID} -- docker logs qbittorrent | grep \"temporary password\")"
echo -e " 3. 💾 스마트 버퍼링 스토리지 구성:"
echo -e "    - 1차 임시 버퍼: /downloads/temp (WD Gold 4TB)"
echo -e "    - 4K 영화 보관소: /downloads/pds1 (WD White 18TB)"
echo -e "    - TV/애니 보관소: /downloads/pds2 (WD White 8TB)"
echo -e "${GREEN}====================================================${NC}"
