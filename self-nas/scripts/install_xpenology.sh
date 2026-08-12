#!/usr/bin/env bash

# ==============================================================================
# self-nas Xpenology VM Installer for Proxmox VE
# ==============================================================================
# 이 스크립트는 MTK Studio (self-nas) 환경에 최적화된 헤놀로지 VM 자동 생성 스크립트입니다.
# - 최신 RR (Redpill Recovery) / m-shell 부트로더 자동 다운로드
# - QEMU 가상 USB 부팅 방식 적용 (SATA 슬롯 낭비 없음)
# - 물리 디스크(WD Red 8TB, WD White 12TB 등) by-id 자동 탐색 및 패스스루
# - 트러블슈팅용 가상 시리얼 포트(--serial0 socket) 내장
# ==============================================================================

set -e

# 색상 정의
GREEN='\033[1;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 기본 설정 (self-nas 사양 기준)
VMID="${VMID:-101}"
VMNAME="${VMNAME:-xpenology}"
CORES="${CORES:-2}"
RAM="${RAM:-4096}"
BRIDGE="${BRIDGE:-vmbr0}"
STORAGE_DIR="/var/lib/vz/template/iso"
LOADER_TYPE="${LOADER_TYPE:-RR}" # RR 또는 m-shell

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err()   { echo -e "${RED}[ERROR]${NC} $1"; }

# 1. Root 권한 검사
if [ "$(id -u)" -ne 0 ]; then
    log_err "이 스크립트는 Proxmox 호스트의 root 권한으로 실행해야 합니다."
    exit 1
fi

# 2. 필요 패키지 점검
for pkg in curl jq unzip; do
    if ! command -v "$pkg" &>/dev/null; then
        log_info "필요한 패키지 ($pkg) 설치 중..."
        apt-get update -qq && apt-get install -y -qq "$pkg"
    fi
done

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}    self-nas Proxmox Xpenology VM 자동 생성기       ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo "VM ID: ${VMID}"
echo "VM 이름: ${VMNAME}"
echo "CPU 코어: ${CORES}"
echo "RAM: ${RAM} MB"
echo "네트워크 브리지: ${BRIDGE}"
echo "부트로더 종류: ${LOADER_TYPE}"
echo "===================================================="

# 3. 기존 VM 존재 여부 확인
if qm status "$VMID" &>/dev/null; then
    log_err "VM ID ${VMID} 가 이미 존재합니다. 다른 VM ID를 지정하거나 기존 VM을 삭제하세요."
    exit 1
fi

# 4. 부트로더 최신 버전을 GitHub에서 다운로드
mkdir -p "$STORAGE_DIR"
IMG_PATH="${STORAGE_DIR}/${LOADER_TYPE}-${VMID}.img"

if [ -f "$IMG_PATH" ]; then
    log_ok "이미 준비된 부트로더 이미지를 사용합니다: ${IMG_PATH}"
else
    log_info "${LOADER_TYPE} 부트로더 최신 버전을 확인하고 다운로드합니다..."

    if [ "$LOADER_TYPE" = "RR" ]; then
        REPO="RROrg/rr"
        LATEST_TAG=$(curl -sfL -w '%{url_effective}' -o /dev/null "https://github.com/${REPO}/releases/latest" | awk -F'/' '{print $NF}')
        if [ -z "$LATEST_TAG" ]; then
            log_err "GitHub에서 RR 최신 버전 태그를 가져오지 못했습니다."
            exit 1
        fi
        DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}/rr-${LATEST_TAG}.img.zip"
        ZIP_PATH="${STORAGE_DIR}/rr-${VMID}.zip"
        
        log_info "RR 버전: ${LATEST_TAG} 다운로드 중..."
        curl -fL -o "$ZIP_PATH" "$DOWNLOAD_URL"
        
        log_info "압축 해제 중..."
        unzip -o "$ZIP_PATH" -d "$STORAGE_DIR" >/dev/null
        rm -f "$ZIP_PATH"
        
        if [ -f "${STORAGE_DIR}/rr.img" ]; then
            mv "${STORAGE_DIR}/rr.img" "$IMG_PATH"
        fi
    else
        REPO="PeterSuh-Q3/tinycore-redpill"
        LATEST_TAG=$(curl -sfL -w '%{url_effective}' -o /dev/null "https://github.com/${REPO}/releases/latest" | awk -F'/' '{print $NF}')
        if [ -z "$LATEST_TAG" ]; then
            log_err "GitHub에서 m-shell 최신 버전 태그를 가져오지 못했습니다."
            exit 1
        fi
        DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}/alpine-redpill.${LATEST_TAG}.m-shell.img.gz"
        GZ_PATH="${STORAGE_DIR}/m-shell-${VMID}.img.gz"
        
        log_info "m-shell 버전: ${LATEST_TAG} 다운로드 중..."
        curl -fL -o "$GZ_PATH" "$DOWNLOAD_URL"
        
        log_info "압축 해제 중..."
        gunzip -f "$GZ_PATH"
    fi
fi

if [ ! -f "$IMG_PATH" ]; then
    log_err "부트로더 이미지 파일 생성 실패: ${IMG_PATH}"
    exit 1
fi

log_ok "부트로더 준비 완료: ${IMG_PATH}"

# 5. Proxmox VM 생성
log_info "Proxmox VM (${VMID}) 생성 중..."

qm create "$VMID" \
  --name "$VMNAME" \
  --memory "$RAM" \
  --cores "$CORES" \
  --cpu host \
  --bios seabios \
  --ostype l26 \
  --net0 "virtio,bridge=${BRIDGE}" \
  --serial0 socket

# 가상 USB 부팅 설정 (QEMU args)
QM_ARGS="-drive if=none,id=synoboot,format=raw,file=${IMG_PATH} -device qemu-xhci,id=xhci -device usb-storage,bus=xhci.0,drive=synoboot,bootindex=0"
qm set "$VMID" --args "$QM_ARGS"

log_ok "VM 기본 구성 완료 (가상 USB 부트로더 탑재 완료)"

# 6. 물리 디스크(WD Red / White 등) 패스스루 자동 탐색 및 안내
echo ""
log_info "미사용 물리 디스크(by-id) 탐색 중..."

ROOT_DISK=$(lsblk -no PKNAME "$(findmnt -no SOURCE / 2>/dev/null)" 2>/dev/null | head -n 1)

DISKS=()
while read -r line; do
    BY_ID=$(echo "$line" | awk '{print $1}')
    DEV_TARGET=$(readlink -f "$BY_ID" 2>/dev/null || true)
    DEV_NAME=$(basename "$DEV_TARGET" 2>/dev/null || true)

    # OS 부팅 디스크 제외
    if [ "$DEV_NAME" = "$ROOT_DISK" ]; then continue; fi

    # 현재 마운트되어 있거나 LVM/ZFS 사용 중 디스크 제외
    if lsblk -nro MOUNTPOINT "$DEV_TARGET" 2>/dev/null | grep -q .; then continue; fi
    if lsblk -nro FSTYPE "$DEV_TARGET" 2>/dev/null | grep -Eq 'LVM2_member|zfs_member|linux_raid_member|swap'; then continue; fi

    # 다른 VM에서 이미 사용 중 디스크 제외
    if grep -qs -- "$BY_ID" /etc/pve/qemu-server/*.conf 2>/dev/null; then continue; fi

    DISKS+=("$BY_ID")
done < <(ls -l /dev/disk/by-id/ata-* 2>/dev/null | grep -v '\-part' | awk '{print $9}')

if [ ${#DISKS[@]} -gt 0 ]; then
    log_ok "패스스루 가능한 데이터 디스크 ${#DISKS[@]}개 발견:"
    SATA_IDX=1
    for disk in "${DISKS[@]}"; do
        echo "  - [sata${SATA_IDX}] ${disk}"
        qm set "$VMID" --sata${SATA_IDX} "$disk"
        ((SATA_IDX++))
    done
    log_ok "데이터 디스크 패스스루 연결 완료!"
else
    log_warn "자동으로 패스스루할 미사용 물리 디스크를 발견하지 못했습니다."
    log_warn "(설치 중 데이터 보호를 위해 SATA 케이블을 분리해 둔 경우:)"
    log_warn "  1. 부트로더 생성 완료 후 시스템 종료 (poweroff)"
    log_warn "  2. WD Red, White SATA 케이블 재결착 후 서버 부팅"
    log_warn "  3. 'qm set ${VMID} -sata1 /dev/disk/by-id/ata-...' 명령으로 패스스루 연결"
fi

# 7. 요약 출력 및 완료 안내
echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}      Xpenology VM (${VMID}) 생성 완료!             ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e " 1. VM 시작: ${YELLOW}qm start ${VMID}${NC}"
echo -e " 2. 로더 설정 접속: 브라우저에서 ${YELLOW}http://<VM_IP>:7681${NC} 접속"
echo -e " 3. 권장 모델 및 DSM 버전:"
echo -e "    - 모델: ${GREEN}DS920+${NC} 또는 ${GREEN}SA6400${NC}"
echo -e "    - DSM 버전: ${GREEN}DSM 7.2.2 (최신 안정 버전)${NC}"
echo -e " 4. DSM 설치 접속: ${YELLOW}http://find.synology.com${NC} 또는 Synology Assistant"
echo -e "${GREEN}====================================================${NC}"
