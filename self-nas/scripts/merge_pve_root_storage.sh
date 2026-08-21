#!/usr/bin/env bash
# ==============================================================================
# Proxmox VE Root Storage Merge & Expansion Script (self-nas)
# ==============================================================================
# - Intel 710 100GB SSD 내 미사용 pve-data (local-lvm 70GB) 안전 제거
# - pve-root (OS 루트)를 100GB 디스크 전체로 온라인 무중단 확장
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

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}    Proxmox VE 710 SSD OS 루트 파티션 100GB 확장    ${NC}"
echo -e "${GREEN}====================================================${NC}"

# 1. pve/data 볼륨 존재 여부 확인 및 제거
if lvdisplay /dev/pve/data &>/dev/null; then
    log_info "1. 미사용 local-lvm (pve/data) 풀 안전 제거 중..."
    lvremove -y /dev/pve/data
    pvesm remove local-lvm &>/dev/null || true
    log_ok "pve/data 제거 완료!"
else
    log_info "pve/data 풀이 이미 정리되어 있습니다."
fi

# 2. pve/root 볼륨을 남은 100% 용량으로 확장
log_info "2. pve-root (OS 시스템) 볼륨을 100GB 전체로 확장 중..."
lvextend -l +100%FREE /dev/pve/root

# 3. ext4 파일시스템 온라인 리사이즈
log_info "3. 파일시스템 온라인 리사이즈 적용 중..."
resize2fs /dev/pve/root

log_ok "Intel 710 SSD OS 루트 파티션 100GB 확장 완료!"
echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e " 💾 [확장 결과 확인]:"
df -h /
echo -e "${GREEN}====================================================${NC}"
