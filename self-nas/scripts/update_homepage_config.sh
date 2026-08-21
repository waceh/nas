#!/usr/bin/env bash
# ==============================================================================
# Homepage Dashboard Configuration Updater (self-nas)
# ==============================================================================
# - Waceh NAS 대시보드 문구 및 테마 적용
# - custom.js 주입: 클릭 이벤트 캡처 방식으로 내부망/외부망 접속 자동 감지 & URL 전환
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

if ! pct status "$CTID" &>/dev/null; then
    log_err "LXC 컨테이너 ${CTID} 가 존재하지 않습니다. 먼저 setup_homepage_lxc.sh 로 설치하세요."
    exit 1
fi

log_info "Homepage LXC (${CTID}) 대시보드 설정 업데이트 중..."

pct exec "$CTID" -- bash -c '
mkdir -p /opt/homepage/config

# 1. settings.yaml (사이트 제목 & 테마)
cat << "SETTINGS_EOF" > /opt/homepage/config/settings.yaml
title: Waceh NAS Dashboard
favicon: https://cdn-icons-png.flaticon.com/512/3208/3208726.png
theme: dark
color: slate
headerStyle: clean
language: ko
useEqualHeights: true
hideVersion: true
SETTINGS_EOF

# 2. widgets.yaml (상단 위젯 및 문구)
cat << "WIDGETS_EOF" > /opt/homepage/config/widgets.yaml
- greeting:
    text_size: xl
    text: "Waceh NAS & Media Hub"
- search:
    provider: google
    target: _blank
- resources:
    cpu: true
    memory: true
    disk: /
WIDGETS_EOF

# 3. services.yaml (서비스 목록 및 내부 상태 체크)
cat << "SERVICES_EOF" > /opt/homepage/config/services.yaml
- 미디어 서비스 (Media Core):
    - Immich Photo:
        icon: immich.png
        href: http://192.168.1.103:2283
        description: AI 사진 백업 / 앨범 인식 (WD Gold 4TB)
        ping: http://192.168.1.103:2283
    - Gonic Music:
        icon: gonic.png
        href: http://192.168.1.104:4747
        description: 무손실 음악 스트리밍 / Amperfy (WD Gold 4TB)
        ping: http://192.168.1.104:4747
    - Jellyfin Video:
        icon: jellyfin.png
        href: http://192.168.1.105:8096
        description: iGPU QuickSync 4K 비디오 (WD White 18TB / 8TB)
        ping: http://192.168.1.105:8096

- 인프라 & 스토리지 (Infrastructure):
    - Proxmox VE:
        icon: proxmox.png
        href: https://192.168.1.200:8006
        description: 하이퍼바이저 호스트 (Intel 710 SSD OS)
        ping: https://192.168.1.200:8006
    - Xpenology DSM:
        icon: synology.png
        href: http://192.168.1.132:5000
        description: Pure Storage Core (Gold 4T + White 26T)
        ping: http://192.168.1.132:5000
SERVICES_EOF

# 4. custom.js (강력한 클릭 가로채기 & DOM 자동 치환 엔진)
cat << "JS_EOF" > /opt/homepage/config/custom.js
(() => {
  const currentHost = window.location.hostname;
  // 외부 도메인(waceh.asuscomm.com 등)으로 접속한 경우에만 동작
  if (!currentHost || currentHost === "localhost" || currentHost.startsWith("192.168.") || currentHost.startsWith("127.")) {
    return;
  }

  function rewriteUrl(originalUrl) {
    try {
      const url = new URL(originalUrl);
      if (url.hostname.startsWith("192.168.1.") && ["2283", "4747", "8096", "3000"].includes(url.port)) {
        url.hostname = currentHost;
        return url.toString();
      }
    } catch (e) {}
    return originalUrl;
  }

  function rewriteLinks() {
    const links = document.querySelectorAll("a[href*=\"192.168.1.\"]");
    links.forEach((a) => {
      a.href = rewriteUrl(a.href);
    });
  }

  // Next.js 가상 DOM 이벤트를 완벽하게 가로채는 전역 클릭 캡처 리스너
  document.addEventListener("click", (e) => {
    const anchor = e.target.closest("a");
    if (anchor && anchor.href && anchor.href.includes("192.168.1.")) {
      const newUrl = rewriteUrl(anchor.href);
      if (newUrl !== anchor.href) {
        e.preventDefault();
        e.stopPropagation();
        const target = anchor.getAttribute("target") || "_blank";
        if (target === "_self") {
          window.location.href = newUrl;
        } else {
          window.open(newUrl, target);
        }
      }
    }
  }, true);

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", rewriteLinks);
  } else {
    rewriteLinks();
  }
  const observer = new MutationObserver(rewriteLinks);
  observer.observe(document.documentElement, { childList: true, subtree: true });
})();
JS_EOF

# 5. docker compose restart
cd /opt/homepage && docker compose restart
'

log_ok "Homepage 대시보드 설정 업데이트 및 재시작 완료!"
echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e " 1. 로컬 접속: ${BLUE}http://192.168.1.107:3000${NC} (클릭 시 내부망 이동)"
echo -e " 2. 외부 접속: ${BLUE}http://waceh.asuscomm.com:3000${NC} (클릭 시 외부망 이동)"
echo -e " 💡 적용 후 브라우저에서 ${BLUE}Ctrl+F5 (또는 Cmd+Shift+R 강력 새로고침)${NC}을 한 번 해주세요!"
echo -e "${GREEN}====================================================${NC}"
