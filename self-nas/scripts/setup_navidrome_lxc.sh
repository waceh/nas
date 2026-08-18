#!/usr/bin/env bash
# ==============================================================================
# Navidrome Music Server Proxmox Native LXC Installer (self-nas)
# ==============================================================================
# - LXC 104 생성 (Debian 12, 1 Core, 512MB RAM, 8GB SSD Root)
# - 헤놀로지 4TB Gold NFS (/volume1/music) -> /mnt/music 자동 영구 마운트
# - Navidrome 초경량(50MB RAM) 음악 스트리밍 서버 자동 설치 및 systemd 등록
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

CTID="${CTID:-104}"
HOSTNAME="${HOSTNAME:-navidrome-server}"
CORES="${CORES:-1}"
RAM="${RAM:-512}"
SWAP="${SWAP:-256}"
DISK_SIZE="${DISK_SIZE:-8}"
STORAGE="${STORAGE:-local-530}"
BRIDGE="${BRIDGE:-vmbr0}"
IP_ADDR="${IP_ADDR:-192.168.1.104/24}"
GATEWAY="${GATEWAY:-192.168.1.1}"
NAS_IP="${NAS_IP:-192.168.1.132}"
NFS_SHARE="${NFS_SHARE:-/volume1/music}"

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}      Navidrome Music Server LXC 자동 설치기        ${NC}"
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

# 3. LXC 104 생성 (Intel 530 SSD local-530 위)
log_info "LXC ${CTID} (${HOSTNAME}) 생성 중..."
pct create "$CTID" "$TEMPLATE" \
  --hostname "$HOSTNAME" \
  --cores "$CORES" \
  --memory "$RAM" \
  --swap "$SWAP" \
  --rootfs "${STORAGE}:${DISK_SIZE}" \
  --net0 name=eth0,bridge="${BRIDGE}",ip="${IP_ADDR}",gw="${GATEWAY}" \
  --unprivileged 0 \
  --features nesting=1 \
  --onboot 1

pct start "$CTID"
log_ok "LXC ${CTID} 생성 및 시작 완료!"

# 4. 네트워크 대기
sleep 5

# 5. 패키지 설치, NFS 마운트 및 Navidrome 배포 (LXC 내부)
log_info "LXC 내부 패키지 설치 및 Navidrome 음악 서버 구성 중..."
pct exec "$CTID" -- bash -c "
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq nfs-common curl ffmpeg

  # 4TB Gold music NFS 마운트
  mkdir -p /mnt/music
  if ! grep -q '${NAS_IP}:${NFS_SHARE}' /etc/fstab; then
    echo '${NAS_IP}:${NFS_SHARE} /mnt/music nfs defaults,_netdev 0 0' >> /etc/fstab
  fi
  mount -a || true

  # Navidrome 최신 바이너리 설치
  mkdir -p /opt/navidrome /var/lib/navidrome
  cd /opt/navidrome

  LATEST_TAG=\$(curl -sfL -w '%{url_effective}' -o /dev/null https://github.com/navidrome/navidrome/releases/latest | awk -F'/' '{print \$NF}')
  ARCH=\$(dpkg --print-architecture)

  curl -fsSL \"https://github.com/navidrome/navidrome/releases/download/\${LATEST_TAG}/navidrome_\${LATEST_TAG#v}_linux_\${ARCH}.tar.gz\" -o navidrome.tar.gz
  tar -xzf navidrome.tar.gz
  rm -f navidrome.tar.gz

  # 설정 파일 생성
  cat << 'CFG' > /var/lib/navidrome/navidrome.toml
MusicFolder = \"/mnt/music\"
DataFolder = \"/var/lib/navidrome\"
Address = \"0.0.0.0\"
Port = 4533
ScanSchedule = \"@every 1m\"
SessionTimeout = \"24h\"
CFG

  # systemd 서비스 등록
  cat << 'SVC' > /etc/systemd/system/navidrome.service
[Unit]
Description=Navidrome Music Server and Streamer
After=remote-fs.target network.target
AssertPathExists=/var/lib/navidrome

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/var/lib/navidrome
ExecStart=/opt/navidrome/navidrome --configfile /var/lib/navidrome/navidrome.toml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVC

  systemctl daemon-reload
  systemctl enable --now navidrome
"

echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}      Navidrome Server (${CTID}) 설치 완료!         ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e " 1. 로컬 웹 접속: ${BLUE}http://${IP_ADDR%/*}:4533${NC}"
echo -e " 2. 외부 접속: ${BLUE}http://your-domain.asuscomm.com:4533${NC} (공유기 4533 포트포워딩 후)"
echo -e " 3. 음악 원본 저장 위치: ${GREEN}${NAS_IP}:${NFS_SHARE} (/mnt/music)${NC}"
echo -e " 4. 추천 모바일 앱: Symfonium(안드로이드), Amperfy/play:Sub/Finamp(iOS), CarPlay 지원"
echo -e "${GREEN}====================================================${NC}"
