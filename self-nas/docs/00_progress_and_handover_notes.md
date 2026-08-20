# 📋 MTK Studio Self-NAS 작업 진행 현황 및 인수인계 노트 (00)

> 💡 **본 문서는 다른 세션이나 새로운 대화 컨텍스트로 돌아왔을 때 현재 구축 진행 상황을 즉시 파악하고, 중단된 시점부터 이어서 작업하기 위한 '마스터 인수인계(Handover & Progress)' 문서입니다.**

---

## 📌 1. 핵심 아키텍처 및 운영 철학 요약

1. **Pure Storage Core + Native LXC 격리**:
   - **헤놀로지(VM 101)**: 무거운 도커를 일체 돌리지 않고 **순수 Samba/NFS 파일 공유 전용**으로 초안정성 유지.
   - **상시 미디어 서비스(LXC 103~105)**: Proxmox 호스트 레벨의 **초경량 Native LXC 컨테이너**로 분리하여 **Intel 530 SSD 고속 풀(`local-530`)** 위에서 구동.
2. **On-Demand (간헐적 사용) 하이브리드 전원 운영**:
   - 24/7 상시 켜두지 않고, 작업할 때 켜고(WOL) 작업 완료 후 Proxmox 호스트까지 한 번에 안전하게 끄는(`nas_power.sh shutdown-host`) 운영 패턴.
3. **RAM 디스크(`tmpfs` / `/dev/shm`) 100% 활용**:
   - 사진 썸네일 생성, 트랜스코딩 캐시를 RAM 디스크에서 처리하여 **SSD 수명(TBW) 완벽 보호**.
4. **실용적 순수 HTTP 직통 연결**:
   - 자체 서명 HTTPS 인증서로 인한 모바일 OS 차단 문제를 배제하고, 공유기 포트포워딩 기반 **순수 HTTP 직통 연결** 채택 (LTE/5G 통신사 무선 암호화 구간 활용으로 실생활 안전성 확보).

---

## 🖥️ 2. 하드웨어 & 4-Tier 스토리지 구성 현황

- **CPU**: Intel Core i5-9500T (6C/6T, Intel UHD Graphics 630 iGPU QuickSync 지원)
- **RAM**: DDR4 16GB (8GB x 2 듀얼 채널)
- **메인보드/케이스**: Vpro C246 (SATA 8포트, LAN 4포트) / Fractal Node 304 / 550W Gold 파워
- **스토리지 티어링**:
  - **`Host OS 전용` Intel 710 SSD (100GB MLC, Non-Disk)**: Proxmox VE 8.x 베이스 OS 및 RRD 통계 전용
  - **`고속 컨테이너` Intel 530 SSD (120GB MLC, Non-Disk)**: Proxmox LVM-Thin `local-530` (LXC 루트, PostgreSQL/Vector DB, Gonic DB)
  - **`홈 & 라이프 허브` WD Gold 4TB (7200RPM Enterprise)**: 헤놀로지 Raw Passthrough ➔ 5대 공유폴더 (`photo`, `video`, `music`, `temp`, `backups`)
  - **`엔터테인먼트 Cold` WD White 8TB + 18TB (총 26TB CMR)**: 소비성 미디어(`PDS1`, `PDS2`), 평소 모터 정지(스핀다운)

---

## ⚡ 3. VM 및 LXC 서비스 구축 진행 상태

| ID / 대상 | 서비스 명칭 | vCPU / RAM | 구동 스토리지 / 볼륨 | 현재 상태 | 상세 가이드 및 스크립트 |
| :---: | :--- | :---: | :--- | :---: | :--- |
| **VM 101** | **Xpenology (Storage Core)** | 2C / 4GB | HDD 3대 Raw Passthrough (Gold 4T, White 26T) | **✅ 구축 완료** | [`04_xpenology_install.md`](04_xpenology_install.md) |
| **LXC 103** | **Immich Photo Server** | 2C / 4GB | Intel 530 SSD + WD Gold (`/volume1/photo` NFS) | **✅ 구축 완료**<br/>*(10GB+ 색인 완료)* | [`09_immich_caddy_https_and_storage_setup.md`](09_immich_caddy_https_and_storage_setup.md)<br>[`setup_immich_lxc.sh`](../scripts/setup_immich_lxc.sh) |
| **LXC 104** | **Gonic Music Server** | 1C / 512MB | Intel 530 SSD + WD Gold (`/volume1/music` NFS) | **✅ 구축 완료**<br/>*(폴더 기반 스트리밍)* | [`09_immich_caddy_https_and_storage_setup.md`](09_immich_caddy_https_and_storage_setup.md)<br>[`setup_gonic_lxc.sh`](../scripts/setup_gonic_lxc.sh) |
| **LXC 105** | **Jellyfin Media Server** | 2C / 2GB | Intel 530 SSD + iGPU QuickSync + WD Gold/White | **✅ 구축 완료**<br/>*(iGPU QSV + RAM 캐시)* | [`10_graceful_power_management_and_jellyfin_guide.md`](10_graceful_power_management_and_jellyfin_guide.md)<br>[`setup_jellyfin_lxc.sh`](../scripts/setup_jellyfin_lxc.sh) |
| **LXC 102** | **AdGuard Home** | 1C / 512MB | Intel 530 SSD (`local-530`) | **⚪ 대기 (선택)** | [`07_media_services_master_guide.md`](07_media_services_master_guide.md) |
| **LXC 106** | **Dev Web Server** | 2C / 2GB | Intel 530 SSD (`local-530`) | **⚪ 대기 (선택)** | Spring Boot / Node 개발용 |
| **Script** | **통합 전원 제어 (`nas_power.sh`)** | - | Proxmox Host `/root/nas_power.sh` | **✅ 스크립트 제작 완료** | [`nas_power.sh`](../scripts/nas_power.sh) |

---

## 🌐 4. 네트워크 & 포트포워딩 구성표

- **공유기 게이트웨이**: `192.168.1.1` (ASUS 공유기, DDNS: `your-domain.asuscomm.com`)
- **Proxmox 호스트 IP**: `192.168.1.200` (`https://192.168.1.200:8006`)
- **헤놀로지 VM 101 IP**: `192.168.1.132` (`https://192.168.1.132:5001`)

| 서비스 | 내부 IP 및 포트 | 외부 공유기 포트포워딩 | 클라이언트 앱 및 연동 |
| :--- | :--- | :---: | :--- |
| **Immich Photo** | `http://192.168.1.103:2283` | **`2283` (TCP)** | Immich 공식 모바일 앱 (iOS/Android 백업) |
| **Gonic Music** | `http://192.168.1.104:4747` | **`4747` (TCP)** | Amperfy (iOS), Ultrasonic/DSub (Android), CarPlay/Android Auto |
| **Jellyfin Video** | `http://192.168.1.105:8096` | **`8096` (TCP)** | Swiftfin, Infuse, Jellyfin 스마트TV 앱 |

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

## 🚀 6. 다음 세션에서 이어서 바로 진행할 작업 (Next To-Do Checklist)

- [x] **Step 1. Jellyfin Media Server (LXC 105) 실제 배포**:
  - 배포 완료 (`http://192.168.1.105:8096`)
  - Intel QuickSync (QSV) 및 RAM 캐시(`/dev/shm/jellyfin-transcodes`) 연동 완료
  - 미디어 라이브러리 `/mnt/video` (4TB Gold) 마운트 완료
  - 공유기 포트포워딩: 외부 포트 `8096` ➔ 내부 `192.168.1.105:8096` (TCP)
- [ ] **Step 2. Graceful 순차 전원 제어 스크립트 등록 & 테스트**:
  ```bash
  # Proxmox 호스트에 스크립트 등록 및 부팅 순서 일괄 적용
  curl -fsSL https://raw.githubusercontent.com/waceh/nas/main/self-nas/scripts/nas_power.sh -o /root/nas_power.sh
  chmod +x /root/nas_power.sh
  bash /root/nas_power.sh init-order
  ```
  - 테스트: 상태 조회(`bash /root/nas_power.sh status`) ➔ 호스트 종료(`bash /root/nas_power.sh shutdown-host`)
  - 스마트폰 ASUS Router 앱에서 WOL 켜기 ➔ 정상 자동 순차 기동(`order=1 ➔ order=2`) 확인
- [ ] **Step 3. Proxmox 자동 백업 스토리지 등록 (`vzdump`)**:
  ```bash
  # Proxmox 호스트 셸에서 헤놀로지 4TB Gold 백업 폴더를 PVE 스토리지로 원클릭 등록
  pvesm add nfs nas-backups --server 192.168.1.132 --export /volume1/backups --content backup --options "vers=4,nolock"
  ```
  - 등록 후 PVE 웹 콘솔 (`Datacenter` ➔ `Backup`)에서 주간 자동 백업(일요일 새벽) 스케줄 활성화
- [ ] **Step 4. (선택 검토) 확장 서비스 후보군 검토**:
  - `Organizr + Homepage` 통합 탭/대시보드, `Uptime Kuma` 장애 알림, `Tailscale`, `Spring AI` 에이전트 연동 검토 → [`98_candidate_services_and_architecture_review.md`](98_candidate_services_and_architecture_review.md)

---

## 📚 핵심 문서 링크 맵
- [00. 작업 진행 현황 및 인수인계](00_progress_and_handover_notes.md) (현재 문서)
- [09. Immich & Gonic 실전 운영 마스터 가이드](09_immich_caddy_https_and_storage_setup.md)
- [10. NAS Graceful 순차 전원 & Jellyfin 구축 가이드](10_graceful_power_management_and_jellyfin_guide.md)
- [98. 향후 확장 서비스 후보군 및 Spring AI 검토](98_candidate_services_and_architecture_review.md)
- [99. (번외편) KMP 모바일 음악 앱 아키텍처](99_kmp_gonic_mobile_app_architecture.md)
