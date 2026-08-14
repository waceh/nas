# 디스크 패스스루 설정 가이드

대상: WD White 8TB + White 18TB (COLD) → 헤놀로지(Xpenology) VM 101 Raw 패스스루  
*(💡 **WD Gold 4TB**는 VM 패스스루가 아닌 Proxmox 호스트 레벨 스토리지로 마운트하여 **백업 금고 & Immich 원본 저장소**로 활용)*  
전제: `01_proxmox_install.md` 완료, BIOS에서 VT-d 활성화됨, HDD SATA 케이블 재결착 완료

## 0. 원칙
- `/dev/sda`, `/dev/sdb` 같은 이름은 재부팅 시 순서 바뀔 수 있음 → 반드시 **by-id** 경로 사용
- 디스크 전체를 raw로 VM에 넘기는 방식 사용 (파티션 단위 X, 컨트롤러 전체 PCIe 패스스루 X)

## 1. 디스크 식별
```bash
lsblk -o NAME,SIZE,MODEL,SERIAL
ls -la /dev/disk/by-id/ | grep -v part
```
출력 예시:
```
ata-WDC_WD80EMAZ-00WJTA0_... -> ../../sdb   (WD White 8TB - Cold Storage)
ata-WDC_WUH721818ALE604_...  -> ../../sdc   (White 18TB - Cold Media)
ata-WDC_WD40EFRX-...         -> ../../sdd   (WD Gold 4TB - Backup & Photos)
```
모델명/용량으로 디스크 매칭. 헷갈리면 `hdparm -I /dev/sdX | grep Serial`로 시리얼 재확인 후 라벨/구매내역과 대조.

## 2. VM에 디스크 패스스루 (헤놀로지 VM 101)
VM ID 확인:
```bash
qm list
```

Cold 디스크 2개 추가 (예: VM ID 101, White 8TB/18TB를 SATA 버스로 연결):
```bash
# 8TB Cold HDD (WD White / WD80EMAZ)를 sata2로 패스스루
qm set 101 -sata2 /dev/disk/by-id/ata-WDC_WD80EMAZ-00WJTA0_XXXXXXXX

# 18TB Cold HDD (WD White / WUH721818ALE604)를 sata3로 패스스루
qm set 101 -sata3 /dev/disk/by-id/ata-WDC_WUH721818ALE604_YYYYYYYY
```
- Xpenology(헤놀로지)는 부트로더가 SATA 컨트롤러 인식에 민감 → **SATA 버스** 권장 (`-scsi`보다 호환성 좋음)
- `sata0`(가상 부트로더 `rr.img`), `sata1`(DSM 32GB OS 가상디스크)은 그대로 유지하고 추가 슬롯에 패스스루

### 💡 WD Gold 4TB는 Proxmox 로컬 백업/사진 스토리지로 등록
WD Gold 4TB는 헤놀로지 패스스루 대신 Proxmox 호스트에서 포맷 후 백업 금고로 마운트:
```bash
# Proxmox GUI: pve 노드 -> Disks -> Directory -> Create Directory (Filesystem: ext4, Disk: WD Gold 4TB)
# 용도: VM 일일 스냅샷(vzdump) 백업 저장소, Immich 원본 미디어 디렉토리 마운트
```

적용 확인:
```bash
qm config 101
```

## 3. VM 부팅 후 확인
- 헤놀로지 VM 부팅 → DSM에서 스토리지 매니저 열어서 기존 볼륨 정상 인식되는지 확인
- 정상이면 RAID/볼륨 정보 그대로 유지된 상태로 마운트됨 (디스크 순서 바뀌어도 by-id라 문제없음)
- 인식 안 되면: `qm config <id>`에서 버스 타입 확인 → SATA로 되어 있는지, 디스크 순서가 기존 DSM 구성과 어긋나지 않는지 점검

## 4. Plex LXC에서 미디어 디스크 접근
LXC는 VM과 달리 raw 블록 디바이스 패스스루 대신 **디렉터리 마운트(bind mount)** 방식 사용.

방법 A) 헤놀로지 DSM이 이미 디스크를 점유 중이면 → **NFS/SMB 공유**로 접근
```bash
# Plex LXC 컨테이너 안에서
apt install -y nfs-common
mkdir -p /mnt/media
mount -t nfs <헤놀로지_VM_IP>:/volume1/media /mnt/media
```
영구 마운트는 LXC 내부 `/etc/fstab`에 등록.

방법 B) 디스크가 Proxmox 호스트에 직접 마운트되어 있고 LXC와 공유할 경우 → **bind mount**
```bash
# Proxmox 호스트에서
pct set 105 -mp0 /mnt/pve/cold-storage,mp=/mnt/media
```
단, 같은 디스크를 헤놀로지 VM에 통째로 패스스루(raw)한 상태면 호스트에서 동시에 마운트 불가 — 방법 A(NFS/SMB) 사용 권장.

## 5. 주의사항
- 같은 물리 디스크를 VM 패스스루(raw)와 호스트 마운트에 동시에 쓰면 데이터 손상 위험 → 반드시 하나의 경로만 사용
- 디스크 교체/증설 시 by-id 값 다시 확인 (시리얼 기준이라 안 바뀜, 안심하고 재부팅 가능)
- 패스스루 해제 시: `qm set 101 -delete sata1` 형태로 제거 후 VM 재시작
