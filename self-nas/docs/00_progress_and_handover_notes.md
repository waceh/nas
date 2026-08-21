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
- **메인보드/케이스**: Vpro C246 (SATA 8포트, LAN 4포트) / Fractal Node 304 / 550W Gold 파워
- **스토리지 티어링**:
  - **`Host OS 전용` Intel 710 SSD (100GB MLC, Non-Disk)**: Proxmox VE 8.x 베이스 OS (LVM 병합으로 94.5GB 여유 확보 완료)
  - **`고속 컨테이너` Intel 530 SSD (120GB MLC, Non-Disk)**: Proxmox LVM-Thin `local-530` (LXC 102~107 루트, DB 풀)
  - **`홈 & 라이프 허브` WD Gold 4TB (7200RPM Enterprise)**: 헤놀로지 Raw Passthrough ➔ 5대 공유폴더 (`photo`, `video`, `music`, `temp`, `backups`)
  - **`엔터테인먼트 Cold` WD White 8TB + 18TB (총 26TB CMR)**: 소비성 미디어(`PDS1`, `PDS2`), 평소 모터 정지(스핀다운)

---

## ⚡ 3. VM 및 LXC 서비스 구축 진행 상태

| ID / 대상 | 서비스 명칭 | vCPU / RAM | 구동 스토리지 / 볼륨 | 현재 상태 | 상세 가이드 및 스크립트 |
| :---: | :--- | :---: | :--- | :---: | :--- |
| **VM 101** | **Xpenology (Storage Core)** | 2C / 4GB | HDD 3대 Raw Passthrough (Gold 4T, White 26T) | **✅ 구축 완료** | [`04_xpenology_install.md`](04_xpenology_install.md) |
| **LXC 103** | **Immich Photo Server** | 2C / 4GB | Intel 530 SSD + WD Gold (`/volume1/photo` NFS) | **✅ 구축 완료**<br/>*(10GB+ 색인 완료)* | [`09_immich_caddy_https_and_storage_setup.md`](09_immich_caddy_https_and_storage_setup.md)<br>[`setup_immich_lxc.sh`](../scripts/setup_immich_lxc.sh) |
| **LXC 104** | **Gonic Music Server** | 1C / 512MB | Intel 530 SSD + WD Gold (`/volume1/music` NFS) | **✅ 구축 완료**<br/>*(폴더 기반 스트리밍)* | [`09_immich_caddy_https_and_storage_setup.md`](09_immich_caddy_https_and_storage_setup.md)<br>[`setup_gonic_lxc.sh`](../scripts/setup_gonic_lxc.sh) |
| **LXC 105** | **Jellyfin Media Server** | 2C / 2GB | Intel 530 SSD + iGPU QuickSync + 4단 NFS (`video`, `music`, `pds1`, `pds2`) | **✅ 구축 완료**<br/>*(iGPU QSV + RAM 캐시 + NFSv3 락프리)* | [`10_graceful_power_management_and_jellyfin_guide.md`](10_graceful_power_management_and_jellyfin_guide.md)<br>[`setup_jellyfin_lxc.sh`](../scripts/setup_jellyfin_lxc.sh) |
| **LXC 107** | **Homepage + Uptime Kuma** | 1C / 512MB | Intel 530 SSD (`local-530`) | **✅ 구축 완료**<br/>*(포털 & 24H 장애 관제)* | [`12_homepage_dashboard_and_disk_architecture.md`](12_homepage_dashboard_and_disk_architecture.md)<br>[`update_homepage_config.sh`](../scripts/update_homepage_config.sh) |
| **LXC 102** | **AdGuard Home** | 1C / 512MB | Intel 530 SSD (`local-530`) | **✅ 구축 완료**<br/>*(광고차단 & 로컬 DNS)* | [`13_adguard_home_dns_setup.md`](13_adguard_home_dns_setup.md)<br>[`setup_adguard_lxc.sh`](../scripts/setup_adguard_lxc.sh) |
| **Host** | **Cockpit Web GUI** | PVE Host | Debian 12 Native (`:9090`) | **✅ 설치 완료**<br/>*(디스크 S.M.A.R.T/온도)* | [`14_cockpit_disk_monitoring_guide.md`](14_cockpit_disk_monitoring_guide.md)<br>[`setup_cockpit_pve.sh`](../scripts/setup_cockpit_pve.sh) |
| **LXC 106** | **Dev Web Server** | 2C / 2GB | Intel 530 SSD (`local-530`) | **⚪ 대기 (선택)** | Spring Boot / Node 개발용 |
| **Script** | **통합 전원 제어 (`nas_power.sh`)** | - | Proxmox Host `/root/nas_power.sh` | **✅ 스크립트 제작 완료** | [`nas_power.sh`](../scripts/nas_power.sh) |

---

## 🌐 4. 네트워크 & 포트포워딩 구성표

- **공유기 게이트웨이**: `192.168.1.1` (ASUS 공유기, DDNS: `waceh.asuscomm.com`)
- **Proxmox 호스트 IP**: `192.168.1.200` (`https://192.168.1.200:8006`, Cockpit: `:9090`)
- **헤놀로지 VM 101 IP**: `192.168.1.132` (`http://192.168.1.132:5000`)

| 서비스 | 내부 IP 및 포트 | 외부 포트 / 접속 방식 | 클라이언트 앱 및 연동 |
| :--- | :--- | :--- | :---: |
| **Homepage 대시보드** | `http://192.168.1.107:3000` | **`3000` (TCP)** | 올인원 시작페이지 포털 & 실시간 리소스 관제 |
| **Immich Photo** | `http://192.168.1.103:2283` | **`2283` (TCP)** | Immich 공식 모바일 앱 (iOS/Android 사진 백업) |
| **Gonic Music** | `http://192.168.1.104:4747` | **`4747` (TCP)** | Amperfy (iOS), Ultrasonic (Android), CarPlay |
| **Jellyfin Video** | `http://192.168.1.105:8096` | **`8096` (TCP)** | Swiftfin, Infuse, Jellyfin 스마트TV 앱 |
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

# 3. 작업 시작 시 수동 순차 기동 (헤놀로지 101 먼저 -> Immich/Gonic/Jellyfin)
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

---

### ⏳ 진행 중 & 귀가 후 실제로 할 일 (Next Action Items)

#### 1️⃣ [AdGuard Home] 초기 셋업 마법사 및 공유기 연동
- [ ] 브라우저에서 `http://192.168.1.102:3000` 접속 ➔ 관리자 계정 생성 (웹 포트 `80`, DNS 포트 `53` 지정).
- [ ] ASUS 공유기(`192.168.1.1`) [LAN] ➔ [DHCP 서버] ➔ DNS 1번에 `192.168.1.102` 등록하여 **집안 전체 기기 광고 자동 차단** 활성화.
- [ ] AdGuard [DNS 재작성] 메뉴에서 `nas.home`(`192.168.1.107`), `photo.home`(`192.168.1.103`) 예쁜 내부 도메인 매핑.

#### 2️⃣ [Uptime Kuma] 텔레그램 봇 실시간 장애/복구 알림 연동
- [ ] 브라우저에서 `http://192.168.1.107:3001` 접속 ➔ 관리자 계정 생성.
- [ ] 텔레그램 `@BotFather`에서 발급받은 **Bot Token**과 `@userinfobot`의 **Chat ID**를 Uptime Kuma 알림에 등록.
- [ ] Immich, Jellyfin, PVE, DSM 모니터 추가 후 [테스트] 발송.

#### 3️⃣ [Homepage 대시보드] 실시간 Service Widget (API) 연동
단순 링크를 넘어 카드 안에 **실시간 숫자와 게이지**가 살아 숨 쉬도록 위젯 연동:
- [ ] **AdGuard Home 위젯**: 차단된 광고 개수, 차단율(%), 오늘 DNS 쿼리 수 실시간 표시 (`username`/`password` 연동).
- [ ] **Uptime Kuma 위젯**: 서버 생존 가동률(100.0%) 및 모니터링 상태 뱃지 표시 (`status-page` slug 연동).
- [ ] **Immich 위젯**: 총 사진 장수, 동영상 개수, 사용 용량 표시 (`API Key` 연동).
- [ ] **Jellyfin 위젯**: 현재 실시간 시청자 수, 영화/드라마 편수 표시 (`API Key` 연동).
- [ ] **Glances 센서 위젯**: CPU 코어별 온도 및 5대 물리 디스크(Gold, White 등) 실시간 온도(°C) 대시보드 표기.

#### 4️⃣ [보안 강화] Tailscale 하이브리드 Subnet Router 구축 (선택)
- [ ] 관리자 핵심 포트(PVE 8006, DSM 5000, SSH 22)는 외부 포트포워딩을 폐쇄하고 **Tailscale WireGuard 2FA 망**으로 완전 은폐.
- [ ] 가족 미디어(Immich, Gonic, Jellyfin)는 포트포워딩 유지로 편리성 100% 보장.

#### 5️⃣ [미래 장기 목표] 헤놀로지 VM 101 완전 제거 및 Proxmox 네이티브 스토리지 전환
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
- [00. 작업 진행 현황 및 인수인계](00_progress_and_handover_notes.md) (현재 문서)
- [09. Immich & Gonic 실전 운영 마스터 가이드](09_immich_caddy_https_and_storage_setup.md)
- [10. NAS Graceful 순차 전원 & Jellyfin 구축 가이드](10_graceful_power_management_and_jellyfin_guide.md)
- [11. Proxmox 백업 스토리지(물리 디스크 매핑) 및 재해 복구 가이드](11_proxmox_backup_and_disaster_recovery_guide.md)
- [12. Homepage 대시보드 구축 및 5대 물리 디스크 관제 가이드](12_homepage_dashboard_and_disk_architecture.md)
- [13. AdGuard Home 네트워크 광고 차단 및 내부 DNS 구축 가이드](13_adguard_home_dns_setup.md)
- [14. Cockpit 웹 시스템 및 5대 디스크 S.M.A.R.T 건강도 관제 가이드](14_cockpit_disk_monitoring_guide.md)
- [98. 향후 확장 서비스 후보군 및 Spring AI 검토](98_candidate_services_and_architecture_review.md)
- [99. (번외편) KMP 모바일 음악 앱 아키텍처](99_kmp_gonic_mobile_app_architecture.md)
