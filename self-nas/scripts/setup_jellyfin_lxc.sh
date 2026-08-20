#!/usr/bin/env bash
# ==============================================================================
# Jellyfin Media Server Proxmox Native LXC Installer (self-nas)
# ==============================================================================
# - LXC 105 생성 (Debian 12, 2 Core, 2GB RAM, 12GB SSD Root)
# - Intel UHD 630 iGPU QuickSync 하드웨어 트랜스코딩 가속 패스스루 (/dev/dri)
# - 헤놀로지 4TB Gold NFS (/volume2/video) -> /mnt/video 자동 영구 마운트
# - Jellyfin 공식 최신 버전 자동 설치
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

CTID="${CTID:-105}"
HOSTNAME="${HOSTNAME:-jellyfin-server}"
CORES="${CORES:-2}"
RAM="${RAM:-2048}"
SWAP="${SWAP:-512}"
DISK_SIZE="${DISK_SIZE:-12}"
STORAGE="${STORAGE:-local-530}"
BRIDGE="${BRIDGE:-vmbr0}"
IP_ADDR="${IP_ADDR:-192.168.1.105/24}"
GATEWAY="${GATEWAY:-192.168.1.1}"
NAS_IP="${NAS_IP:-192.168.1.132}"
NFS_SHARE="${NFS_SHARE:-/volume1/video}"

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}      Jellyfin Media Server LXC 자동 설치기         ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo "컨테이너 ID: ${CTID}"
echo "호스트명: ${HOSTNAME}"
echo "IP 주소: ${IP_ADDR}"
echo "스토리지 풀: ${STORAGE}"
echo "iGPU HW 가속: Intel UHD Graphics 630 (/dev/dri)"
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
    log_err "CTID ${CTID} 가 이미 존재합니다. 삭제 후 다시 실행하거나 다른 ID를 지정하세요."
    exit 1
fi

# 3. LXC 105 생성 (iGPU 패스스루를 위해 unprivileged 0 사용)
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

# 4. Intel iGPU (/dev/dri) 패스스루 설정 주입
log_info "Intel UHD 630 iGPU 패스스루 설정 주입 중..."
CONF_FILE="/etc/pve/lxc/${CTID}.conf"
if ! grep -q "dev/dri" "$CONF_FILE"; then
cat << 'EOF' >> "$CONF_FILE"
lxc.cgroup2.devices.allow: c 226:0 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
EOF
fi

pct start "$CTID"
log_ok "LXC ${CTID} 생성 및 시작 완료 (iGPU 연동 완료)!"

# 5. 네트워크 대기
sleep 5

# 6. 패키지 설치 및 NFS 마운트, Jellyfin 공식 설치 (LXC 내부)
log_info "LXC 내부 패키지 설치 및 Jellyfin 설치 중..."
pct exec "$CTID" -- bash -c "
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq nfs-common curl ca-certificates gnupg

  # RAM 디스크(/dev/shm) 트랜스코딩 캐시 디렉터리 생성
  mkdir -p /dev/shm/jellyfin-transcodes
  chmod 777 /dev/shm/jellyfin-transcodes

  # 4TB Gold video NFS 마운트 (nolock으로 안전 마운트)
  mkdir -p /mnt/video
  if ! grep -q '${NAS_IP}:${NFS_SHARE}' /etc/fstab; then
    echo '${NAS_IP}:${NFS_SHARE} /mnt/video nfs defaults,_netdev,nolock 0 0' >> /etc/fstab
  fi
  mount -a || true

  # Jellyfin 공식 설치 스크립트 비대화형 실행
  curl -fsSL https://repo.jellyfin.org/install-debuntu.sh | bash
"

# 7. 호스트 부팅 및 종료 순서 설정 (헤놀로지 101 다음 기동, 종료 시 15초 Graceful Shutdown 대기)
pct set "$CTID" --startup "order=2,up=10,down=15"

echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}      Jellyfin Server (${CTID}) 설치 완료!          ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e " 1. 로컬 접속: ${BLUE}http://${IP_ADDR%/*}:8096${NC}"
echo -e " 2. 외부 접속: ${BLUE}http://your-domain.asuscomm.com:8096${NC} (공유기 8096 포트포워딩 후)"
echo -e " 3. 미디어 저장 위치: ${GREEN}${NAS_IP}:${NFS_SHARE} (/mnt/video)${NC}"
echo -e " 4. 웹 접속 후: 라이브러리 경로로 ${GREEN}/mnt/video${NC} 지정"
echo -e "    대시보드 ➔ 재생 ➔ 하드웨어 가속: ${GREEN}Intel QuickSync (QSV)${NC} 활성화"
echo -e "${GREEN}====================================================${NC}"
