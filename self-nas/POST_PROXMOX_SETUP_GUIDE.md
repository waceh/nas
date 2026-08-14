# 🚀 Proxmox 설치 이후 통합 구축 가이드 (Master Setup Guide)

본 가이드는 Proxmox VE 설치(Step 3) 완료 후, **가상 부팅 디스크 개념부터 RR 부트로더 선택 이유, SSD 헤놀로지 선설치 후 HDD 디스크 패스스루 연결**, 그리고 Plex LXC 및 Docker 서비스 배포까지의 모든 과정을 한눈에 보고 따라 할 수 있도록 정리한 통합 마스터 문서입니다.

---

## 💡 핵심 개념 이해: 헤놀로지 부팅 USB vs VM 가상 부팅 디스크

### 실물 PC vs Proxmox VM 부팅 방식 비교

| 구분 | **실제 물리 PC (Host OS 바로 설치)** | **Proxmox 가상 머신 (VM)** |
| :--- | :--- | :--- |
| **부팅 매체** | **실물 USB 메모리** | **`rr.img` 가상 이미지 파일 (Virtual Boot Disk)** |
| **준비 과정** | Rufus 등으로 실물 USB에 로더 이미지 구움 | Proxmox 터미널에서 `rr.img` 파일 다운로드 |
| **연결 방식** | 본체 USB 포트에 실물 USB를 꽂음 | VM 가상 슬롯(`sata0`)에 `rr.img`를 부팅 디스크로 꽂음 |
| **부팅 순서** | 메인보드 BIOS에서 1순위를 USB로 지정 | Proxmox VM 설정에서 부팅 1순위를 `sata0`로 지정 |

- **VM 방식의 장점**: 실물 USB 메모리가 필요 없으며(USB 고장/포트 차지 0%), Proxmox 스냅샷 기능으로 부트로더 복구가 1초 만에 가능합니다.

---

## 💡 부트로더 비교: 왜 RR (Redpill Recovery) 로더인가?

| 구분 | **ARC Loader (아크 로더)** | **RR Loader (Redpill Recovery)** 🟢 *선택* |
| :--- | :--- | :--- |
| **주요 특징** | 화려한 커스텀 UI, 다양한 부가 패키지 제공 | 직관적 UI, **높은 안정성 & 강력한 복구 기능** |
| **복구 능력** | 부팅 실패 시 재빌드 필요 | **Recovery OS 모드** 내장 (장애 시 데이터/부트로더 복구 용이) |
| **Proxmox 호환성** | 좋음 (일부 드라이버 충돌 발생 가능) | **극상 (VirtIO 네트워크, 가상화 드라이버가 매우 안정적)** |

### 🎯 모델 & DSM 버전 선택 가이드 (2026년 8월 기준 최적 선택)
- **추천 모델: `DS920+`**
  - **이유**: 사용 중인 CPU가 **Intel i5-9500T (UHD 630 내장그래픽)**이므로, Intel QuickSync 하드웨어 트랜스코딩 및 GPU 가속을 공식 지원하는 **DS920+** 모델이 가장 적합합니다.

- **추천 DSM 버전: `DSM 7.2.1-69057` (Golden Release / 2026년 8월 기준 최선)**
  - 💡 **왜 최신 7.2.2 대신 7.2.1-69057인가?**
    1. **`Video Station` & 서버 미디어 코덱 지원의 마지막 버전**: 시놀로지가 DSM 7.2.2부터 Video Station 패키지를 공식 폐지하고 서버 코덱을 제거하였으므로, 순정 미디어 및 코덱 호환성을 온전히 이용하려면 7.2.1이 최선입니다.
    2. **검증된 100% 안정성**: 부트로더 커뮤니티에서 가장 완벽히 검증되어 부팅 에러, 네트워크 드라이버 충돌, 스토리지 마운트 오류가 전무합니다.
    3. **Docker 100% 최신 지원**: Docker(Container Manager), SMB/NFS 기능은 최신 7.2.2와 완전히 동일하므로 성능 손실이 없습니다.
    4. **향후 원클릭 업데이트 가능**: 7.2.1로 안정 구축 후, 추후 7.2.2 이상이 필요해지면 데이터 손실 없이 RR 로더 메뉴에서 클릭 몇 번으로 쉽게 업데이트할 수 있습니다.

---

## 📋 전체 진행 순서

1. [Step 1. Proxmox VE 설치 (Intel 710 SSD 전용, HDD 분리 상태 유지)](#step-1-proxmox-ve-설치)
2. [Step 2. 헤놀로지(Xpenology) VM 생성 및 DSM 기본 설치 (SSD 기반)](#step-2-헤놀로지-xpenology-vm-생성-및-dsm-기본-설치)
3. [Step 3. HDD 케이블 재결착 및 디스크 패스스루 (qm set)](#step-3-hdd-케이블-재결착-및-디스크-패스스루)
4. [Step 4. DSM 스토리지 관리자에서 HDD 볼륨 인식 & 마이그레이션](#step-4-dsm-스토리지-관리자에서-hdd-볼륨-인식--마이그레이션)
5. [Step 5. Plex 미디어 서버 LXC 구축 및 iGPU 트랜스코딩 (선택)](#step-5-plex-미디어-서버-lxc-구축-및-igpu-트랜스코딩)
6. [Step 6. 공유기 & 외부 접근 세팅 (내부 구축 완결 후 나중에)](#step-6-공유기--외부-접근-세팅-나중에-진행)

---

## Step 1. Proxmox VE 설치
- **상태**: HDD 3개(WD Red 8TB, White 18TB, Gold 4TB) SATA 케이블은 메인보드에서 **완전히 빼둔 상태** 유지 (Intel 710 Host OS SSD 및 Intel 530 SSD만 연결).
- **작업**: Intel 710 SSD(100GB MLC)에 Proxmox VE 8.x 설치 완료 (Host OS 전용 구동).
- **접속**: 같은 네트워크 PC에서 웹 UI(`https://<Proxmox_IP>:8006`) 및 SSH 접속 확인.

---

## Step 2. 헤놀로지 (Xpenology) VM 생성 및 DSM 기본 설치

HDD가 없는 상태에서 SSD 가상디스크에 헤놀로지 DSM 기본 시스템을 먼저 설치합니다.

### 2-1. Proxmox VM 껍데기 생성 (VM ID: 101)
Proxmox 터미널(SSH)에서 실행:
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

> 💡 **추천 원클릭 자동 설치 스크립트 (`waceh/nas` 전용)**  
> 아래 원클릭 명령어로 Proxmox 터미널에서 실행하면 최신 RR 부트로더 자동 다운로드부터 VM 101 생성, USB 부팅 구성이 한 번에 완료됩니다:
> ```bash
> apt update && apt install curl jq unzip -y && \
> curl -fsSL https://raw.githubusercontent.com/waceh/nas/main/self-nas/scripts/install_xpenology.sh -o install_xpenology.sh && \
> chmod +x install_xpenology.sh && \
> ./install_xpenology.sh
> ```
> *(달소 기반 TUI 마법사 실행 시: `curl -fsSL https://raw.githubusercontent.com/waceh/nas/main/self-nas/scripts/pve_xpenol_install.sh -o pve_xpenol_install.sh && chmod +x pve_xpenol_install.sh && ./pve_xpenol_install.sh`)*

### 2-2. 수동 부트로더 다운로드 & VM 등록 (참고용)
```bash
# 1. Proxmox 터미널(SSH) 진입 후 임시 폴더로 이동
cd /tmp

# 2. RR 로더 다운로드
curl -fsSL https://raw.githubusercontent.com/waceh/nas/main/self-nas/scripts/install_xpenology.sh -o install_xpenology.sh
```

### 2-3. DSM OS 전용 가상디스크 생성
```bash
# SSD 저장소 위에 DSM OS가 설치될 32GB 가상디스크 생성 (sata1)
qm set 101 -sata1 local-lvm:32
```

### 2-4. 헤놀로지 부팅 및 DSM 기본 설치
1. **VM 부팅**: `qm start 101`
2. **로더 웹 UI 접속**: 브라우저에서 `http://<VM_IP>:7681` 접속
   - **`Choose a model`**: `DS920+` 선택
   - **`Choose a build number`**: `7.2.1-69057` 선택
   - **`Build the loader`**: 클릭 (자동 빌드 완료 후)
   - **`Boot the loader`**: 클릭하여 헤놀로지 부팅!
3. **DSM 설치**: 새 탭에서 `find.synology.com` 접속 후 DSM 자동 설치 진행 (SSD의 `sata1` 가상디스크에 DSM 설치 완료).
4. 설치 완료 후 초기 계정 생성 및 DSM 메인 화면 진입 확인.

---

## Step 3. HDD 케이블 재결착 및 디스크 패스스루

DSM 기본 시스템이 SSD 상에 잘 구축되었으므로, 전원을 끄고 HDD를 연결하여 헤놀로지 VM에 패스스루 및 Proxmox 백업 스토리지를 구성합니다.

### 3-1. HDD 케이블 재결착 및 시스템 부팅
1. Proxmox 및 헤놀로지 VM 종료 후 **컴퓨터 전원 OFF**.
2. **WD Red 8TB**, **White 18TB**, **WD Gold 4TB** SATA 케이블을 메인보드에 결착.
3. 컴퓨터 전원 ON → Proxmox 부팅.

### 3-2. Proxmox 터미널에서 디스크 고유 ID(`by-id`) 확인
```bash
ls -la /dev/disk/by-id/ | grep -v part
```
*출력 예시:*
- WD Red 8TB (Cold): `/dev/disk/by-id/ata-WDC_WD80EFAX-XXXXXXXX`
- White 18TB (Cold): `/dev/disk/by-id/ata-WDC_WD180EDGZ-YYYYYYYY`
- WD Gold 4TB (Backup/Photo): `/dev/disk/by-id/ata-WDC_WD40EFRX-ZZZZZZZZ`

### 3-3. 헤놀로지 VM (ID: 101)에 Cold 디스크 패스스루 연결
```bash
# 8TB Cold HDD를 sata2로 패스스루
qm set 101 -sata2 /dev/disk/by-id/ata-WDC_WD80EFAX-XXXXXXXX

# 18TB Cold HDD를 sata3로 패스스루
qm set 101 -sata3 /dev/disk/by-id/ata-WDC_WD180EDGZ-YYYYYYYY
```
*(💡 **WD Gold 4TB**는 헤놀로지에 패스스루하지 않고, Proxmox 호스트 레벨에서 포맷/마운트하여 **VM 백업 금고(`vzdump`)** 및 **Immich 사진/동영상 저장소**로 활용합니다.)*

---

## Step 4. DSM 스토리지 관리자에서 HDD 볼륨 인식 & 마이그레이션

> 🚨 **주의: 기존 디스크 데이터 보존 시 절대로 "스토리지 풀 생성"을 누르지 마세요! (포맷되어 데이터가 삭제됩니다)**

1. **헤놀로지 VM 부팅**: `qm start 101`
2. **DSM 접속**: 브라우저에서 헤놀로지 DSM(`http://<VM_IP>:5000`) 접속.
3. **스토리지 관리자 (Storage Manager) 열기**:
   - **기존 시놀로지 디스크인 경우**: 상단 경고창 또는 우측 상단 `...` 버튼 ➔ **`온라인 조립 (Online Assemble)`** 클릭 (포맷 없이 기존 데이터 100% 원본 복원).
   - **신규 디스크 개별 독립 구성 시**: **`Basic`** (또는 `SHR` 선택 후 드라이브 1개 지정) 선택. *(JBOD는 디스크 1개 고장 시 전체 데이터 증발하므로 사용 금지, 파일 시스템 Btrfs 선택, 검사 건너뛰기, 크기 최대)*.
4. **확인**: 기존 공유 폴더 및 데이터 파일이 DSM 파일 스테이션(File Station)에서 모두 정상적으로 보이는지 확인.

---

## Step 5. Plex 미디어 서버 LXC 구축 및 iGPU 트랜스코딩 (선택)

헤놀로지 스토리지 조립이 완료된 후, Plex용 LXC 컨테이너를 생성하여 헤놀로지 NFS 디스크를 연동합니다.

### 5-1. Plex LXC 컨테이너 생성 (ID: 105)
```bash
pct create 105 local:vztmpl/debian-12-standard_12.x_amd64.tar.zst \
  --hostname plex \
  --cores 2 \
  --memory 2048 \
  --swap 512 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --unprivileged 1 \
  --features nesting=1
```

### 5-2. 미디어 디스크 연동 (헤놀로지 NFS 공유 마운트)
```bash
pct enter 105
apt update && apt install -y nfs-common
mkdir -p /mnt/media
echo "<헤놀로지_VM_IP>:/volume1/media /mnt/media nfs defaults,_netdev 0 0" >> /etc/fstab
mount -a
```

### 5-3. Intel iGPU (UHD630) 하드웨어 가속 패스스루
Proxmox 호스트의 `/etc/pve/lxc/105.conf` 하단에 추가:
```ini
lxc.cgroup2.devices.allow: c 226:0 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,create=file
```
- `pct restart 105` 실행 후 Plex 웹 UI(`:32400/web`)에서 트랜스코더 하드웨어 가속 체크.

---

## Step 6. 공유기 & 외부 접근 세팅 (나중에 진행)

모든 서비스가 로컬 내부 IP에서 완성된 후 진행합니다.

1. **ASUS 공유기 고정 IP 예약**: Proxmox, 헤놀로지 VM, Plex LXC MAC 주소에 고정 IP 부여.
2. **이중 NAT 정리 / 포트포워딩**: 외부 접속이 필요할 때 포트포워딩 및 DDNS/VPN 세팅.
