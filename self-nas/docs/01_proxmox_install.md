# Proxmox VE 설치 가이드

대상 하드웨어: Vpro C246 보드, Intel 710 SSD (100GB, MLC, Non-Disk) → Host OS 전용 디스크, Intel 530 SSD (120GB, MLC, Non-Disk) → 상시 고속 서비스용
HDD 3대(WD White 8TB, WD White 18TB, WD Gold 4TB)는 설치 중 SATA 케이블 분리 상태 유지 (데이터 보호, `README.md` 체크리스트 2번 참고)

## 0. 준비물

- USB 메모리 8GB 이상
- Proxmox VE ISO 다운로드: https://www.proxmox.com/en/downloads
- 설치용 PC/노트북 (부팅 USB 생성용)
- 모니터 + 키보드 (설치 대상 서버에 직결)

## 1. 부팅 USB 만들기

- balenaEtcher 또는 Rufus 사용
- ISO 그대로 USB에 굽기 (별도 압축 해제 불필요)
- macOS에서 `dd`로 만들 경우:
  ```bash
  diskutil list                 # USB 디스크 번호 확인 (예: /dev/disk4)
  diskutil unmountDisk /dev/disk4
  sudo dd if=proxmox-ve_8.x.iso of=/dev/rdisk4 bs=4m status=progress
  ```

  `disk4`가 아니라 `rdisk4` 사용 (raw 모드, 속도 훨씬 빠름). 대상 디스크 번호 반드시 재확인 — 잘못 지정 시 다른 디스크 데이터 삭제됨.

## 2. BIOS 상세 설정 가이드 (Vpro C246 보드 기준)

서버 부팅 시 `Del` 또는 `F2` 키를 연타하여 BIOS(UEFI) 설정 화면에 진입합니다.

### 2-1. CPU 및 가상화 설정 (`Advanced` ➔ `CPU Configuration` / `chipset` ➔ `System Agent Configuration`)

- **Intel Virtualization Technology (VT-x)**: `Enabled` (필수)
  - Proxmox KVM 가상머신(VM) 구동을 위한 최우선 가상화 옵션입니다.
- **Intel VT for Directed I/O (VT-d / IOMMU)**: `Enabled` (필수)
  - 위치: `chipset` ➔ `System Agent (SA) Configuration` ➔ `VT-d`
  - Proxmox 호스트가 물리 디스크(HDD), 10Gbps PCIe NIC, iGPU(내장 그래픽)를 VM/LXC 컨테이너로 직접 넘겨주는 **Hardware Passthrough**의 핵심 기능입니다.
- **Active Processor Cores**: `All`
  - CPU 코어 6개를 모두 가상화 자원으로 사용하도록 설정합니다.

### 2-2. 내장 그래픽(iGPU) 설정 (`Advanced` ➔ `Graphics Configuration`)

- **Internal Graphics (iGPU)**: `Enabled` (또는 `Auto`)
  - i5-9500T의 Intel UHD 630 내장 그래픽을 활성화합니다. Jellyfin LXC의 QuickSync 하드웨어 트랜스코딩에 필수입니다.
- **DVMT Pre-Allocated**: `64MB` 또는 `128MB`
  - 내장 그래픽 비디오 메모리 기본 할당량을 64MB 이상으로 설정하여 그래픽 가속 안정성을 확보합니다.
- **Primary Display**: `IGFX`

### 2-3. 스토리지 (SATA) 설정 (`Advanced` ➔ `SATA Configuration`)

- **SATA Controller**: `Enabled`
- **SATA Mode Selection**: `AHCI` (★ RAID / RST 모드 금지)
  - Intel 710 SSD 및 연결될 HDD들의 개별 S.M.A.R.T 정보 및 디스크 고유 ID(`by-id`)를 인식하기 위해 반드시 AHCI로 설정합니다.
- **Aggressive LPM (Link Power Management)**: `Disabled`
  - NAS 전용 고용량 HDD가 과도한 절전 모드로 진입하여 스핀다운/스핀업 지연이 발생하는 것을 방지합니다.
- **Staggered Spin-up (SSU / Sequential Spin-up)**: `Disabled` (기본값) 권장
  - **기능**: 부팅 시 여러 개의 HDD 전원을 1~2초 간격으로 순차적으로 켜서 순간 돌입 전류(Inrush Current)를 줄이는 기술입니다.
  - **권장 사항**: 현재 구성(Cooler Master 550W Gold 파워 + HDD 3대)은 부팅 시 스핀업 피크 전력이 60~70W 수준으로 550W 파워에 전혀 무리가 없습니다. 또한 일부 일반 소비자용 HDD는 SSU가 켜져 있으면 부팅 시 BIOS 디스크 드라이버에서 인식 타임아웃이 발생할 수 있으므로 **Disabled**로 유지하는 것을 권장합니다. (HDD 8대 이상 대용량 배열 구축 시 고려)

### 2-4. 부팅 및 보안 설정 (`Boot` / `Security`)

- **Secure Boot**: `Disabled` (비활성화)
  - 위치: `Boot` ➔ `Secure Boot` 또는 `Security` ➔ `Secure Boot`
  - Proxmox 커널 드라이버 및 헤놀로지 부트로더(`rr.img`)와의 보안 서명 충돌을 방지합니다.
- **Boot Mode Select**: `UEFI` (또는 `UEFI and Legacy`)
- **Boot Option Priorities (부팅 순서)**:
  - **Proxmox 설치 시**: 1순위 `USB Flash Drive`
  - **Proxmox 설치 완료 후**: 1순위 `Intel 710 SSD` (`Proxmox VE / UEFI OS`)

### 2-5. 서버 24시간 무인 운영 설정 (`Advanced` ➔ `ACPI / Power Management`)

- **Restore AC Power Loss (State After G3)**: `Power On` (또는 `Always On`)
  - 정전 후 전기가 다시 들어왔을 때 서버 전원 버튼을 누르지 않아도 자동으로 서버가 켜지도록 설정합니다.
- **Wake on LAN (PME Event Wake Up)**: `Enabled`
  - 필요한 경우 원격 매직 패킷(WOL) 부팅을 허용합니다.

설정 완료 후 `F10`을 눌러 저장(Save & Exit)하고 재부팅합니다.

## 3. Proxmox 설치

1. USB로 부팅 → `Install Proxmox VE` 선택
2. EULA 동의
3. **Target Harddisk**: Intel 710 SSD만 보이는지 확인 후 선택
   - HDD가 이미 연결된 상태라면 절대 실수로 선택하지 않도록 재확인
   - Filesystem은 기본 `ext4` 사용 (단일 SSD 구성이므로 ZFS 불필요)
4. 지역/시간대/키보드 레이아웃 설정
5. **Password**: root 비밀번호 설정, 관리용 이메일 입력
6. **Network Configuration**:
   - Management Interface: 온보드 LAN 중 하나 선택 (10Gbps NIC는 이후 용도별로 별도 설정, `02_network_setup.md` 참고)
   - Hostname(FQDN): 예) `pve.local`
   - IP 주소: 공유기 대역에 맞는 고정 IP 권장 (예: `192.168.0.10/24`)
   - Gateway: 공유기 IP
   - DNS: 공유기 IP 또는 `1.1.1.1`
7. 설정 요약 확인 후 `Install` 클릭
8. 설치 완료 후 재부팅, USB 제거

## 4. 첫 접속

- 브라우저에서 `https://<설정한 IP>:8006` 접속 (인증서 경고는 무시하고 진행)
- `root` / 설치 시 지정한 비밀번호로 로그인

## 5. 설치 직후 필수 설정

### 5-1. 구독 알림 제거 (No-Subscription repo 전환)

```bash
# enterprise repo 비활성화
sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list

# no-subscription repo 추가
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" \
  > /etc/apt/sources.list.d/pve-no-subscription.list
```

(Proxmox 버전에 따라 코드네임 `bookworm` 대신 실제 배포판 이름 확인)

### 5-2. 업데이트

```bash
apt update && apt full-upgrade -y
```

### 5-3. 웹 UI 구독 알림 팝업 제거 (선택)

```bash
sed -i.bak "s/data.status !== 'Active'/false/g" \
  /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
systemctl restart pveproxy.service
```

브라우저 캐시 삭제 후 재접속하면 팝업 사라짐.

## 6. 다음 단계

- 시스템 종료 → HDD(Red, White) SATA 케이블 결착
- 재부팅 후 `lspci`, `lsblk`로 디스크 인식 확인
- 디스크 패스스루 설정은 별도 문서 예정 (`02_network_setup.md` 다음 문서로 추가 예정)
