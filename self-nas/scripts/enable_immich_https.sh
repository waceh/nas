#!/usr/bin/env bash
# Immich Direct HTTPS (Caddy SSL) Installer for self-nas
set -e

DOMAIN="${1:-waceh.asuscomm.com}"
EMAIL="${2:-admin@waceh.asuscomm.com}"
PORT="${3:-2283}"

echo "===================================================="
echo "🔒 Immich 다이렉트 HTTPS (SSL 자물쇠) 설정기"
echo "===================================================="
echo "도메인: ${DOMAIN}"
echo "외부 HTTPS 포트: ${PORT}"
echo "===================================================="

# LXC 103 내부에 Caddy 설치 및 설정
pct exec 103 -- bash -c "
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq debian-keyring debian-archive-keyring apt-transport-https curl

  # Caddy 공식 저장소 추가 및 설치
  curl -1sLF 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg --yes 2>/dev/null
  curl -1sLF 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
  apt-get update -qq
  apt-get install -y -qq caddy

  # Immich Docker 포트를 로컬 3001로 변경
  cd /opt/immich
  sed -i 's|\"2283:2283\"|\"127.0.0.1:3001:2283\"|g' docker-compose.yml
  sed -i 's|\x272283:2283\x27|\"127.0.0.1:3001:2283\"|g' docker-compose.yml
  docker compose down && docker compose up -d

  # Caddyfile 설정 (waceh.asuscomm.com:2283 HTTPS 리버스 프록시)
  cat << 'CFG' > /etc/caddy/Caddyfile
${DOMAIN}:${PORT} {
    reverse_proxy 127.0.0.1:3001
}
CFG

  # Caddy 재시작
  systemctl restart caddy
"

echo ""
echo "===================================================="
echo "🎉 Immich 자체 HTTPS(SSL) 설정이 완료되었습니다!"
echo "===================================================="
echo "▶ 외부 접속: https://${DOMAIN}:${PORT} (보안 자물쇠 🔒)"
echo "▶ 내부 접속: http://192.168.1.103:3001"
echo "===================================================="
echo "⚠️ 필수 체크: ASUS 공유기 포트포워딩에서"
echo "  - 외부 ${PORT} ➔ 내부 192.168.1.103:${PORT} (TCP)"
echo "  - 외부 80 ➔ 내부 192.168.1.103:80 (Let's Encrypt 인증서 발급용 최초 1회)"
echo "===================================================="
