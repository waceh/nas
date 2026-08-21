#!/usr/bin/env bash
# ==============================================================================
# Homepage Dashboard HTTP Basic Auth Protector (self-nas)
# ==============================================================================
# - Homepage 대시보드에 Nginx 보안 인증 프록시 레이어 자동 구축
# - ID / Password 미입력 시 401 Unauthorized 원천 차단
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
AUTH_USER="${AUTH_USER:-waceh}"
AUTH_PASS="${AUTH_PASS:-aaaa}"

log_info "Homepage LXC (${CTID})에 HTTP Basic Auth 보안 설정 적용 중... (ID: ${AUTH_USER})"

pct exec "$CTID" -- bash -c "
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq apache2-utils

mkdir -p /opt/homepage

# 1. .htpasswd 파일 생성
htpasswd -bc /opt/homepage/.htpasswd '${AUTH_USER}' '${AUTH_PASS}'
chmod 644 /opt/homepage/.htpasswd

# 2. Nginx 프록시 설정 파일 생성
cat << 'NGINX_EOF' > /opt/homepage/nginx.conf
server {
    listen 3000;
    server_name _;

    auth_basic \"Waceh NAS Dashboard\";
    auth_basic_user_file /etc/nginx/.htpasswd;

    location / {
        proxy_pass http://homepage:3000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"upgrade\";
    }
}
NGINX_EOF

# 3. Docker Compose 파일 업데이트 (보안 프록시 연동)
cat << 'COMPOSE_EOF' > /opt/homepage/docker-compose.yml
services:
  homepage:
    image: ghcr.io/gethomepage/homepage:latest
    container_name: homepage
    restart: unless-stopped
    expose:
      - 3000
    volumes:
      - /opt/homepage/config:/app/config
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - PUID=0
      - PGID=0
      - HOMEPAGE_ALLOWED_HOSTS=*

  auth-proxy:
    image: nginx:alpine
    container_name: auth-proxy
    restart: unless-stopped
    ports:
      - 3000:3000
    volumes:
      - /opt/homepage/nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - /opt/homepage/.htpasswd:/etc/nginx/.htpasswd:ro
    depends_on:
      - homepage
COMPOSE_EOF

cd /opt/homepage
docker compose up -d --force-recreate
"

log_ok "Homepage 비밀번호 보안 설정 완료!"
echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e " 🔒 대시보드 로그인 계정:"
echo -e "   - 아이디 (ID): ${BLUE}${AUTH_USER}${NC}"
echo -e "   - 비밀번호 (PW): ${BLUE}${AUTH_PASS}${NC}"
echo -e " 🌐 접속 주소: ${BLUE}http://waceh.asuscomm.com:3000${NC}"
echo -e "${GREEN}====================================================${NC}"
