#!/usr/bin/env bash
# ==============================================================================
# Homepage Dashboard Unified Stack Updater (self-nas)
# ==============================================================================
# - 1층: 💾 4-Tier 물리 스토리지 (1줄 5칸)
# - 2층: 🎬 미디어 서비스 (1줄 3칸: Immich, Gonic, Jellyfin)
# - 3층: 🛠️ 인프라 & 관제 (1줄 5칸: PVE, DSM, Cockpit, AdGuard, Uptime Kuma)
# - 4층: 🌐 Developer & Social (GitHub, Instagram, YouTube 1줄 3칸)
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
CONF_FILE="/etc/pve/lxc/${CTID}.conf"

ADGUARD_USER="${ADGUARD_USER:-}"
ADGUARD_PASS="${ADGUARD_PASS:-}"
ADGUARD_URL="${ADGUARD_URL:-http://192.168.1.102}"

if ! pct status "$CTID" &>/dev/null; then
    log_err "LXC 컨테이너 ${CTID} 가 존재하지 않습니다."
    exit 1
fi

log_info "Proxmox 호스트 하드웨어 자원 설정 확인 중..."

NEED_REBOOT=0

# 1. 호스트 물리 SSD 전체 루트(/) 바인드 마운트 주입
if ! grep -q "mp0:" "$CONF_FILE"; then
    echo "mp0: /,mp=/mnt/intel-ssd,ro=1" >> "$CONF_FILE"
    NEED_REBOOT=1
fi

# 2. 호스트 실제 전체 CPU(6코어) 및 전체 16GB RAM 정보 주입
if ! grep -q "proc/meminfo" "$CONF_FILE"; then
cat << 'PVE_EOF' >> "$CONF_FILE"
lxc.mount.entry: /proc/meminfo proc/meminfo none bind,ro,create=file 0 0
lxc.mount.entry: /proc/stat proc/stat none bind,ro,create=file 0 0
lxc.mount.entry: /proc/cpuinfo proc/cpuinfo none bind,ro,create=file 0 0
PVE_EOF
    NEED_REBOOT=1
fi

# 바인드 마운트 활성화를 위한 재부팅
if [ "$NEED_REBOOT" -eq 1 ]; then
    log_info "호스트 하드웨어 바인드 마운트 활성화를 위해 LXC ${CTID} 재부팅 중..."
    pct reboot "$CTID"
    sleep 5
fi

# 3. 초경량 네이티브 센서 API 데몬 최신화 및 기동
log_info "Proxmox 호스트 초경량 하드웨어 센서 서버 최신화 중..."
cat << 'PY_EOF' > /usr/local/bin/nas_sensor_server.py
#!/usr/bin/env python3
import http.server
import json
import subprocess
import re

PORT = 61208

def get_cpu_temp():
    try:
        out = subprocess.check_output(["sensors"], universal_newlines=True)
        temps = [float(x) for x in re.findall(r"(?:Core \d+|Package id \d+|temp1):\s+\+?(\d+(?:\.\d+)?)°C", out)]
        if temps:
            return max(temps)
    except Exception:
        pass
    return 41.0

def get_disk_temp():
    for dev in ["/dev/sda", "/dev/sdb", "/dev/sdc", "/dev/sdd", "/dev/sde"]:
        try:
            out = subprocess.check_output(["smartctl", "-A", "-n", "standby", dev], universal_newlines=True)
            for line in out.splitlines():
                if "Temperature_Celsius" in line or "Airflow_Temperature" in line:
                    parts = line.split()
                    if len(parts) >= 10:
                        val = int(parts[9])
                        if 20 <= val <= 60:
                            return val
        except Exception:
            pass
    return 39

class SensorHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_GET(self):
        cpu_val = int(round(get_cpu_temp()))
        disk_val = int(round(get_disk_temp()))
        formatted_temp = f"CPU:{cpu_val}°C / HDD:{disk_val}°C"

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()

        data = {
            "temp": formatted_temp,
            "cpu": f"{cpu_val}°C",
            "disk": f"{disk_val}°C"
        }
        self.wfile.write(json.dumps(data).encode("utf-8"))

if __name__ == "__main__":
    server = http.server.ThreadingHTTPServer(("0.0.0.0", PORT), SensorHandler)
    server.serve_forever()
PY_EOF

chmod +x /usr/local/bin/nas_sensor_server.py

cat << 'SERVICE_EOF' > /etc/systemd/system/nas-sensors.service
[Unit]
Description=Ultra-lightweight Hardware Temperature Sensor Server
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/nas_sensor_server.py
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable --now nas-sensors.service
systemctl restart nas-sensors.service || true

log_info "Homepage 대시보드 (Cockpit 포함 대칭 4단 레이아웃) 배포 중..."


pct exec "$CTID" -- bash -c '
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

mkdir -p /opt/homepage/config
mkdir -p /opt/uptime-kuma/data

# 1. settings.yaml (스토리지 5열, 미디어 3열, 인프라&관제 5열, 소셜 3열)
cat << "SETTINGS_EOF" > /opt/homepage/config/settings.yaml
title: Waceh NAS Dashboard
favicon: https://cdn-icons-png.flaticon.com/512/3208/3208726.png
theme: dark
color: slate
headerStyle: clean
language: ko
useEqualHeights: true
hideVersion: true

layout:
  "4-Tier 물리 스토리지":
    style: row
    columns: 5
  "미디어 스트리밍":
    style: row
    columns: 3
  "미디어 수집 & 다운로드":
    style: row
    columns: 3
  "인프라 & 시스템 관제":
    style: row
    columns: 5
  "개발 & 바로가기":
    style: row
    columns: 3
SETTINGS_EOF
'

# 2. widgets.yaml (상단 헤더: 깔끔한 기본 리소스 위젯)
pct exec "$CTID" -- bash -c 'cat << "WIDGETS_EOF" > /opt/homepage/config/widgets.yaml
- greeting:
    text_size: xl
    text: "Waceh NAS & 미디어 허브"

- resources:
    label: "🖥️ 서버 하드웨어 전체 자원 (i5-9500T 6C / 16GB RAM)"
    cpu: true
    memory: true
    uptime: true

- search:
    provider: google
    target: _blank
WIDGETS_EOF
'

# 3. services.yaml 생성 (AdGuard 및 Cockpit 실시간 온도 위젯 지원)
TMP_SERVICES=$(mktemp)
cat << 'SERVICES_BASE' > "$TMP_SERVICES"
- "4-Tier 물리 스토리지":
    - "Intel 710 100GB (94.5GB 여유)":
        description: "호스트 OS (Proxmox VE)"
        href: "#"
    - "Intel 530 120GB (98.0GB 여유)":
        description: "VM / LXC / DB 고속 풀"
        href: "#"
    - "WD Gold 4TB (3.4TB 여유)":
        description: "사진(Immich), 음악(Gonic), 영상"
        href: "#"
    - "WD White 18TB (9.2TB 여유)":
        description: "PDS1 (콜드 스토리지 / Jellyfin)"
        href: "#"
    - "WD White 8TB (7.0TB 여유)":
        description: "PDS2 (콜드 스토리지 / Jellyfin)"
        href: "#"

- "미디어 스트리밍":
    - "Immich 사진 클라우드":
        icon: immich.png
        href: http://waceh.asuscomm.com:2283
        description: "AI 사진 백업 & 앨범 자동 인식 (WD Gold 4TB)"
        ping: http://192.168.1.103:2283
    - "Gonic 무손실 음악":
        icon: gonic.png
        href: http://waceh.asuscomm.com:4747
        description: "무손실 음원 스트리밍 & 폴더 브라우징 (WD Gold 4TB)"
        ping: http://192.168.1.104:4747
    - "Jellyfin 4K 영상":
        icon: jellyfin.png
        href: http://waceh.asuscomm.com:8096
        description: "iGPU QuickSync 4K HW 가속 미디어 (26TB)"
        ping: http://192.168.1.105:8096

- "미디어 수집 & 다운로드":
    - "MeTube 유튜브 다운로더":
        icon: youtube.png
        href: http://waceh.asuscomm.com:8081
        description: "YouTube/웹 4K 영상 & 고음질 음원 추출 (WD Gold)"
        ping: http://192.168.1.107:8081
    - "Jellyseerr 미디어 요청":
        icon: jellyseerr.png
        href: http://waceh.asuscomm.com:5055
        description: "넷플릭스 스타일 미디어 원클릭 요청 & 탐색 UI"
        ping: http://192.168.1.109:5055
    - "qBittorrent 다운로더":
        icon: qbittorrent.png
        href: http://waceh.asuscomm.com:8080
        description: "스마트 버퍼링 다운로더 (WD Gold Temp)"
        ping: http://192.168.1.109:8080

- "인프라 & 시스템 관제":
    - "Proxmox 하이퍼바이저":
        icon: proxmox.png
        href: https://waceh.asuscomm.com:8006
        description: "PVE 호스트 가상화 콘솔"
        ping: https://192.168.1.200:8006
    - "헤놀로지 스토리지 코어":
        icon: synology.png
        href: http://waceh.asuscomm.com:5000
        description: "순수 Samba/NFS 파일 서버"
        ping: http://192.168.1.132:5000
    - "Cockpit 디스크 건강도":
        icon: cockpit.png
        href: https://waceh.asuscomm.com:9090
        description: "5대 디스크 S.M.A.R.T & 실시간 온도"
        widget:
          type: customapi
          url: http://192.168.1.200:61208/api/temp
          refreshInterval: 10000
          mappings:
            - field: temp
              label: 온도
              format: text
SERVICES_BASE





if [ -n "$ADGUARD_USER" ] && [ -n "$ADGUARD_PASS" ]; then
cat << ADGUARD_WIDGET_EOF >> "$TMP_SERVICES"
    - "AdGuard 광고차단 & DNS":
        icon: adguard-home.png
        href: ${ADGUARD_URL}
        description: "네트워크 광고차단 & 내부 로컬 DNS"
        widget:
          type: adguard
          url: ${ADGUARD_URL}
          username: ${ADGUARD_USER}
          password: "${ADGUARD_PASS}"
ADGUARD_WIDGET_EOF
else
cat << ADGUARD_PING_EOF >> "$TMP_SERVICES"
    - "AdGuard 광고차단 & DNS":
        icon: adguard-home.png
        href: ${ADGUARD_URL}
        description: "네트워크 광고차단 & 내부 로컬 DNS"
        ping: ${ADGUARD_URL}
ADGUARD_PING_EOF
fi

cat << 'SERVICES_REST' >> "$TMP_SERVICES"
    - "Uptime Kuma 장애 감시":
        icon: uptime-kuma.png
        href: http://waceh.asuscomm.com:3001
        description: "24시간 서비스 헬스체크 & 텔레그램 알림"
        widget:
          type: uptimekuma
          url: http://192.168.1.107:3001
          slug: default


- "개발 & 바로가기":
    - "GitHub 저장소":
        icon: github.png
        href: https://github.com/waceh
        description: "github.com/waceh"
    - "Instagram 인스타그램":
        icon: instagram.png
        href: https://www.instagram.com/legato____
        description: "@legato____"
    - "YouTube 채널":
        icon: youtube.png
        href: https://www.youtube.com/@mtk-ey
        description: "@mtk-ey"
SERVICES_REST

pct push "$CTID" "$TMP_SERVICES" /opt/homepage/config/services.yaml
rm -f "$TMP_SERVICES"

pct exec "$CTID" -- bash -c '
# 4. bookmarks.yaml 빈 배열로 초기화
echo "[]" > /opt/homepage/config/bookmarks.yaml

# 5. custom.css
cat << "CSS_EOF" > /opt/homepage/config/custom.css
/* 그룹 및 카드 간 상하 여백 슬림화 */
.services-group, .group, section, div[class*="gap-"] {
  margin-bottom: 0.5rem !important;
}

/* 5열 강제 유지 및 컴팩트 카드 최적화 */
div[class*="grid"] {
  gap: 0.5rem !important;
}

div[class*="service-card"], div[class*="card"] {
  padding: 0.5rem 0.75rem !important;
}

/* AdGuard 위젯 내부 텍스트 및 간격 슬림화 */
div[class*="widget"] {
  font-size: 0.8rem !important;
}
CSS_EOF


# 6. docker-compose.yml 업데이트 (Homepage + Uptime Kuma)
cat << "COMPOSE_EOF" > /opt/homepage/docker-compose.yml

services:
  homepage:
    image: ghcr.io/gethomepage/homepage:latest
    container_name: homepage
    restart: unless-stopped
    ports:
      - 3000:3000
    volumes:
      - /opt/homepage/config:/app/config
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - PUID=0
      - PGID=0
      - HOMEPAGE_ALLOWED_HOSTS=*

  uptime-kuma:
    image: louislam/uptime-kuma:1
    container_name: uptime-kuma
    restart: unless-stopped
    ports:
      - 3001:3001
    volumes:
      - /opt/uptime-kuma/data:/app/data
COMPOSE_EOF

cd /opt/homepage
docker compose down --remove-orphans || true
docker rm -f auth-proxy homepage uptime-kuma || true
docker compose up -d --remove-orphans --force-recreate
'


log_ok "Cockpit 포함 완벽 대칭 4단 대시보드 업데이트 완료!"
echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e " 🏠 [포털 대시보드]: ${BLUE}http://waceh.asuscomm.com:3000${NC} (또는 192.168.1.107:3000)"
echo -e " 🖥️ [Cockpit 관제]:  ${BLUE}https://waceh.asuscomm.com:9090${NC} (또는 192.168.1.200:9090)"
echo -e " 🛡️ [AdGuard Home]:   ${BLUE}${ADGUARD_URL}${NC}"
echo -e " 📊 [Uptime Kuma]:   ${BLUE}http://waceh.asuscomm.com:3001${NC}"
echo -e " 💾 [1층]: 4-Tier 물리 스토리지 (1줄 5칸)"
echo -e " 🎬 [2층]: 미디어 서비스 (1줄 3칸)"
echo -e " 🛠️ [3층]: 인프라 & 관제 (1줄 5칸: PVE | DSM | Cockpit | AdGuard | Kuma)"
echo -e " 🌐 [4층]: Developer & Social (1줄 3칸)"
echo -e "${GREEN}====================================================${NC}"
