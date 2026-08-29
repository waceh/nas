# 📋 MTK Studio Self-NAS 작업 진행 현황 및 인수인계 노트 (00)

> 💡 **본 문서는 다른 세션이나 새로운 대화 컨텍스트로 돌아왔을 때 현재 구축 진행 상황을 즉시 파악하고, 중단된 시점부터 이어서 작업하기 위한 '마스터 인수인계(Handover & Progress)' 문서입니다.**

---

## 📌 1. 핵심 아키텍처 및 운영 철학 요약

1. **Pure Storage Core + Native LXC 격리**:
   - **헤놀로지(VM 101)**: 무거운 도커를 일체 돌리지 않고 **순수 Samba/NFS 파일 공유 전용**으로 초안정성 유지.
   - **상시 미디어 & 관제 서비스(LXC 102~107)**: Proxmox 호스트 레벨의 **초경량 Native LXC 컨테이너**로 분리하여 **Intel 530 SSD 고속 풀(`local-530`)** 위에서 구동.
2. **On-Demand (간헐적 사용) 하이브리드 전원 운영**:
   - 24/7 상시 켜두지 않고, 작업할 때 켜고(WOL) 작업 완료 후 Proxmox 호스트까지 한 번에 안전하게 끄는(`nas_power.sh shutdown-host`) 운영 패턴.
3. **RAM 디스크(`tmpfs` / `/dev/shm`) 100% 활용**:
   - 사진 썸네일 생성, 트랜스코딩 캐시를 RAM 디스크에서 처리하여 **SSD 수명(TBW) 완벽 보호**.
4. **하이브리드 2-Tier 외부 접속 보안**:
   - 가족 일상 미디어(Immich, Gonic, Jellyfin)는 공유기 포트포워딩으로 접근 편의성 보장.
   - 관리자 핵심 인프라(PVE, DSM, SSH)는 포트포워딩 완전 폐쇄 및 **Tailscale WireGuard 2FA 암호화 통로**로 완벽 은폐.

---

## 🖥️ 2. 하드웨어 & 4-Tier 스토리지 구성 현황

- **CPU**: Intel Core i5-9500T (6C/6T, Intel UHD Graphics 630 iGPU QuickSync 지원)
- **RAM**: DDR4 16GB (8GB x 2 듀얼 채널)
- **메인보드/케이스**: Vpro C246 (SATA 8포트, Onboard Multi-NIC 3포트 + 1더미) / Fractal Node 304 / 550W Gold 파워
- **네트워크 인터페이스 (Multi-NIC 3포트 풀가동)**:
  - **1번 슬롯 (`nic0` 1GbE vPro)**: `vmbr0` (공유기 메인망 `192.168.1.200`, PVE 호스트 & 상시 웹/앱 서비스)
  - **2번 슬롯 (`nic1` 2.5GbE)**: `vmbr1` (공유기 2차선 토렌트/LXC 109 전용 2.5G 브리지, 트래픽 완전 격리)
  - **3번 슬롯 (`nic2` 2.5GbE)**: `vmbr2` (맥북 1:1 직결 전용망 `10.10.10.x`, 핑 ~0.7ms)
  - **4번 슬롯**: 미실장 더미 슬롯
- **스토리지 티어링**:
  - **`Host OS 전용` Intel 710 SSD (100GB MLC, Non-Disk)**: Proxmox VE 8.x 베이스 OS (LVM 병합으로 94.5GB 여유 확보 완료)
  - **`고속 컨테이너` Intel 530 SSD (120GB MLC, Non-Disk)**: Proxmox LVM-Thin `local-530` (LXC 102~107 루트, DB 풀)
  - **`홈 & 라이프 허브` WD Gold 4TB (7200RPM Enterprise)**: 헤놀로지 Raw Passthrough ➔ 5대 공유폴더 (`photo`, `video`, `music`, `temp`, `backups`)
  - **`엔터테인먼트 Cold` WD White 8TB + 18TB (총 26TB CMR)**: 소비성 미디어(`PDS1`, `PDS2`), 평소 모터 정지(스핀다운)

---

## ⚡ 3. VM 및 LXC 서비스 구축 진행 상태

| ID / 대상 | 서비스 명칭 | vCPU / RAM | 구동 스토리지 / 볼륨 | 현재 상태 | 상세 가이드 및 스크립트 |
| :---: | :--- | :---: | :--- | :---: | :--- |
| **VM 101** | **Xpenology (Storage Core)** | 2C / 4GB | HDD 3대 Raw Passthrough (Gold 4T, White 26T) | **✅ 구축 완료** | LAN 1 `192.168.1.132` + LAN 2 `10.10.10.101` (맥북 직결 SMB), [`04_xpenology_install.md`](04_xpenology_install.md) |
| **LXC 103** | **Immich Photo Server** | 2C / 4GB | Intel 530 SSD + WD Gold (`/volume1/photo` NFS) | **✅ 구축 완료**<br/>*(10GB+ 색인 완료)* | [`09_immich_caddy_https_and_storage_setup.md`](09_immich_caddy_https_and_storage_setup.md)<br>[`setup_immich_lxc.sh`](../scripts/setup_immich_lxc.sh) |
| **LXC 104** | **Gonic Music Server** | 1C / 512MB | Intel 530 SSD + WD Gold (`/volume1/music` NFS) | **✅ 구축 완료**<br/>*(폴더 기반 스트리밍)* | [`09_immich_caddy_https_and_storage_setup.md`](09_immich_caddy_https_and_storage_setup.md)<br>[`setup_gonic_lxc.sh`](../scripts/setup_gonic_lxc.sh) |
| **LXC 105** | **Jellyfin Media Server** | 2C / 2GB | Intel 530 SSD + iGPU QuickSync + 4단 NFS (`video`, `music`, `pds1`, `pds2`) | **✅ 구축 완료**<br/>*(iGPU QSV + RAM 캐시 + NFSv3 락프리)* | [`10_graceful_power_management_and_jellyfin_guide.md`](10_graceful_power_management_and_jellyfin_guide.md)<br>[`setup_jellyfin_lxc.sh`](../scripts/setup_jellyfin_lxc.sh) |
| **LXC 107** | **Homepage + Uptime Kuma + MeTube** | 1C / 1GB | Intel 530 SSD (`local-530`) | **✅ 구축 완료**<br/>*(포털 & 24H 관제 & 유튜브 한글 다운로더)* | [`12_homepage_dashboard_and_disk_architecture.md`](12_homepage_dashboard_and_disk_architecture.md)<br>[`16_metube_youtube_media_downloader_guide.md`](16_metube_youtube_media_downloader_guide.md)<br>[`setup_metube_lxc.sh`](../scripts/setup_metube_lxc.sh)<br>[`patch_metube_korean.sh`](../scripts/patch_metube_korean.sh) |
| **LXC 109** | **Full *Arr Media Automation Stack**<br/>(Jellyseerr + Radarr + Sonarr + Prowlarr + FlareSolverr + qBittorrent) | 2C / 2048MB | Intel 530 SSD + WD Gold Temp 버퍼 + 26TB White | **✅ 완전 구축 완료**<br/>*(미디어 원클릭 요청, 봇 자동 탐색, 보안 우회, 스마트 버퍼링, 2.5G vmbr1 전용선)* | [`17_media_automation_jellyseerr_qbittorrent_guide.md`](17_media_automation_jellyseerr_qbittorrent_guide.md)<br>[`setup_media_automation_lxc.sh`](../scripts/setup_media_automation_lxc.sh) |
| **LXC 102** | **AdGuard Home** | 1C / 512MB | Intel 530 SSD (`local-530`) | **✅ 구축 완료**<br/>*(광고차단 & 로컬 DNS)* | [`13_adguard_home_dns_setup.md`](13_adguard_home_dns_setup.md)<br>[`setup_adguard_lxc.sh`](../scripts/setup_adguard_lxc.sh) |
| **Host** | **Cockpit Web GUI** | PVE Host | Debian 12 Native (`:9090`) | **✅ 설치 완료**<br/>*(디스크 S.M.A.R.T/온도)* | [`14_cockpit_disk_monitoring_guide.md`](14_cockpit_disk_monitoring_guide.md)<br>[`setup_cockpit_pve.sh`](../scripts/setup_cockpit_pve.sh) |
| **LXC 106** | **Dev Web Server** | 2C / 2GB | Intel 530 SSD (`local-530`) | **⚪ 대기 (선택)** | Spring Boot / Node 개발용 |
| **Script** | **통합 전원 제어 (`nas_power.sh`)** | - | Proxmox Host `/root/nas_power.sh` | **✅ 스크립트 제작 완료** | [`nas_power.sh`](../scripts/nas_power.sh) |

---

## 🌐 4. 네트워크 & 포트포워딩 구성표

- **공유기 게이트웨이**: `192.168.1.1` (ASUS 공유기, DDNS: `waceh.asuscomm.com`)
- **Proxmox 메인 IP (`vmbr0`)**: `192.168.1.200` (`https://192.168.1.200:8006`, Cockpit: `:9090`)
- **헤놀로지 메인 IP (`vmbr0`)**: `192.168.1.132` (`http://192.168.1.132:5000`)
- **토렌트 스택 전용선 (`vmbr1`)**: `192.168.1.109` (qBit `:8080`, Jellyseerr `:5055`)
- **맥북 1:1 직결망 (`vmbr2`)**:
  - Proxmox 웹 콘솔: `https://10.10.10.1:8006`
  - 맥북: `10.10.10.2`
  - 헤놀로지 직결 SMB: `smb://10.10.10.101`

| 서비스 | 내부 IP 및 포트 | 외부 포트 / 접속 방식 | 클라이언트 앱 및 연동 |
| :--- | :--- | :--- | :---: |
| **Homepage 대시보드** | `http://192.168.1.107:3000` | **`3000` (TCP)** | 올인원 시작페이지 포털 & 실시간 리소스 관제 |
| **Immich Photo** | `http://192.168.1.103:2283` | **`2283` (TCP)** | Immich 공식 모바일 앱 (iOS/Android 사진 백업) |
| **Gonic Music** | `http://192.168.1.104:4747` | **`4747` (TCP)** | Amperfy (iOS), Ultrasonic (Android), CarPlay |
| **Jellyfin Video** | `http://192.168.1.105:8096` | **`8096` (TCP)** | Swiftfin, Infuse, Jellyfin 스마트TV 앱 |
| **MeTube Downloader** | `http://192.168.1.107:8081` | **`8081` (TCP)** | YouTube/웹 영상 4K & 고음질 음원 추출 다운로더 |
| **Jellyseerr Request** | `http://192.168.1.109:5055` | **`5055` (TCP)** | 넷플릭스 스타일 미디어 원클릭 탐색 및 요청 포털 |
| **Radarr (영화 봇)** | `http://192.168.1.109:7878` | **로컬 / VPN** | 영화 자동 탐색, 자막 매칭 및 `/pds1/Video/Movie` 분류 |
| **Sonarr (드라마 봇)** | `http://192.168.1.109:8989` | **로컬 / VPN** | 드라마/애니/예능 방영 추적 및 `/pds1/Video/drama` 분류 |
| **Prowlarr (인덱서 허브)**| `http://192.168.1.109:9696` | **로컬 / VPN** | 토렌트 인덱서 통합 관리 및 Radarr/Sonarr 자동 연동 |
| **FlareSolverr** | `http://192.168.1.109:8191` | **내부 전용** | Cloudflare 보안 및 통신사 SNI 차단 자동 우회 |
| **qBittorrent** | `http://192.168.1.109:8080` | **`8080` (TCP)** | 스마트 버퍼링 다운로더 (WD Gold 4TB 1차 조각 쓰기) |
| **Uptime Kuma** | `http://192.168.1.107:3001` | **`3001` (TCP) / 로컬** | 24시간 실시간 장애/복구 텔레그램 봇 알림 |
| **AdGuard Home** | `http://192.168.1.102` | **포트 53 (DNS) / 80** | 집안 전체 광고 차단 & 로컬 DNS (`nas.home`) |
| **Cockpit GUI** | `https://192.168.1.200:9090` | **`9090` (HTTPS) / 로컬** | 5대 물리 디스크 실시간 온도 & S.M.A.R.T 건강도 |

---

## 🔄 5. Graceful 순차 전원 관리 명령어 요약 (`nas_power.sh`)

NAS를 쓸 때 켜고 다 쓰면 끄는 On-Demand 패턴을 위한 필수 명령어입니다.

```bash
# 1. Proxmox 자동 부팅/종료 순서(order 1 -> order 2) 일괄 등록 (최초 1회)
bash /root/nas_power.sh init-order

# 2. 현재 상태 확인
bash /root/nas_power.sh status

# 3. 작업 시작 시 수동 순차 기동 (헤놀로지 101 먼저 -> Immich/Gonic/Jellyfin/Arr스택)
bash /root/nas_power.sh up

# 4. 작업 완료 후 안전 순차 종료 (DB 플러시 -> 헤놀로지 Btrfs 플러시)
bash /root/nas_power.sh down

# 5. 작업 완료 후 Proxmox 호스트 본체 전원까지 완전 끄기 (추천 ⭐)
bash /root/nas_power.sh shutdown-host
```

---

## 🚀 6. 진행 완료 및 차기 작업 (Progress & Action Items)

### ✅ 완료된 작업 (Done)
- [x] **Step 1. Jellyfin Media Server (LXC 105) 배포 및 트러블슈팅 완료** (NFSv3 락프리, RAM 캐시, QSV 가속)
- [x] **Step 2. Graceful 순차 전원 제어 스크립트 등록 & 5대 디스크 모니터링** (`nas_power.sh`)
- [x] **Step 3. Proxmox 자동 백업 스토리지 등록 (`vzdump`) & 재해 복구 매뉴얼** (`nas-backups`)
- [x] **Step 4. Homepage 올인원 대시보드 + Uptime Kuma 통합 배포** (Intel 710 SSD 100GB OS 파티션 확장 포함)
- [x] **Step 5. AdGuard Home (LXC 102) 및 Cockpit (PVE Host) 배포 완료** (가이드 13, 14 작성)
- [x] **Step 6. Tailscale Subnet Router 구축 및 OCI 하이브리드 AI 연동 완료** (가이드 15 작성)
- [x] **Step 7. MeTube 웹 다운로더 (LXC 107) 배포 완료** (100% 한국어 패치, WD Gold 4TB `downloads` 직통 매핑, 가이드 16 작성)
- [x] **Step 9. Multi-NIC 3-포트 분리 및 맥북 1:1 직결(Direct Link) 최종 검증 완료**:
  - `vmbr0` (1번 슬롯 `nic0`): 공유기 메인 홈 네트워크 (`192.168.1.200/24`, 게이트웨이 `192.168.1.1`)
  - `vmbr1` (2번 슬롯 `nic1`): 공유기 2차 라인 2.5G 전용 L2 브리지 (헤놀로지/토렌트 트래픽 격리)
  - `vmbr2` (3번 슬롯 `nic2`): 맥북 1:1 직결 전용 브리지 (`10.10.10.1/24`, 핑 ~0.7ms 검증 완료)
  - 4번 슬롯: 미실장 더미 슬롯 확인 완료
  - 자동화 스크립트 배포 완료 (`apply_network.sh`)
- [x] **Step 6. NFSv3 락프리(No-Lock) 고속 마운트 전면 표준화 & Amperfy 트러블슈팅 완료**:
  - `LXC 103 (Immich)` 및 `LXC 104 (Gonic)`의 fstab 마운트 옵션을 `vers=3,nolock,soft,timeo=30,intr,_netdev`로 교체 완료
  - fstab 중복 옵션 정리로 `/mnt/music` 정상 마운트 및 Amperfy 모바일 스트리밍 100% 정상화
  - 헤놀로지 HDD 대기 시간 1시간 최적화 (음악/사진 딜레이 0초 vs 영상 26TB 절전 모터 정지)
- [x] **Step 7. Graceful 순차 기동·종료 순서(`order 1 ➔ order 2`) 전수 검증 완료**:
  - `VM 101 (헤놀로지)`: `order=1,up=30,down=30` (스토리지 코어 최우선 기동 / 최후 종료)
  - `LXC 102~107 (전체 컨테이너)`: `order=2` (DB 플러시 후 선 종료)
  - 호스트 재기동/종료 시 데이터 무결성 100% 보장 확인 완료

---

### ⏳ 진행 중 & 귀가 후 실제로 할 일 (Next Action Items)

#### 1️⃣ [AdGuard Home] 초기 셋업 마법사 및 공유기 연동 (완료 ✅)
- [x] 브라우저에서 `http://192.168.1.102:3000` 접속 ➔ 관리자 계정 생성 및 포트 설정.
- [x] ASUS 공유기(`192.168.1.1`) [LAN] ➔ [DHCP 서버] ➔ DNS 1번에 `192.168.1.102` 등록하여 **집안 전체 기기 광고 자동 차단** 활성화.
- [x] AdGuard [필터링 ➔ DNS 변경] 메뉴에서 `nas.home`, `photo.home`, `music.home`, `video.home`, `pve.home`, `dsm.home` 내부 도메인 매핑 완료.


#### 2️⃣ [Uptime Kuma] 텔레그램 봇 실시간 장애/복구 알림 연동 (완료 ✅)
- [x] 브라우저에서 `http://192.168.1.107:3001` 접속 ➔ 관리자 계정 생성 완료.
- [x] 텔레그램 봇 토큰 및 Chat ID 발급하여 Uptime Kuma 텔레그램 알림 등록 및 테스트 완료.
- [x] 6대 핵심 서비스(Immich, Gonic, Jellyfin, AdGuard, PVE, DSM) 모니터 등록 완료 (24H 실시간 감시).


#### 3️⃣ [Homepage 대시보드] 실시간 Service Widget (API) 연동
단순 링크를 넘어 카드 안에 **실시간 숫자와 게이지**가 살아 숨 쉬도록 위젯 연동:
- [x] **AdGuard Home 위젯**: 차단된 광고 개수, 차단율(%), 오늘 DNS 쿼리 수 실시간 표시 완료 (`username`/`password` 연동).
- [x] **Uptime Kuma 위젯**: 서버 생존 가동률(100.0%) 및 모니터링 상태 뱃지 표시 완료 (`status-page` slug: `default` 연동).
- [x] **Cockpit 실시간 온도 위젯**: CPU 코어 실시간 온도(°C) 및 WD Gold HDD 작동 온도(39°C) 연동 완료 (`nas-sensors` 초경량 데몬).
- [x] **미디어 카드(Immich, Gonic, Jellyfin)**: 0ms 실시간 생존 핑 및 심플 클린 레이아웃 유지.

#### 4️⃣ [자동 백업 스케줄러] 매일 새벽 04:00 자동 스냅샷 백업 (완료 ✅)
- [x] 매일 새벽 04:00 전체 6대 게스트(101~107) 무중단 라이브 스냅샷 백업 스케줄 등록 (`setup_backup_schedule_pve.sh`).
- [x] WD Gold 4TB 백업 금고(`nas-backups`)에 최신 3회분 롤링 보관(Keep Last: 3) 정책 적용.

#### 5️⃣ [보안 강화] Tailscale 하이브리드 Subnet Router 구축 (완료 ✅)
- [x] Proxmox 호스트에 Tailscale WireGuard 서브넷 라우터(`192.168.1.0/24`) 구축 완료 (`setup_tailscale_subnet_router.sh`).
- [x] 관리자 핵심 포트(PVE 8006, DSM 5000, Cockpit 9090, SSH 22)를 Tailscale 암호화 터널로 완전 보호.
- [x] 가족 미디어(Immich, Gonic, Jellyfin)는 포트포워딩 유지로 VPN 없이 24시간 원활한 접속 보장.

#### 6️⃣ [미래 장기 목표] 헤놀로지 VM 101 완전 제거 및 Proxmox 네이티브 스토리지 전환
- [ ] 하드디스크 3대를 Proxmox 호스트 네이티브(ZFS / ext4)로 마운트.
- [ ] LXC 컨테이너(103~105)에 초고속 바인드 마운트(`mp0`)로 직통 연결하여 VM 101 삭제 및 RAM 4GB 회수.


---

## 🏛️ 7. 미래 아키텍처 전환 로드맵 (헤놀로지 탈출 플랜)

1. **현재 1단계 (안전 과도기 - 운영 중)**:
   - 기존 Synology Btrfs 데이터(6.8TB) 포맷 없이 즉시 활용을 위해 헤놀로지(VM 101)를 '스토리지 코어'로 유지.
   - 모든 미디어 서비스(LXC 103~107)가 NFS로 마운트하여 실사용.
2. **최종 2단계 (순수 리눅스 네이티브 Proxmox 스토리지)**:
   - 데이터 검증/정리 완료 후 HDD 3대를 Proxmox 호스트의 네이티브 풀로 전환.
   - 헤놀로지 VM 101 완전 영구 삭제 (`qm destroy 101`) ➔ RAM 4GB 및 VM 오버헤드 100% 회수.
   - NFS 네트워크 계층 대신 Proxmox 호스트 ➔ LXC 간 커널 레벨 초고속 바인드 마운트(`mp0`)로 전환.

---

## 📚 핵심 문서 링크 맵

### 🏗️ 1. 초기 인프라 및 스토리지 구축 (01~08)
- [01. Proxmox VE 8.x 설치 및 초기 환경 설정](01_proxmox_install.md)
- [02. 네트워크 구성 및 이중 NAT/브리지 모드 설정](02_network_setup.md)
- [03. 물리 디스크 Raw Passthrough 설정 매뉴얼](03_disk_passthrough.md)
- [04. Xpenology (헤놀로지) VM 101 설치 가이드](04_xpenology_install.md)
- [05. WD Gold 4TB 5대 공유폴더 및 NFS 스토리지 구성](05_wd_gold_storage_setup.md)
- [06. Immich & Jellyfin 4-Tier 스토리지 아키텍처 설계](06_immich_jellyfin_architecture.md)
- [07. 멀티미디어 서비스 스택 마스터 가이드](07_media_services_master_guide.md)
- [08. 4-Tier 스토리지 티어링 및 미디어 분리 아키텍처](08_storage_tiering_and_media_separation.md)

### 🚀 2. 실전 서비스 운영 및 고도화 가이드 (09~17)
- [00. 작업 진행 현황 및 인수인계 마스터 노트](00_progress_and_handover_notes.md) (현재 문서)
- [09. Immich & Gonic 실전 운영 마스터 가이드](09_immich_caddy_https_and_storage_setup.md)
- [10. NAS Graceful 순차 전원 & Jellyfin 구축 가이드](10_graceful_power_management_and_jellyfin_guide.md)
- [11. Proxmox 백업 스토리지(물리 디스크 매핑) 및 재해 복구 가이드](11_proxmox_backup_and_disaster_recovery_guide.md)
- [12. Homepage 대시보드 구축 및 5대 물리 디스크 관제 가이드](12_homepage_dashboard_and_disk_architecture.md)
- [13. AdGuard Home 네트워크 광고 차단 및 내부 DNS 구축 가이드](13_adguard_home_dns_setup.md)
- [14. Cockpit 웹 시스템 및 5대 디스크 S.M.A.R.T 건강도 관제 가이드](14_cockpit_disk_monitoring_guide.md)
- [15. Tailscale WireGuard 하이브리드 보안망 및 원격 접속 가이드](15_tailscale_hybrid_security_and_remote_access_guide.md)
- [16. MeTube 고화질 영상/음원 원클릭 웹 다운로더 구축 가이드](16_metube_youtube_media_downloader_guide.md)
- [17. Jellyseerr & qBittorrent 스마트 미디어 수집 스택 가이드](17_media_automation_jellyseerr_qbittorrent_guide.md)

### 🔮 3. 아키텍처 검토 및 확장 로드맵 (97~99)
- [97. OCI 하이브리드 AI 서비스 및 Ollama 아키텍처 가이드](97_oci_hybrid_ai_service_and_ollama_architecture.md)
- [98. 향후 확장 서비스 후보군 및 Spring AI 검토](98_candidate_services_and_architecture_review.md)
- [99. (번외편) KMP 모바일 음악 앱 아키텍처](99_kmp_gonic_mobile_app_architecture.md)


