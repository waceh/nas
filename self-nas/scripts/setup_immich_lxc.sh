#!/usr/bin/env bash
# ==============================================================================
# Immich Photo Server Proxmox Native LXC Installer (self-nas)
# ==============================================================================
# - LXC 103 생성 (Debian 12, 2 Core, 4GB RAM, 16GB SSD Root)
# - 헤놀로지 4TB Gold NFS (/volume1/photo) -> /mnt/photo 자동 영구 마운트
# - Docker 및 Immich 최신 버전 자동 다운로드 및 배포
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

CTID="${CTID:-103}"
HOSTNAME="${HOSTNAME:-immich-server}"
CORES="${CORES:-2}"
RAM="${RAM:-4096}"
SWAP="${SWAP:-1024}"
DISK_SIZE="${DISK_SIZE:-16}"
STORAGE="${STORAGE:-local-530}"
BRIDGE="${BRIDGE:-vmbr0}"
IP_ADDR="${IP_ADDR:-192.168.1.103/24}"
GATEWAY="${GATEWAY:-192.168.1.1}"
NAS_IP="${NAS_IP:-192.168.1.132}"
NFS_SHARE="${NFS_SHARE:-/volume1/photo}"

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}      Immich Photo Server LXC 자동 설치기           ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo "컨테이너 ID: ${CTID}"
echo "호스트명: ${HOSTNAME}"
echo "IP 주소: ${IP_ADDR}"
echo "스토리지 풀: ${STORAGE}"
echo "NFS 스토리지: ${NAS_IP}:${NFS_SHARE}"
echo "===================================================="

# 1. Debian 12 템플릿 준비
TEMPLATE=$(pveam list local | grep -E "debian-12-standard" | awk '{print $1}' | head -n 1 || true)
if [ -z "$TEMPLATE" ]; then
    log_info "Debian 12 표준 템플릿 다운로드 중..."
    pveam update
    pveam download local debian-12-standard_12.7-1_amd64.tar.zst || pveam download local $(pveam available | grep debian-12 | awk '{print $2}' | head -n 1)
    TEMPLATE=$(pveam list local | grep -E "debian-12-standard" | awk '{print $1}' | head -n 1)
fi

# 2. 기존 컨테이너 확인
if pct status "$CTID" &>/dev/null; then
    log_info "기존 CTID ${CTID} 컨테이너 정리 중..."
    pct stop "$CTID" &>/dev/null || true
    pct destroy "$CTID" &>/dev/null || true
fi

# 3. LXC 103 생성 (Intel 530 SSD local-530 위)
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
  --onboot 1

pct start "$CTID"
log_ok "LXC ${CTID} 생성 및 시작 완료!"

# 4. 네트워크 대기
sleep 5

# 5. 패키지 설치 및 NFS 마운트, Docker 배포 (LXC 내부)
log_info "LXC 내부 패키지 설치 및 Docker/Immich 환경 구성 중..."
pct exec "$CTID" -- bash -c "
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq nfs-common curl ca-certificates gnupg

  # Docker 공식 원클릭 설치 (Docker Engine + Docker Compose Plugin)
  if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sh
  fi

  # 4TB Gold photo NFS 마운트 (NFSv4 + nolock 완벽 안정화)
  mkdir -p /mnt/photo
  if ! grep -q "${NAS_IP}:${NFS_SHARE}" /etc/fstab; then
    echo "${NAS_IP}:${NFS_SHARE} /mnt/photo nfs vers=4,nolock,defaults,_netdev 0 0" >> /etc/fstab
  fi
  systemctl daemon-reload
  mount -a || true

  # Immich Docker Compose 다운로드 & 설정
  mkdir -p /opt/immich && cd /opt/immich
  curl -fsSL https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml -o docker-compose.yml
  curl -fsSL https://github.com/immich-app/immich/releases/latest/download/example.env -o .env

  # 업로드 경로 및 DB 패스워드 설정
  sed -i 's|UPLOAD_LOCATION=.*|UPLOAD_LOCATION=/mnt/photo|g' .env
  sed -i 's|DB_PASSWORD=.*|DB_PASSWORD=immichpassword|g' .env

  docker compose up -d
"

# 6. 호스트 부팅 및 종료 순서 설정 (헤놀로지 101 다음 기동, 종료 시 15초 DB 플러시 대기)
pct set "$CTID" --startup "order=2,up=10,down=15"

echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}      Immich Server (${CTID}) 설치 완료!            ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e " 1. 로컬 접속: ${BLUE}http://${IP_ADDR%/*}:2283${NC}"
echo -e " 2. 외부 접속: ${BLUE}http://your-domain.asuscomm.com:2283${NC} (공유기 2283 포트포워딩 후)"
echo -e " 3. 사진 원본 저장 위치: ${GREEN}${NAS_IP}:${NFS_SHARE} (/mnt/photo)${NC}"
echo -e "${GREEN}====================================================${NC}"
