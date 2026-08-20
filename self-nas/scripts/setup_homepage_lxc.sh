#!/usr/bin/env bash
# ==============================================================================
# Homepage Dashboard Proxmox Native LXC Installer (self-nas)
# ==============================================================================
# - LXC 107 생성 (Debian 12, 1 Core, 512MB RAM, 4GB SSD Root on local-530)
# - Docker 및 Homepage 공식 최신 이미지 자동 배포
# - Proxmox(710/530), 헤놀로지(Gold/White), Immich, Gonic, Jellyfin 통합 대시보드 자동 사전구성
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
HOSTNAME="${HOSTNAME:-homepage-dashboard}"
CORES="${CORES:-1}"
RAM="${RAM:-512}"
SWAP="${SWAP:-256}"
DISK_SIZE="${DISK_SIZE:-4}"
STORAGE="${STORAGE:-local-530}"
BRIDGE="${BRIDGE:-vmbr0}"
IP_ADDR="${IP_ADDR:-192.168.1.107/24}"
GATEWAY="${GATEWAY:-192.168.1.1}"

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}      Homepage Dashboard LXC 자동 설치기            ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo "컨테이너 ID: ${CTID}"
echo "호스트명: ${HOSTNAME}"
echo "IP 주소: ${IP_ADDR}"
echo "스토리지 풀: ${STORAGE}"
echo "===================================================="

# 1. Debian 12 템플릿 준비
TEMPLATE=$(pveam list local | grep -E "debian-12-standard" | awk '{print $1}' | head -n 1 || true)
if [ -z "$TEMPLATE" ]; then
    log_info "Debian 12 표준 템플릿 다운로드 중..."
    pveam update
    pveam download local debian-12-standard_12.7-1_amd64.tar.zst || pveam download local $(pveam available | grep debian-12 | awk '{print $2}' | head -n 1)
    TEMPLATE=$(pveam list local | grep -E "debian-12-standard" | awk '{print $1}' | head -n 1)
fi

# 2. 기존 컨테이너 확인 및 강제 정리
if pct status "$CTID" &>/dev/null; then
    log_info "기존 CTID ${CTID} 컨테이너 강제 정리 중..."
    pct stop "$CTID" --force &>/dev/null || true
    pct destroy "$CTID" --purge --force &>/dev/null || true
fi

# 3. LXC 107 생성 (Intel 530 SSD local-530 위)
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

# 5. Docker 설치 및 Homepage 사전 구성 (LXC 내부)
log_info "LXC 내부 Docker 설치 및 Homepage 대시보드 사전 설정 중..."
pct exec "$CTID" -- bash -c 'echo "ZXhwb3J0IERFQklBTl9GUk9OVEVORD1ub25pbnRlcmFjdGl2ZQphcHQtZ2V0IHVwZGF0ZSAtcXEKYXB0LWdldCBpbnN0YWxsIC15IC1xcSBjdXJsIGNhLWNlcnRpZmljYXRlcyBnbnVwZwoKaWYgISBjb21tYW5kIC12IGRvY2tlciAmPi9kZXYvbnVsbDsgdGhlbgogIGN1cmwgLWZzU0wgaHR0cHM6Ly9nZXQuZG9ja2VyLmNvbSB8IHNoCmZpCgpta2RpciAtcCAvb3B0L2hvbWVwYWdlL2NvbmZpZwoKY2F0IDw8ICdTRVRUSU5HU19FT0YnID4gL29wdC9ob21lcGFnZS9jb25maWcvc2V0dGluZ3MueWFtbAp0aXRsZTogTVRLIFN0dWRpbyBIb21lIERhc2hib2FyZApmYXZpY29uOiBodHRwczovL2Nkbi1pY29ucy1wbmcuZmxhdGljb24uY29tLzUxMi8zMjA4LzMyMDg3MjYucG5nCnRoZW1lOiBkYXJrCmNvbG9yOiBzbGF0ZQpoZWFkZXJTdHlsZTogY2xlYW4KbGFuZ3VhZ2U6IGtvCnVzZUVxdWFsSGVpZ2h0czogdHJ1ZQpoaWRlVmVyc2lvbjogdHJ1ZQpTRVRUSU5HU19FT0YKCmNhdCA8PCAnV0lER0VUU19FT0YnID4gL29wdC9ob21lcGFnZS9jb25maWcvd2lkZ2V0cy55YW1sCi0gZ3JlZXRpbmc6CiAgICB0ZXh0X3NpemU6IHhsCiAgICB0ZXh0OiAiTVRLIFN0dWRpbyBOQVMgJiBNZWRpYSBIdWIiCi0gc2VhcmNoOgogICAgcHJvdmlkZXI6IGdvb2dsZQogICAgdGFyZ2V0OiBfYmxhbmsKLSByZXNvdXJjZXM6CiAgICBjcHU6IHRydWUKICAgIG1lbW9yeTogdHJ1ZQogICAgZGlzazogLwpXSURHRVRTX0VPRgoKY2F0IDw8ICdTRVJWSUNFU19FT0YnID4gL29wdC9ob21lcGFnZS9jb25maWcvc2VydmljZXMueWFtbAotIOuvuOuUlOyWtCDshJzruYTsiqQgKE1lZGlhIENvcmUpOgogICAgLSBJbW1pY2ggUGhvdG86CiAgICAgICAgaWNvbjogaW1taWNoLnBuZwogICAgICAgIGhyZWY6IGh0dHA6Ly8xOTIuMTY4LjEuMTAzOjIyODMKICAgICAgICBkZXNjcmlwdGlvbjogQUkg7IKs7KeEIOuwseyXhSAvIOyViOuptCDsnbjsi50gKFdEIEdvbGQgNFRCKQogICAgICAgIHBpbmc6IGh0dHA6Ly8xOTIuMTY4LjEuMTAzOjIyODMKICAgIC0gR29uaWMgTXVzaWM6CiAgICAgICAgaWNvbjogZ29uaWMucG5nCiAgICAgICAgaHJlZjogaHR0cDovLzE5Mi4xNjguMS4xMDQ6NDc0NwogICAgICAgIGRlc2NyaXB0aW9uOiDrrLTshpDsi6Qg7J2M7JWFIOyKpO2KuOumrOuwjSAvIEFtcGVyZnkgKFdEIEdvbGQgNFRCKQogICAgICAgIHBpbmc6IGh0dHA6Ly8xOTIuMTY4LjEuMTA0OjQ3NDcKICAgIC0gSmVsbHlmaW4gVmlkZW86CiAgICAgICAgaWNvbjogamVsbHlmaW4ucG5nCiAgICAgICAgaHJlZjogaHR0cDovLzE5Mi4xNjguMS4xMDU6ODA5NgogICAgICAgIGRlc2NyaXB0aW9uOiBpR1BVIFF1aWNrU3luYyA0SyDruYTrlJTsmKQgKFdEIFdoaXRlIDE4VEIgLyA4VEIpCiAgICAgICAgcGluZzogaHR0cDovLzE5Mi4xNjguMS4xMDU6ODA5NgoKLSDsnbjtlITrnbwgJiDsiqTthqDrpqzsp4AgKEluZnJhc3RydWN0dXJlKToKICAgIC0gUHJveG1veCBWRToKICAgICAgICBpY29uOiBwcm94bW94LnBuZwogICAgICAgIGhyZWY6IGh0dHBzOi8vMTkyLjE2OC4xLjIwMDo4MDA2CiAgICAgICAgZGVzY3JpcHRpb246IO2VmOydtO2NvOuwlOydtOyggCDtmLjsiqTtirggKEludGVsIDcxMCBTU0QgT1MpCiAgICAgICAgcGluZzogaHR0cHM6Ly8xOTIuMTY4LjEuMjAwOjgwMDYKICAgIC0gWHBlbm9sb2d5IERTTToKICAgICAgICBpY29uOiBzeW5vbG9neS5wbmcKICAgICAgICBocmVmOiBodHRwOi8vMTkyLjE2OC4xLjEzMjo1MDAwCiAgICAgICAgZGVzY3JpcHRpb246IFB1cmUgU3RvcmFnZSBDb3JlIChHb2xkIDRUICsgV2hpdGUgMjZUKQogICAgICAgIHBpbmc6IGh0dHA6Ly8xOTIuMTY4LjEuMTMyOjUwMDAKU0VSVklDRVNfRU9GCgpjYXQgPDwgJ0NPTVBPU0VfRU9GJyA+IC9vcHQvaG9tZXBhZ2UvZG9ja2VyLWNvbXBvc2UueW1sCnNlcnZpY2VzOgogIGhvbWVwYWdlOgogICAgaW1hZ2U6IGdoY3IuaW8vZ2V0aG9tZXBhZ2UvaG9tZXBhZ2U6bGF0ZXN0CiAgICBjb250YWluZXJfbmFtZTogaG9tZXBhZ2UKICAgIHJlc3RhcnQ6IHVubGVzcy1zdG9wcGVkCiAgICBwb3J0czoKICAgICAgLSAzMDAwOjMwMDAKICAgIHZvbHVtZXM6CiAgICAgIC0gL29wdC9ob21lcGFnZS9jb25maWc6L2FwcC9jb25maWcKICAgICAgLSAvdmFyL3J1bi9kb2NrZXIuc29jazovdmFyL3J1bi9kb2NrZXIuc29jazpybwogICAgZW52aXJvbm1lbnQ6CiAgICAgIC0gUFVJRD0wCiAgICAgIC0gUEdJRD0wCkNPTVBPU0VfRU9GCgpjZCAvb3B0L2hvbWVwYWdlCmRvY2tlciBjb21wb3NlIHVwIC1kCg==" | base64 -d | bash'

# 6. 호스트 부팅 및 종료 순서 설정
pct set "$CTID" --startup "order=2,up=5,down=10"

echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}     Homepage Dashboard (${CTID}) 설치 완료!         ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e " 1. 로컬 접속 URL: ${BLUE}http://${IP_ADDR%/*}:3000${NC}"
echo -e " 2. 메인 대시보드: Immich / Gonic / Jellyfin / Proxmox / 헤놀로지 자동 연동"
echo -e " 3. 설정 파일 위치: LXC ${CTID} 내부 ${GREEN}/opt/homepage/config/${NC}"
echo -e "${GREEN}====================================================${NC}"
