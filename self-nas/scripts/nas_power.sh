#!/usr/bin/env bash
# ==============================================================================
# ⚡ MTK Studio Self-NAS 통합 Graceful 전원 및 순차 제어 스크립트 (nas_power.sh)
# ==============================================================================
# 사용법:
#   bash nas_power.sh status        # 전체 VM 및 LXC 상태 & 서비스 헬스체크
#   bash nas_power.sh up            # 스토리지(VM 101) -> 미디어 서비스(LXC) 순차 안전 기동
#   bash nas_power.sh down          # 미디어 서비스(LXC) -> 스토리지(VM 101) 순차 안전 종료
#   bash nas_power.sh shutdown-host # 전체 안전 순차 종료 후 Proxmox 호스트 전원 끄기
#   bash nas_power.sh reboot-host   # 전체 안전 순차 종료 후 Proxmox 호스트 재부팅
#   bash nas_power.sh init-order    # Proxmox 부팅/종료 순서(order/up/down) 일괄 등록
# ==============================================================================

set -e

GREEN='\033[1;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $1"; }

if [ "$(id -u)" -ne 0 ]; then
    log_err "이 스크립트는 Proxmox 호스트의 root 권한으로 실행해야 합니다."
    exit 1
fi

NAS_VM_ID="101"
NAS_IP="192.168.1.132"
LXC_SERVICES=(102 103 104 105 106)
LXC_SHUTDOWN_ORDER=(105 104 103 106 102) # Jellyfin -> Gonic -> Immich -> Dev -> AdGuard

# ------------------------------------------------------------------------------
# 1. 상태 조회 (Status)
# ------------------------------------------------------------------------------
show_status() {
    echo -e "${GREEN}====================================================${NC}"
    echo -e "${GREEN}       ⚡ Proxmox VM & LXC 서비스 상태 모니터        ${NC}"
    echo -e "${GREEN}====================================================${NC}"
    
    # 1. 헤놀로지 VM 101
    if qm status "$NAS_VM_ID" &>/dev/null; then
        VM_STATE=$(qm status "$NAS_VM_ID" | awk '{print $2}')
        if [ "$VM_STATE" == "running" ]; then
            echo -e " [VM 101] 헤놀로지 스토리지 코어: ${GREEN}🟢 RUNNING${NC} (${NAS_IP})"
        else
            echo -e " [VM 101] 헤놀로지 스토리지 코어: ${RED}🔴 STOPPED${NC}"
        fi
    fi

    # 2. LXC 컨테이너 목록
    for ctid in "${LXC_SERVICES[@]}"; do
        if pct status "$ctid" &>/dev/null; then
            CT_NAME=$(pct config "$ctid" | grep "hostname:" | awk '{print $2}')
            CT_IP=$(pct config "$ctid" | grep "net0:" | grep -oE "ip=[0-9.]+" | cut -d'=' -f2 || true)
            CT_STATE=$(pct status "$ctid" | awk '{print $2}')
            
            if [ "$CT_STATE" == "running" ]; then
                echo -e " [LXC ${ctid}] ${CT_NAME}: ${GREEN}🟢 RUNNING${NC} (${CT_IP})"
            else
                echo -e " [LXC ${ctid}] ${CT_NAME}: ${RED}🔴 STOPPED${NC}"
            fi
        fi
    done
    echo -e "${GREEN}====================================================${NC}"
}

# ------------------------------------------------------------------------------
# 2. 안전 순차 기동 (Graceful Up)
# ------------------------------------------------------------------------------
power_up() {
    echo -e "${GREEN}====================================================${NC}"
    echo -e "${GREEN}       🚀 NAS 및 미디어 서비스 순차 기동 시작        ${NC}"
    echo -e "${GREEN}====================================================${NC}"

    # 1단계: 헤놀로지 VM 101 기동
    if qm status "$NAS_VM_ID" &>/dev/null; then
        VM_STATE=$(qm status "$NAS_VM_ID" | awk '{print $2}')
        if [ "$VM_STATE" != "running" ]; then
            log_info "1단계: 헤놀로지 VM 101 기동 중..."
            qm start "$NAS_VM_ID"
            
            log_info "헤놀로지 Btrfs 볼륨 및 NFS 데몬 응답 대기 중..."
            RETRIES=0
            MAX_RETRIES=15
            while [ $RETRIES -lt $MAX_RETRIES ]; do
                if ping -c 1 -W 1 "$NAS_IP" &>/dev/null; then
                    log_ok "헤놀로지 IP 응답 확인! (추가 안정화 15초 대기...)"
                    sleep 15
                    break
                fi
                RETRIES=$((RETRIES + 1))
                echo -n "."
                sleep 3
            done
            echo ""
        else
            log_ok "1단계: 헤놀로지 VM 101 이미 실행 중입니다."
        fi
    fi

    # 2단계: LXC 컨테이너 순차 기동
    log_info "2단계: 미디어 및 네트워크 컨테이너 순차 기동 중..."
    for ctid in "${LXC_SERVICES[@]}"; do
        if pct status "$ctid" &>/dev/null; then
            CT_STATE=$(pct status "$ctid" | awk '{print $2}')
            CT_NAME=$(pct config "$ctid" | grep "hostname:" | awk '{print $2}')
            if [ "$CT_STATE" != "running" ]; then
                log_info "LXC ${ctid} (${CT_NAME}) 기동 중..."
                pct start "$ctid"
                sleep 3
            else
                log_ok "LXC ${ctid} (${CT_NAME}) 이미 실행 중"
            fi
        fi
    done

    echo ""
    log_ok "🎉 모든 스토리지 및 미디어 서비스가 안전하게 기동되었습니다!"
    show_status
}

# ------------------------------------------------------------------------------
# 3. 안전 순차 종료 (Graceful Down)
# ------------------------------------------------------------------------------
power_down() {
    echo -e "${YELLOW}====================================================${NC}"
    echo -e "${YELLOW}       🛑 NAS 및 미디어 서비스 순차 안전 종료 시작   ${NC}"
    echo -e "${YELLOW}====================================================${NC}"

    # 1단계: LXC 컨테이너 역순 종료 (NFS 마운트 해제 및 DB 안전 종료)
    log_info "1단계: 미디어 서비스 LXC 컨테이너 안전 종료 중 (DB/캐시 플러시)..."
    for ctid in "${LXC_SHUTDOWN_ORDER[@]}"; do
        if pct status "$ctid" &>/dev/null; then
            CT_STATE=$(pct status "$ctid" | awk '{print $2}')
            CT_NAME=$(pct config "$ctid" | grep "hostname:" | awk '{print $2}')
            if [ "$CT_STATE" == "running" ]; then
                log_info "LXC ${ctid} (${CT_NAME}) Graceful Stop 중 (최대 15초)..."
                pct shutdown "$ctid" -timeout 15 || pct stop "$ctid"
            fi
        fi
    done

    # 2단계: 헤놀로지 VM 101 종료 (스토리지 I/O 완료 후 최종 셧다운)
    if qm status "$NAS_VM_ID" &>/dev/null; then
        VM_STATE=$(qm status "$NAS_VM_ID" | awk '{print $2}')
        if [ "$VM_STATE" == "running" ]; then
            log_info "2단계: 헤놀로지 VM 101 Graceful Shutdown 중 (Btrfs 플러시)..."
            qm shutdown "$NAS_VM_ID" -timeout 30 || qm stop "$NAS_VM_ID"
            log_ok "헤놀로지 VM 101 안전 종료 완료!"
        fi
    fi

    echo ""
    log_ok "🛡️ 모든 컨테이너 및 스토리지가 데이터 손실 없이 안전하게 종료되었습니다."
}

# ------------------------------------------------------------------------------
# 4. Proxmox 부팅/종료 시퀀스 일괄 등록 (Init Order)
# ------------------------------------------------------------------------------
init_pve_order() {
    log_info "Proxmox 호스트 레벨의 자동 부팅/종료 순서(order/up/down) 일괄 등록 중..."
    
    # 헤놀로지 VM 101: 1순위 부팅 (30초 대기), 마지막 종료 (30초 대기)
    qm set 101 --onboot 1 --startup "order=1,up=30,down=30" || true
    
    # LXC 컨테이너들: 2순위 부팅, 먼저 종료
    pct set 102 --onboot 1 --startup "order=2,up=5,down=10" 2>/dev/null || true  # AdGuard
    pct set 103 --onboot 1 --startup "order=2,up=10,down=15" 2>/dev/null || true # Immich
    pct set 104 --onboot 1 --startup "order=2,up=5,down=10" 2>/dev/null || true  # Gonic
    pct set 105 --onboot 1 --startup "order=2,up=10,down=15" 2>/dev/null || true # Jellyfin
    pct set 106 --onboot 1 --startup "order=2,up=5,down=10" 2>/dev/null || true  # Dev Web

    log_ok "Proxmox 호스트 기동/종료 순서 등록 완료!"
}

# ------------------------------------------------------------------------------
# 진입점 분기
# ------------------------------------------------------------------------------
case "$1" in
    status)
        show_status
        ;;
    up|start)
        power_up
        ;;
    down|stop)
        power_down
        ;;
    shutdown-host|poweroff)
        power_down
        log_warn "5초 후 Proxmox 호스트 전원을 완전히 끕니다 (Poweroff)..."
        sleep 5
        poweroff
        ;;
    reboot-host|reboot)
        power_down
        log_warn "5초 후 Proxmox 호스트를 안전하게 재부팅합니다 (Reboot)..."
        sleep 5
        reboot
        ;;
    init-order)
        init_pve_order
        ;;
    *)
        echo "사용법: $0 {status|up|down|shutdown-host|reboot-host|init-order}"
        exit 1
        ;;
esac
