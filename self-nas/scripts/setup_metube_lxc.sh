#!/usr/bin/env bash
# ==============================================================================
# MeTube (YouTube/Web Media & Music Downloader) LXC Installer (self-nas)
# ==============================================================================
# - LXC 107(Homepage 호스트) 또는 지정된 LXC에 MeTube 컨테이너를 배포
# - yt-dlp 기반 초고화질(4K/1080p) 영상 및 최고음질(MP3/FLAC) 원클릭 추출
# - 다운로드 경로: WD Gold 4TB NFS (/volume1/temp/downloads, /volume1/music, /volume1/video)
# - 웹 포트: http://192.168.1.107:8081 (소모 RAM: ~40MB)
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
PORT="${PORT:-8081}"
NAS_IP="${NAS_IP:-192.168.1.132}"

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}  MeTube 고화질 영상/음원 다운로더 LXC 배포기      ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo "대상 컨테이너 ID: ${CTID}"
echo "웹 접속 포트: ${PORT}"
echo "NAS (NFS) IP: ${NAS_IP}"
echo "===================================================="

if ! pct status "$CTID" &>/dev/null; then
    log_err "LXC 컨테이너 ${CTID} 가 존재하지 않습니다. 먼저 LXC 107을 배포해주세요."
    exit 1
fi

log_info "1. LXC ${CTID} DNS 및 필수 패키지 점검 (nfs-common, curl)..."
pct exec "$CTID" -- bash -c "
# DNS 리졸버 보완 (1.1.1.1, 8.8.8.8 추가)
if ! grep -q '1.1.1.1' /etc/resolv.conf; then
    echo 'nameserver 1.1.1.1' >> /etc/resolv.conf
fi
if ! grep -q '8.8.8.8' /etc/resolv.conf; then
    echo 'nameserver 8.8.8.8' >> /etc/resolv.conf
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update || true
apt-get install -y nfs-common curl ca-certificates || true

mkdir -p /mnt/gold-temp /mnt/gold-music /mnt/gold-video /opt/metube/data /opt/metube/downloads /opt/metube/audio

# 고성능 락프리 NFSv3 마운트 등록 (soft, timeo=30)
if ! grep -q \"/mnt/gold-temp\" /etc/fstab; then
    echo \"${NAS_IP}:/volume1/temp /mnt/gold-temp nfs defaults,_netdev,vers=3,nolock,soft,timeo=30,intr 0 0\" >> /etc/fstab
fi
if ! grep -q \"/mnt/gold-music\" /etc/fstab; then
    echo \"${NAS_IP}:/volume1/music /mnt/gold-music nfs defaults,_netdev,vers=3,nolock,soft,timeo=30,intr 0 0\" >> /etc/fstab
fi
if ! grep -q \"/mnt/gold-video\" /etc/fstab; then
    echo \"${NAS_IP}:/volume1/video /mnt/gold-video nfs defaults,_netdev,vers=3,nolock,soft,timeo=30,intr 0 0\" >> /etc/fstab
fi

mount -a || true
"

log_info "2. MeTube Docker Compose 설정 생성..."
pct exec "$CTID" -- bash -c "
cat << 'EOF' > /opt/metube/docker-compose.yml
services:
  metube:
    image: ghcr.io/alexta69/metube:latest
    container_name: metube
    restart: unless-stopped
    ports:
      - \"${PORT}:8081\"
    environment:
      UID: 1000
      GID: 1000
      DOWNLOAD_DIR: /downloads
      AUDIO_DOWNLOAD_DIR: /audio
      CUSTOM_DIRS: \"true\"
      STATE_DIR: /app/.metube
      OUTPUT_TEMPLATE: \"%(title)s.%(ext)s\"
      YTDL_OPTIONS: '{\"writesubtitles\": true, \"subtitleslangs\": [\"ko\", \"en\", \"all\"]}'
    volumes:
      - /opt/metube/downloads:/downloads
      - /opt/metube/audio:/audio
      - /opt/metube/data:/app/.metube
      - /mnt/gold-temp:/mnt/gold-temp
      - /mnt/gold-music:/mnt/gold-music
      - /mnt/gold-video:/mnt/gold-video
EOF
"

log_info "3. MeTube Docker 이미지 다운로드 및 기동 중..."
pct exec "$CTID" -- bash -c "
cd /opt/metube
docker compose pull
docker compose up -d --remove-orphans
"

log_info "4. MeTube 웹 UI 한국어 패치 주입 중..."
pct exec "$CTID" -- docker exec metube python3 -c '
import os
injector = """<script>
(function() {
  const dict = {
    "Add": "다운로드 추가",
    "Format": "포맷 선택",
    "Quality": "화질 / 음질",
    "Folder": "저장 폴더",
    "Advanced": "고급 옵션",
    "Downloads": "다운로드 목록",
    "Clear finished": "완료 목록 지우기",
    "Clear all": "전체 목록 지우기",
    "Theme": "화면 테마",
    "Dark": "어두운 테마 (Dark)",
    "Light": "밝은 테마 (Light)",
    "Auto": "자동 (Auto)",
    "Best": "최고화질 (Best)",
    "Audio": "음원 추출 (MP3/FLAC)",
    "Video": "동영상 (MP4/MKV)",
    "No downloads yet": "현재 진행 중인 다운로드가 없습니다",
    "URL": "유튜브/웹 영상 URL을 여기에 붙여넣으세요",
    "Enter URL": "유튜브/웹 영상 URL을 여기에 붙여넣으세요",
    "Active": "다운로드 중",
    "Completed": "완료됨",
    "Finished": "완료됨",
    "Queued": "대기 중",
    "Preparing": "다운로드 준비 중...",
    "Error": "다운로드 실패",
    "Options": "상세 옵션",
    "Custom arguments": "사용자 커스텀 인자",
    "Custom name": "저장할 파일명 직접 지정",
    "Any (video)": "동영상 (최고화질)",
    "Any (audio)": "음원 (최고음질)",
    "Cancel": "취소",
    "Retry": "재시도",
    "Delete": "삭제"
  };
  function translate(node) {
    if (!node) return;
    if (node.nodeType === 3) {
      let t = node.nodeValue.trim();
      if (dict[t]) node.nodeValue = node.nodeValue.replace(t, dict[t]);
    } else if (node.nodeType === 1) {
      if (node.placeholder && dict[node.placeholder]) node.placeholder = dict[node.placeholder];
      if (node.title && dict[node.title]) node.title = dict[node.title];
      if (node.tagName === "INPUT" && node.value && dict[node.value]) node.value = dict[node.value];
      for (let c of node.childNodes) translate(c);
    }
  }
  const obs = new MutationObserver(muts => {
    for (let m of muts) {
      if (m.type === "childList") {
        for (let a of m.addedNodes) translate(a);
      } else if (m.type === "characterData") {
        translate(m.target);
      }
    }
  });
  function start() {
    translate(document.body);
    obs.observe(document.body, { childList: true, subtree: true, characterData: true });
  }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start);
  } else {
    start();
  }
})();
</script>"""

for root, dirs, files in os.walk("/app"):
    for f in files:
        if f == "index.html":
            p = os.path.join(root, f)
            with open(p, "r", encoding="utf-8") as fp:
                c = fp.read()
            if "dict" not in c:
                if "</head>" in c:
                    c = c.replace("</head>", injector + "</head>")
                else:
                    c = c + injector
                with open(p, "w", encoding="utf-8") as fp:
                    fp.write(c)
'

log_ok "MeTube 한국어 UI 패치 및 컨테이너 배포 완료!"

IP_CLEAN=$(pct exec "$CTID" -- ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "192.168.1.107")

echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}  MeTube 웹 다운로더 배포가 성공적으로 완료되었습니다!  ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e " 🌐 웹 접속 URL: ${BLUE}http://${IP_CLEAN}:${PORT}${NC} 또는 ${BLUE}http://waceh.asuscomm.com:${PORT}${NC}"
echo -e " 📁 다운로드 기본 저장소: /downloads (및 /mnt/gold-temp, /mnt/gold-music, /mnt/gold-video 연동)"
echo -e " 💡 RAM 소모량: 약 40MB 내외 (초경량)"
echo -e "${GREEN}====================================================${NC}"
