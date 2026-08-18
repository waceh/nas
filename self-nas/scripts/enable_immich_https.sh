#!/usr/bin/env bash
# Immich Direct HTTPS (Caddy SSL + OpenSSL) Installer for self-nas
set -e

DOMAIN="${1:-your-domain.asuscomm.com}"
PORT="${2:-2283}"

echo "===================================================="
echo "🔒 Immich 다이렉트 HTTPS (OpenSSL + Caddy) 설정기"
echo "===================================================="
echo "도메인: ${DOMAIN}"
echo "외부 HTTPS 포트: ${PORT}"
echo "===================================================="

# LXC 103 내부에 Caddy 설치 및 OpenSSL 인증서 설정
pct exec 103 -- bash -c "
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq openssl caddy curl

  # 1. 10년짜리 고유 RSA SSL 인증서 생성
  mkdir -p /etc/caddy/certs
  openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /etc/caddy/certs/immich.key \
    -out /etc/caddy/certs/immich.crt \
    -subj '/CN=${DOMAIN}' \
    -addext 'subjectAltName=DNS:${DOMAIN},IP:192.168.1.103,IP:127.0.0.1' 2>/dev/null

  chmod 644 /etc/caddy/certs/immich.crt /etc/caddy/certs/immich.key

  # 2. Immich Docker 포트를 로컬 3001로 변경
  cd /opt/immich
  sed -i 's/\"2283:2283\"/\"127.0.0.1:3001:2283\"/g' docker-compose.yml
  sed -i \"s/'2283:2283'/\"127.0.0.1:3001:2283\"/g\" docker-compose.yml
  docker compose down && docker compose up -d

  # 3. Caddyfile에 SSL 인증서 및 리버스 프록시 등록
  printf 'https://:2283 {\n    tls /etc/caddy/certs/immich.crt /etc/caddy/certs/immich.key\n    reverse_proxy 127.0.0.1:3001\n}\n' > /etc/caddy/Caddyfile

  # 4. Caddy 재시작
  systemctl restart caddy
"

echo ""
echo "===================================================="
echo "🎉 Immich 자체 HTTPS(SSL) 설정이 완료되었습니다!"
echo "===================================================="
echo "▶ 외부 접속: https://${DOMAIN}:${PORT} (보안 자물쇠 🔒)"
echo "▶ 내부 접속: https://192.168.1.103:${PORT}"
echo "===================================================="
echo "⚠️ 필수 체크: ASUS 공유기 포트포워딩에서"
echo "  - 외부 ${PORT} ➔ 내부 192.168.1.103:${PORT} (TCP)"
echo "===================================================="
