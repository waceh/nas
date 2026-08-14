# 헤놀로지(Xpenology) VM 설치 가이드

전제: `01_proxmox_install.md`, `02_network_setup.md`, `03_disk_passthrough.md` 완료
대상 디스크: WD Gold 4TB, WD White 8TB, WD White 18TB (by-id로 SATA 패스스루 설정)

## 0. 어디에 설치하나 — VM (LXC 아님)
DSM은 자체 커널/부트로더가 통째로 필요해서 호스트 커널을 공유하는 LXC로는 못 돌림 → **반드시 별도 VM**으로 생성.
LXC는 이후 Jellyfin 등 커널 공유해도 되는 가벼운 서비스용으로 따로 씀 (`lxc/jellyfin/README.md`).

> ⚠️ **데이터 보호 및 디스크 분리/결착 절차**  
> 1. Proxmox VE 설치 및 Xpenology 최초 VM/부트로더 구성 단계에서는 데이터 안전을 위해 **HDD 3대(WD White 8TB, WD White 18TB, WD Gold 4TB)의 SATA 케이블을 분리해 둡니다.**  
> 2. VM 및 부트로더 생성이 완료되면 시스템을 종료(`poweroff`)한 후 **SATA 케이블을 재결착**합니다.  
> 3. Proxmox 재부팅 후 물리 디스크 패스스루를 연결합니다. (자동 설치 스크립트 실행 시 케이블이 연결되어 있으면 미사용 디스크가 자동 인식되며, 케이블 분리 상태에서 스크립트를 먼저 실행한 경우 케이블 결착 후 수동으로 `qm set 101 -sata1 ...` 연결하시면 됩니다.)

> 💡 **빠른 자동 설치 (추천)**  
> Proxmox VE Web UI의 **`>_ Shell`** 메뉴 또는 SSH로 Proxmox 호스트(`root@<Proxmox_IP>`) 접속 후 아래 명령어를 원클릭으로 실행하면 `jq` 패키지 설치부터 최신 RR 부트로더 다운로드, VM 101 생성, 가상 USB 부팅 구성까지 한 번에 완료됩니다.
> 
> **1) 실행 위치**: Proxmox 웹 관리자(`https://<Proxmox_IP>:8006`) ➔ 좌측 노드(pve) 선택 ➔ 우측 상단 **`>_ Shell`** 버튼 클릭 (또는 SSH 접속)  
> **2) 명령어 실행 (복사 후 붙여넣기)**:
> ```bash
> # [옵션 A] self-nas 맞춤형 스크립트 (추천)
> apt update && apt install curl jq unzip -y && \
> curl -fsSL https://raw.githubusercontent.com/waceh/nas/main/self-nas/scripts/install_xpenology.sh -o install_xpenology.sh && \
> chmod +x install_xpenology.sh && \
> ./install_xpenology.sh
> 
> # [옵션 B] dalso 기반 TUI 대화형 마법사 스크립트 (waceh/nas 내 보관본)
> apt update && apt install curl jq unzip whiptail -y && \
> curl -fsSL https://raw.githubusercontent.com/waceh/nas/main/self-nas/scripts/pve_xpenol_install.sh -o pve_xpenol_install.sh && \
> chmod +x pve_xpenol_install.sh && \
> ./pve_xpenol_install.sh
> ```
> 
> **3) 스크립트 완료 후 단계**:
> 1. VM 101 시작 (`qm start 101`)
> 2. 웹 브라우저에서 `http://<VM_IP>:7681` 접속 ➔ RR 로더 설정 (모델: `DS920+` 또는 `SA6400`, DSM: `DSM 7.2.2`)
> 3. 설정 완료 후 호스트 종료 (`poweroff`) ➔ COLD 디스크(WD White 8TB/18TB) SATA 케이블 재결착 ➔ 서버 부팅
> 4. 디스크 패스스루 연결 (`qm set 101 -sata2 ...`)

## 1. 로더 준비 (ARPL / RR)
- 구형 jun's loader는 최신 DSM 미지원 → **ARPL(Automated Redpill Loader)** 또는 후속 프로젝트 **RR(Redpill Recovery)** 사용 권장
- GitHub에서 최신 릴리스 이미지(.img) 다운로드
- 진행 전 커뮤니티(reddit r/synology, xpenology 포럼 등)에서 현재 안정적인 로더+DSM 버전 조합 확인 — 조합 안 맞으면 부팅 시 커널 패닉 흔함

## 2. VM 생성
```bash
qm create 101 \
  --name xpenology \
  --memory 4096 \
  --cores 2 \
  --sockets 1 \
  --cpu host \
  --bios seabios \
  --ostype other \
  --net0 virtio,bridge=vmbr0
```
- BIOS는 **SeaBIOS** (UEFI 아님) — 로더가 레거시 부팅 방식 기대
- 머신 타입은 Proxmox 기본값(i440fx/pc) 권장 (q35보다 로더 호환성 이슈 적음)
- RAM/코어는 README 스펙(2 Core/4GB) 기준

## 3. 로더 이미지 붙이기
```bash
qm importdisk 101 arpl.img local-lvm --format qcow2
qm set 101 -sata0 local-lvm:vm-101-disk-0
qm set 101 -boot order=sata0
```
- 로더는 `sata0`에 부팅 디스크로 연결 (실제 시놀로지 부팅 USB 역할)

## 4. 데이터 디스크 연결 (HDD 3대 패스스루)
`03_disk_passthrough.md` 및 `05_wd_gold_storage_setup.md`에서 준비한 by-id 경로 그대로 sata2, sata3, sata4에 연결:
```bash
# 1. 8TB Cold HDD (WD80EMAZ)
qm set 101 -sata2 /dev/disk/by-id/ata-WDC_WD80EMAZ-00WJTA0_XXXXXXXX

# 2. 18TB Cold HDD (WUH721818ALE604)
qm set 101 -sata3 /dev/disk/by-id/ata-WDC_WUH721818ALE604_YYYYYYYY

# 3. 4TB Gold HDD (Immich / 수동저장 / PVE 백업금고)
qm set 101 -sata4 /dev/disk/by-id/ata-WDC_WD40EFRX-ZZZZZZZZ
```
- 기존 DSM에서 쓰던 디스크 슬롯 순서와 최대한 맞춰주는 게 안전 (볼륨 인식 문제 예방)

## 5. MAC 주소 확인/고정
로더가 시리얼 번호와 매칭되는 MAC 주소를 요구하는 경우가 많음. 필요시 지정:
```bash
qm set 101 -net0 virtio=<지정할MAC>,bridge=vmbr0
```
개인 사용 목적이면 QuickConnect 등 일부 클라우드 연동 기능만 제한되고 로컬 사용엔 지장 없음.

## 6. 스냅샷 (안전장치)
설치 진행 전 스냅샷 하나 걸어두기:
```bash
qm snapshot 101 before-dsm-install
```

## 7. 로더 부팅 및 설정
1. VM 시작: `qm start 101`
2. 로더 웹 UI 접속 (보통 `http://<VM IP>:7681`, 로더 화면에 안내되는 주소 확인)
3. 모델(Model) 선택 — **기존에 쓰던 모델과 동일하게** 선택해야 기존 볼륨/설정 인식 확률 높음 (모델 모르면 DSM 백업 정보나 이전 관리 화면 캡처 확인)
4. 빌드 넘버, 시리얼 설정 후 저장 → 부팅

## 8. DSM 설치 (마이그레이션 모드)
1. 같은 네트워크 PC에서 `find.synology.com` 또는 Synology Assistant 실행 → 새 장치 검색
2. 설치 화면에서 **"마이그레이션"** 옵션 선택 (재설치, 데이터 보존)
   - ⚠️ "설치" 대신 **초기화/전체 설치 절대 선택 금지** — 기존 데이터 삭제됨
3. DSM 최신 버전 자동 감지 후 설치 진행
4. 설치 완료 후 재부팅 → 기존 계정/공유폴더/Docker 설정 그대로 살아있는지 확인

## 9. 설치 후 스토리지 마운트 및 구성 가이드

### 9-1. 기존 시놀로지 디스크 복구 (데이터 100% 보존)
> 🚨 **주의: 절대로 "스토리지 풀 생성" 버튼을 누르지 마세요! (포맷되어 데이터가 모두 삭제됩니다)**

1. DSM ➔ **`스토리지 관리자 (Storage Manager)`** ➔ **`스토리지 (Storage)`** 진입
2. 상단 경고창 또는 우측 상단 **`... (더보기)`** 클릭 ➔ **`온라인 조립 (Online Assemble)`** 실행
3. 포맷 없이 기존 파일 시스템(Btrfs/ext4) 및 공유 폴더 데이터가 100% 원본 그대로 복원됩니다.

### 9-2. 신규 독립 디스크 구성 (RAID 미사용 시)
여러 디스크(예: 8TB, 18TB)를 각각 독립된 개별 스토리지로 사용하려는 경우:

* **RAID 유형**: **`Basic`** 선택 (Basic 옵션이 없는 경우 `SHR` 선택 후 드라이브 1개 지정)
* **`JBOD` 사용 금지**: 8TB+18TB를 26TB 1개로 합치는 방식이지만, 드라이브 1개만 고장 나도 26TB 전체 데이터가 증발하므로 절대 비추천
* **파일 시스템**: **`Btrfs`** 선택 (스냅샷 복구, 데이터 무결성 검사 지원)
* **드라이브 검사**: `건너뛰기` 선택 (검사 시 수 시간 소요됨)
* **할당된 크기**: **`최대 (Max)`** 선택

---

## 10. Proxmox 네트워크 & 저장소 트러블슈팅 노트

### 10-1. `Temporary failure resolving ...` (DNS 실패)
`/etc/resolv.conf` 파일에 외부 DNS 서버가 지정되지 않은 경우 발생:
```bash
cat <<EOF > /etc/resolv.conf
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
```

### 10-2. `401 Unauthorized` (Proxmox 유료 저장소 경고)
Proxmox 설치 기본값인 Enterprise/Ceph 유료 레포를 삭제하고 무료(No-Subscription) 레포로 전환:
```bash
rm -f /etc/apt/sources.list.d/*enterprise* /etc/apt/sources.list.d/ceph*
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list
apt update
```

## 11. 문제 발생 시
- 부팅 안 됨/커널 패닉 → 로더-DSM 버전 조합 재확인, 최신 로더로 교체
- 볼륨 인식 안 됨 → 디스크 슬롯 순서(sata1/sata2) 원래 구성과 비교, `qm config 101`로 확인
- 롤백 필요 시:
```bash
qm rollback 101 before-dsm-install
```

## 다음 단계
헤놀로지 VM 정상 동작(Pure NAS 스토리지 및 NFS/SMB 공유) 확인되면 → Proxmox Native LXC 컨테이너 구성 (AdGuard, Immich, Jellyfin, Dev Web)으로 진행. (상세 절차: `POST_PROXMOX_SETUP_GUIDE.md` Step 5 참고)
