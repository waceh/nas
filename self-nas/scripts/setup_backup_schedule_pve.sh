#!/usr/bin/env bash
# ==============================================================================
# Proxmox VE Automated Daily Backup Scheduler Installer (self-nas)
# ==============================================================================
# - 매일 새벽 04:00 전체 VM/LXC 컨테이너(101~107) 무중단(Snapshot) 자동 백업
# - 저장소: WD Gold 4TB 엔터프라이즈 금고 (nas-backups)
# - 보관 정책: keep-last=3 (최신 3개 상시 유지, 이전 백업 자동 롤링 삭제)
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
echo -e "${GREEN}  Proxmox VE 6대 서비스 매일 새벽 04:00 자동 백업   ${NC}"
echo -e "${GREEN}====================================================${NC}"

# 1. 백업 스토리지 확인
TARGET_STORAGE="nas-backups"
if ! pvesm status --storage "$TARGET_STORAGE" &>/dev/null; then
    log_info "nas-backups 스토리지를 찾을 수 없어 기본 local 스토리지로 설정합니다."
    TARGET_STORAGE="local"
else
    log_ok "백업 대상 스토리지 확인 완료: ${TARGET_STORAGE} (WD Gold 4TB)"
fi

# 2. 백업 스케줄 잡 등록 (/etc/pve/jobs.cfg)
log_info "자동 백업 스케줄 등록 중 (매일 새벽 04:00, keep-last: 3)..."

JOB_ID="backup-daily-0400"
JOBS_FILE="/etc/pve/jobs.cfg"

# 기존 동일 잡 제거 후 갱신
if [ -f "$JOBS_FILE" ] && grep -q "vzdump: ${JOB_ID}" "$JOBS_FILE"; then
    log_info "기존 ${JOB_ID} 설정을 최신 설정으로 갱신합니다."
    # vzdump 블록 제거
    sed -i "/vzdump: ${JOB_ID}/,/^$/d" "$JOBS_FILE"
fi

cat << JOB_EOF >> "$JOBS_FILE"
vzdump: ${JOB_ID}
	schedule 04:00
	storage ${TARGET_STORAGE}
	all 1
	mode snapshot
	compress zstd
	keep-last 3
	quiet 1

JOB_EOF

log_ok "Proxmox 자동 백업 스케줄러 등록 완료!"
echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e " ⏰ 백업 주기:    ${BLUE}매일 새벽 04:00 (무중단 Live Snapshot)${NC}"
echo -e " 💾 저장소:       ${BLUE}${TARGET_STORAGE} (WD Gold 4TB 금고)${NC}"
echo -e " 📦 대상:         ${BLUE}전체 게스트 (LXC 102, 103, 104, 105, 107, VM 101)${NC}"
echo -e " 🗜️ 압축 방식:    ${BLUE}Zstandard (zstd) 초고속 압축${NC}"
echo -e " ♻️ 보관 정책:    ${GREEN}최신 3회분 상시 보관 (이전 백업 자동 롤링 삭제)${NC}"
echo -e "===================================================="
