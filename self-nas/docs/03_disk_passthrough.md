# 디스크 패스스루 설정 가이드

대상: **HDD 3대 전체 → 헤놀로지(Xpenology) VM 101 Raw 패스스루**
- **WD Gold 4TB** (`WD40EFRX`) → `sata4` (Immich 사진 & Jellyfin 미디어 / 수동 저장 / Proxmox 백업 금고)
- **WD White 8TB** (`WD80EMAZ-00WJTA0`) → `sata2` (Cold 스토리지 풀)
- **WD White 18TB** (`WUH721818ALE604`) → `sata3` (Cold 아카이브 풀)

전제: `01_proxmox_install.md` 완료, BIOS에서 VT-d 활성화됨, HDD SATA 케이블 재결착 완료

---

## 0. 패스스루 기본 원칙
1. `/dev/sda`, `/dev/sdb` 같은 디바이스명은 재부팅 시 순서가 바뀔 수 있으므로, **반드시 고유 식별자인 `/dev/disk/by-id/` 경로**를 사용합니다.
2. 디스크 전체를 raw 블록 디바이스로 VM에 연결합니다.
3. Xpenology(헤놀로지)는 부트로더 호환성을 위해 **SATA 버스**(`-sata2`, `-sata3`, `-sata4`)로 연결합니다.
   - `sata0`: 가상 부트로더 (`rr.img`)
   - `sata1`: DSM OS 전용 32GB SSD 가상디스크

---

## 1. Proxmox 터미널에서 디스크 식별

Proxmox Web UI의 `>_ Shell` 또는 SSH(`root@<Proxmox_IP>`)에서 디스크 목록을 조회합니다:

```bash
lsblk -o NAME,SIZE,MODEL,SERIAL
ls -la /dev/disk/by-id/ | grep -v part
```

*출력 예시:*
```
ata-WDC_WD80EMAZ-00WJTA0_XXXXXXXX -> ../../sdb   (WD White 8TB)
ata-WDC_WUH721818ALE604_YYYYYYYY  -> ../../sdc   (WD White 18TB)
ata-WDC_WD40EFRX-ZZZZZZZZ         -> ../../sdd   (WD Gold 4TB)
```

---

## 2. 헤놀로지 VM(101)에 디스크 3대 패스스루 연결

VM ID를 확인한 후, 각 디스크를 가상 SATA 포트에 연결합니다:

```bash
# 1. 8TB Cold HDD 연결 (sata2)
qm set 101 -sata2 /dev/disk/by-id/ata-WDC_WD80EMAZ-00WJTA0_XXXXXXXX

# 2. 18TB Cold 미디어 HDD 연결 (sata3)
qm set 101 -sata3 /dev/disk/by-id/ata-WDC_WUH721818ALE604_YYYYYYYY

# 3. 4TB Gold (Immich/Jellyfin/수동저장/백업금고) HDD 연결 (sata4)
qm set 101 -sata4 /dev/disk/by-id/ata-WDC_WD40EFRX-ZZZZZZZZ
```

### 연결 결과 확인
```bash
qm config 101
```
*설정 출력에 `sata0`, `sata1`, `sata2`, `sata3`, `sata4`가 모두 정상 등록되었는지 확인합니다.*

---

## 3. 헤놀로지 부팅 및 DSM 스토리지 구성

1. **VM 부팅**:
   ```bash
   qm start 101
   ```
2. **DSM 웹 UI(`http://<VM_IP>:5000`) 접속** ➔ **`스토리지 관리자 (Storage Manager)`** 진입:
   - **기존 데이터 디스크인 경우**: 상단 알림 또는 `...` 메뉴 ➔ **`온라인 조립 (Online Assemble)`** 클릭 (포맷 없이 100% 원본 데이터 복원).
   - **신규 디스크 개별 독립 구성 시**: RAID 유형 **`Basic`** (또는 SHR 1개 드라이브), 파일 시스템 **`Btrfs`**, 크기 **`최대`** 선택.

---

## 4. 다른 서비스(LXC / Proxmox 백업)와의 공유 및 연동

헤놀로지가 3대 디스크를 모두 장악하고 있으므로, 다른 서비스들은 **헤놀로지의 초고속 내부 네트워크 공유(NFS/SMB)**를 통해 접근합니다:

### 4-1. Jellyfin LXC (미디어 재생)
- **헤놀로지**: WD Gold 4TB 볼륨 위의 `/volume2/media`에 NFS 권한 부여 (LXC IP 허용).
- **Jellyfin LXC (`/etc/fstab`)**:
  ```bash
  <헤놀로지_IP>:/volume2/media /mnt/media nfs defaults,_netdev 0 0
  ```

### 4-2. Immich (사진/동영상 원본 저장)
- **헤놀로지**: 4TB Gold 볼륨 위의 `/volume2/immich-photos`에 NFS 권한 부여.
- **Immich 컨테이너**: 해당 NFS 경로를 `/mnt/immich-photos`로 마운트하고, Immich의 `UPLOAD_LOCATION`으로 지정.

### 4-3. Proxmox VE 전체 시스템 백업 (`vzdump`)
- **헤놀로지**: 4TB Gold 볼륨 위에 `pve-backup` 공유 폴더 생성.
- **Proxmox GUI**: `Datacenter` ➔ `Storage` ➔ `Add NFS` (서버: 헤놀로지 IP, 경로: `/volume2/pve-backup`, 용도: `VZDump backup file`).

### 4-4. 사용자 수동 파일 저장 (문서/개인 자료)
- **웹 브라우저**: 헤놀로지 DSM `File Station`에서 마우스 드래그 & 드롭.
- **PC/맥북**: Finder(Cmd+K) 또는 윈도우 탐색기에서 `smb://<헤놀로지_IP>/personal_data` 마운트.

---

## 5. 주의사항
- 같은 물리 디스크를 VM 패스스루와 Proxmox 호스트 마운트에 **동시에 물리적으로 이중 연결하지 마세요** (데이터 손상 위험).
- 디스크 교체나 증설 시 `qm set 101 -delete sataX` 명령어로 안전하게 해제할 수 있습니다.
