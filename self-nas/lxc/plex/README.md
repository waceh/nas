# Plex (Proxmox LXC)

Xpenology 내부 Docker 아닌 별도 Proxmox LXC 컨테이너로 구동하는 Plex 설정.
전제: `docs/04_xpenology_install.md` 완료, 헤놀로지 VM 정상 동작 확인됨

## 0. 왜 LXC로 분리하나
- Plex 트랜스코딩 성능/자원 격리를 헤놀로지 VM과 분리
- 커널 공유해도 되는 가벼운 서비스라 VM보다 오버헤드 적은 LXC 선택

## 1. LXC 생성
Proxmox 웹 UI 또는 CLI:
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
- **Unprivileged** 기본 권장 (보안상 안전). 단, 하드웨어 트랜스코딩(iGPU 패스스루) 쓰려면 `/dev/dri` 접근 위해 privileged 전환 또는 unprivileged + uid/gid 매핑 필요 (5-2 참고)
- 템플릿 목록 확인: `pveam available`, 다운로드: `pveam download local debian-12-standard_12.x_amd64.tar.zst`
- ASUS 공유기에서 이 LXC도 고정 IP 예약 권장 (`02_network_setup.md` 방식과 동일)

## 2. 미디어 디스크 접근
`03_disk_passthrough.md`의 **방법 A(NFS/SMB)** 사용 — White 8TB/18TB 디스크는 이미 헤놀로지 VM에 raw로 패스스루된 상태라 호스트/다른 LXC에서 직접 마운트 불가.

LXC 컨테이너 안에서:
```bash
apt update && apt install -y nfs-common
mkdir -p /mnt/media
```
`/etc/fstab`에 추가 (영구 마운트):
```
<헤놀로지_VM_IP>:/volume1/media  /mnt/media  nfs  defaults,_netdev  0  0
```
```bash
mount -a
df -h /mnt/media   # 정상 마운트 확인
```
- 헤놀로지 DSM 쪽에서 미리 NFS 서비스 활성화 + 공유폴더 NFS 권한 설정 필요 (제어판 → 파일 서비스 → NFS)
- 헤놀로지 쪽 NFS 규칙에서 LXC IP 또는 서브넷 허용 등록

## 3. Plex 설치
```bash
apt update && apt install -y curl gnupg apt-transport-https

curl https://downloads.plex.tv/plex-keys/PlexSign.key | gpg --dearmor -o /usr/share/keyrings/plex.gpg
echo "deb [signed-by=/usr/share/keyrings/plex.gpg] https://downloads.plex.tv/repo/deb public main" \
  > /etc/apt/sources.list.d/plexmediaserver.list

apt update && apt install -y plexmediaserver
```

## 4. 라이브러리 경로 설정
- 브라우저에서 `http://<LXC_IP>:32400/web` 접속
- 라이브러리 추가 시 경로: `/mnt/media/...` (2번에서 마운트한 경로 하위)
- Plex 계정 로그인 및 원격 접속 설정은 필요에 따라 진행

## 5. 하드웨어 트랜스코딩 (선택)
iGPU(i5-9500T UHD630) 활용해 트랜스코딩 부하 줄이고 싶으면:

### 5-1. Proxmox 호스트에서 GPU 확인
```bash
lspci | grep -i vga
ls -la /dev/dri
```

### 5-2. LXC에 `/dev/dri` 패스스루
Proxmox 호스트 LXC 설정(`/etc/pve/lxc/105.conf`)에 추가:
```
lxc.cgroup2.devices.allow: c 226:0 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,create=file
```
- unprivileged LXC면 컨테이너 안 `video`/`render` 그룹 GID를 호스트와 매핑 필요할 수 있음 — 안 되면 우선 privileged로 전환 후 재시도
- LXC 재시작 후 컨테이너 안에서 `/dev/dri/renderD128` 보이는지 확인
- Plex 설정 → Transcoder → 하드웨어 가속 활성화

## 6. 확인 체크리스트
- [ ] LXC 생성 및 고정 IP 확인
- [ ] NFS 마운트 정상 (`/mnt/media` 접근 가능)
- [ ] Plex 웹 UI 접속 (`:32400/web`)
- [ ] 라이브러리 스캔 및 재생 테스트
- [ ] (선택) 하드웨어 트랜스코딩 동작 확인

## 다음 단계
Plex 안정화 후 나머지 도커 서비스(*arr Stack, Nextcloud, Immich, AdGuard Home, Vaultwarden)는 헤놀로지 VM 내부 Container Manager로 순차 배포 (`README.md` 체크리스트 참고).
