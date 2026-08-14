# WD Gold 4TB 패스스루 및 통합 스토리지 구성 가이드

이미 8TB(`sata2`), 18TB(`sata3`)가 헤놀로지 VM에 연결된 상태에서, **`WD Gold 4TB`를 추가 패스스루(`sata4`)하고 Immich 사진 원본, 수동 GUI 파일 저장, Proxmox VM 백업 금고**로 구축하는 전체 실전 가이드입니다.

---

## 📋 구성 개요 및 구조

```
💾 WD Gold 4TB (헤놀로지 sata4 패스스루 ➔ Volume 2 - Btrfs)
 ├── 📁 /volume2/immich-photos  (NFS) ➔ Immich 원본 사진/동영상 저장소
 ├── 📁 /volume2/personal-data  (SMB) ➔ 사용자 수동 저장 (Mac Finder / Win 탐색기 / File Station)
 └── 📁 /volume2/pve-backups    (NFS) ➔ Proxmox VE 전체 VM/LXC 스냅샷 백업 금고 (vzdump)
```

---

## 1단계. Proxmox 터미널에서 WD Gold 4TB 고유 ID(`by-id`) 확인

Proxmox Web UI의 **`>_ Shell`** 메뉴 또는 SSH(`root@<Proxmox_IP>`)에서 실행합니다:

```bash
ls -la /dev/disk/by-id/ | grep -v part
```

*출력 예시:*
```
ata-WDC_WD80EMAZ-00WJTA0_XXXXXXXX -> ../../sdb   (기존 연결된 8TB)
ata-WDC_WUH721818ALE604_YYYYYYYY  -> ../../sdc   (기존 연결된 18TB)
ata-WDC_WD40EFRX-ZZZZZZZZ         -> ../../sdd   (👈 이 4TB 디스크 ID 복사)
```
> `ata-WDC_WD40...` 형태의 전체 ID 문자열을 복사합니다.

---

## 2단계. 헤놀로지 VM(101)에 4TB 디스크 연결 (`sata4`)

8TB(`sata2`), 18TB(`sata3`)에 이어 **`sata4`** 슬롯으로 4TB 디스크를 연결합니다:

```bash
# WD Gold 4TB를 sata4에 연결 (복사한 ID 값으로 변경)
qm set 101 -sata4 /dev/disk/by-id/ata-WDC_WD40EFRX-ZZZZZZZZ
```

### 연결 확인
```bash
qm config 101
```
*출력 결과에 `sata2`, `sata3`, `sata4`가 모두 정상 등록되어 있는지 확인합니다.*

---

## 3단계. 헤놀로지 DSM에서 4TB 디스크 볼륨 생성

1. **헤놀로지 VM 실행**: `qm start 101`
2. 웹 브라우저에서 헤놀로지 DSM(`http://<VM_IP>:5000`) 접속.
3. **`메인 메뉴` ➔ `스토리지 관리자 (Storage Manager)` ➔ `스토리지`** 진입.
4. 새로 인식된 4TB 드라이브에서 **[스토리지 풀 생성]** 클릭:
   - **RAID 유형**: **`Basic`** (또는 `SHR - 데이터 보호 없음`)
   - **드라이브 선택**: 4TB WD Gold 체크
   - **드라이브 검사**: 건너뛰기
   - **파일 시스템**: **`Btrfs`** (스냅샷 및 데이터 무결성 지원)
   - **할당 크기**: `최대`
5. 생성이 완료되면 **`볼륨 2 (Volume 2 - 약 3.6TB)`** 가 활성화됩니다.

---

## 4단계. 4TB 볼륨 안에 3대 공유 폴더 생성 & 권한 설정

헤놀로지 DSM **`제어판 ➔ 공유 폴더 ➔ 생성`** 에서 용도별로 3개 폴더를 만듭니다:

### ① `immich-photos` (Immich 미디어 저장소)
1. **위치**: 볼륨 2 (4TB)
2. **NFS 권한 탭** ➔ **[생성]**:
   - **호스트/IP**: Proxmox 호스트 IP 또는 Immich LXC IP (또는 서브넷 `192.168.50.0/24`)
   - **권한**: `읽기/쓰기`
   - **Squash**: `매핑 없음` (또는 `admin으로 모든 사용자 매핑`)
   - **비동기(Asynchronous)**: 활성화 체크

### ② `personal-data` (수동 GUI 저장소)
1. **위치**: 볼륨 2 (4TB)
2. **권한 탭**: 사용자 계정에 `읽기/쓰기` 권한 부여 (일반 SMB 공유).

### ③ `pve-backups` (Proxmox 백업 금고)
1. **위치**: 볼륨 2 (4TB)
2. **NFS 권한 탭** ➔ **[생성]**:
   - **호스트/IP**: Proxmox 호스트 IP (예: `192.168.50.2`)
   - **권한**: `읽기/쓰기`
   - **Squash**: `root를 admin으로 매핑` (또는 `매핑 없음`)
   - **비동기**: 활성화 체크

> 💡 **NFS 서비스 켜기**: DSM `제어판` ➔ `파일 서비스` ➔ `NFS` 탭 ➔ **[NFS 서비스 활성화]** 체크.

---

## 5단계. 각 서비스 및 PC 연동 실전

### 1. PC / 맥북에서 수동 파일 저장 (외장하드처럼 사용)
- **Mac Finder**: Finder 실행 ➔ `Cmd + K` ➔ `smb://<헤놀로지_IP>/personal-data` 연결.
- **Windows**: 파일 탐색기 주소창 ➔ `\\<헤놀로지_IP>\personal-data` 연결.
- **Web GUI**: 브라우저로 DSM 접속 ➔ **`File Station`** 앱에서 마우스 드래그 & 드롭으로 업로드.

### 2. Proxmox VE 전체 백업 금고 등록 (`vzdump`)
1. Proxmox 웹 관리자(`https://<Proxmox_IP>:8006`) 접속.
2. 좌측 트리에서 **`Datacenter`** 클릭 ➔ **`Storage`** ➔ **`Add` ➔ `NFS`** 선택:
   - **ID**: `wd4tb-backup`
   - **Server**: `<헤놀로지_IP>` (예: `192.168.50.101`)
   - **Export**: `/volume2/pve-backups`
   - **Content**: **`VZDump backup file`** 선택
3. **[Add]** 클릭 완료.
4. 이제 `Datacenter` ➔ `Backup` 메뉴에서 일일/주간 VM 자동 스냅샷 백업 일정을 추가하면 4TB 엔터프라이즈 디스크에 안전하게 보관됩니다.

### 3. Immich 사진/동영상 원본 저장소 연동
1. Immich 컨테이너(또는 LXC) 내부의 `/etc/fstab`에 NFS 자동 마운트 추가:
   ```bash
   <헤놀로지_IP>:/volume2/immich-photos  /mnt/immich-photos  nfs  defaults,_netdev  0  0
   ```
2. 마운트 적용:
   ```bash
   mount -a
   ```
3. Immich의 `.env` 환경설정 파일에서 사진 업로드 경로 지정:
   ```env
   UPLOAD_LOCATION=/mnt/immich-photos
   ```

---

## 6단계. 부팅 순서 (Startup Order) 최적화

헤놀로지 VM이 켜져서 NFS 공유를 열어주어야 Proxmox 백업과 Immich/Jellyfin 마운트가 정상 작동하므로 부팅 순서를 지정합니다:

1. Proxmox GUI ➔ **`VM 101 (헤놀로지)` ➔ `Options` ➔ `Start/Shutdown order`**:
   - **Start at boot**: `Yes`
   - **Startup order**: `1`
   - **Startup delay**: `0`
2. **`LXC 105 (Jellyfin)` 및 기타 컨테이너 ➔ `Options` ➔ `Start/Shutdown order`**:
   - **Start at boot**: `Yes`
   - **Startup order**: `2`
   - **Startup delay**: `30` (헤놀로지 부팅 완료 대기)
