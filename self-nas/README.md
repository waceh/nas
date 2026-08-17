# 🚀 My Home Server Infrastructure (MTK Studio)

개인 영상 편집(Final Cut Pro), 음악 작업(Suno AI) 및 미디어 스트리밍을 위한 고성능 10Gbps 홈 서버 구축 기록입니다.

> 📘 **[Proxmox 설치 이후 전체 과정 한눈에 보기 (통합 가이드)](POST_PROXMOX_SETUP_GUIDE.md)**

## 🖥️ 1. Hardware Specifications
| 부품              | 모델명                                  | 비고                         |
|:----------------|:-------------------------------------|:---------------------------|
| **CPU**         | Intel Core i5-9500T (6 Cores)        | 저전력 고효율 (T모델, UHD 630 iGPU) |
| **RAM**         | DDR4 8GB x 2 (16GB)                  | 듀얼 채널                    |
| **Storage**     | Intel 710 SSD 100GB (MLC, Non-Disk)<br/>Intel 530 SSD 120GB (MLC, Non-Disk)<br/>WD Gold 4TB (7200RPM Enterprise)<br/>WD White 8TB (`WD80EMAZ-00WJTA0`, CMR)<br/>WD White 18TB (`WUH721818ALE604`, Ultrastar) | 4-Tier 스토리지 (OS / 고속앱 / 작업+사진 / NAS+미디어) |
| **CPU Cooler**  | TDP <= 200W, 120mm, PWM              | XUANFENG 가성비 CPU 쿨러        |
| **Motherboard** | Server(NAS) Board Vpro C246          | 서버급 안정성, 확장성(SATAX8, LANX4) |
| **Case**        | Fractal Design Node 304 (Black)      | 미니 ITX, 쿨링 최적화 구조          |
| **Power**       | Cooler Master MWE 550 V3 80plus GOLD | HDB 저소음 팬 (자동 팬 조절)        |
| **Network**     | 10Gbps Server NIC (PCIe)             | 맥북 직결 초고속 네트워크(추후 필요시)     |

## 💾 2. Storage Architecture
디스크의 성격과 속도에 따라 역할을 완벽히 분리한 4-Tier 스토리지 구성입니다.

- **`HOST OS 전용 (Non-Disk)` Intel 710 SSD (MLC 100GB, Non-Disk):** Proxmox VE 베이스 OS 및 부팅 전용 (안정성 최우선, 기타 서비스 미설치, 무소음/무회전)
- **`상시 고속 서비스 (Non-Disk)` Intel 530 SSD (MLC 120GB, Non-Disk):** 24/7 상시 무소음 서비스 (AdGuard Home, Jellyfin LXC 루트/캐시, Immich DB/앱 고속 I/O)
- **`미디어 & 백업 스토리지` WD Gold 4TB (7200RPM Enterprise):** 헤놀로지 Raw 패스스루(`sata4`), Immich 사진 & Jellyfin 미디어 원본 저장, 사용자 수동 GUI 저장, Proxmox VM 전체 백업 금고
- **`COLD 스토리지` WD White 8TB (`WD80EMAZ`) + WD White 18TB (`WUH721818ALE604`):** 헤놀로지 Raw 패스스루(`sata2`, `sata3`), 순수 개인 데이터 보관 및 대용량 콜드 아카이빙 (필요 시에만 호출)

## 🏗️ 3. Virtualization (Proxmox VE)
| 가상 머신 (VM) / 컨테이너 | 할당 자원 | 스토리지 (위치) | 주요 역할 |
| :--- | :--- | :--- | :--- |
| **VM 101: 헤놀로지**<br/>*(Pure Storage Core)* | 2 Core / 4GB | WD Gold 4TB, WD White 8TB, WD White 18TB (Raw Passthrough) | **순수 NAS 스토리지 코어** (Samba / NFS 파일 공유 데몬 전용, 도커 미구동으로 초경량 유지) |
| **LXC 102: AdGuard Home** | 1 Core / 512MB | Intel 530 SSD (MLC, Non-Disk) | 24/7 상시 무소음 DNS 쿼리 캐시 & 네트워크 광고 차단 |
| **LXC 103: Immich Server** | 2 Core / 4GB | Intel 530 SSD (DB/앱) + 헤놀로지 4TB Gold (NFS 원본 저장) | AI 기반 사진 백업 백엔드 + PostgreSQL + Vector Search DB |
| **LXC 105: Jellyfin Server** | 2 Core / 2GB | Intel 530 SSD (루트/캐시) + 헤놀로지 4TB Gold (NFS 미디어 저장) | Intel UHD 630 iGPU QuickSync HW 트랜스코딩 미디어 스트리밍 |
| **LXC 106: Dev Web Server** | 2 Core / 2GB | Intel 530 SSD (MLC, Non-Disk) | Spring Boot / Node.js / Nginx 개인 프로젝트 개발 & 테스트 웹 서버 |
| *(선택 확장) Windows VM* | *2~4 Core / 4GB* | *Intel 530 SSD or WD Gold 4TB* | *추후 필요 시에만 최소 리소스로 On-Demand 생성 예정* |

## ⚡ 4. Services Architecture (Proxmox Native LXC 격리 구동)
헤놀로지 내부에서 무겁게 도커를 돌리지 않고, **Proxmox 하이퍼바이저 레벨의 초경량 Native LXC 컨테이너**로 각 서비스를 완전 분리하여 초고속 SSD(Intel 530) 위에서 구동합니다:

* **DNS & Network Security**: `LXC 102 (AdGuard Home)` — 24/7 무소음 DNS 필터링/캐시
* **AI Photo Cloud**: `LXC 103 (Immich)` — 초고속 PostgreSQL/벡터 DB는 SSD에서 구동, 대용량 원본 사진은 4TB Gold NFS로 저장
* **Media Streaming**: `LXC 105 (Jellyfin)` — iGPU 하드웨어 가속, 4TB Gold NFS 미디어 라이브러리 연동
* **Development Web Server**: `LXC 106 (Dev Web)` — 개인 웹 애플리케이션 개발/배포 환경

## 🌐 5. Network Topology & ISP Bridge Mode (LG U+)
```
Internet(origin)
   │
LG U+ 공유기/모뎀 (임대 장비)
   │
ASUS 공유기 (내 방, 유무선)
   ├── NAS (유선)
   ├── PC (유선)
   └── MacBook M1 Pro 16" (WiFi)
```
LG U+ 공유기와 ASUS 공유기 사이 **이중 NAT** 상태. 포트포워딩/VPN을 한 곳에서만 관리하려면 LG U+ 공유기를 브리지 모드로 전환 권장. 상세 절차 및 대안(이중 NAT 유지 시 양쪽 포워딩)은 [`02_network_setup.md`](docs/02_network_setup.md) 참고.

### LG U+ 공유기 브리지 모드 전환 절차
1. 브라우저에서 공유기 관리 페이지 접속: `http://192.168.219.1` (LG U+ 기본 게이트웨이 IP)
2. 관리자 로그인 — 기본 계정은 보통 `admin` / 공유기 하단 스티커에 적힌 비밀번호 (초기화 안 했으면 그대로 사용)
3. **고급설정 → 네트워크 설정 → 인터넷 설정(또는 WAN 설정)** 메뉴 진입 (임대 장비 모델에 따라 메뉴명 다를 수 있음)
4. "브리지 모드" 또는 "AP 모드" 항목 선택 후 적용 — 일부 구형 모델은 이 옵션이 아예 없을 수 있음
5. **MAC 주소 클론 필수 확인**: LG U+는 회선에 MAC 주소 인증을 거는 경우가 많음 → 공유기 교체/브리지 전환 시 인터넷 끊길 수 있음
   - ASUS 공유기 관리 페이지 → WAN 설정 → MAC 주소 클론(Clone) 기능으로 기존 LG U+ 공유기의 WAN MAC 주소 복사해서 등록
   - 기존 MAC 주소는 브리지 전환 전 LG U+ 공유기 관리 페이지의 상태/정보 메뉴에서 미리 확인해 둘 것
6. PPPoE 방식 회선이면 ASUS 공유기 WAN 설정에서 PPPoE 계정(아이디/비밀번호) 직접 입력 필요 — 모르면 LG U+ 고객센터(101) 문의
7. 브리지 모드 메뉴가 안 보이거나 전환 후에도 인터넷이 안 되면 고객센터에 **"공유기 브리지 모드 전환"** 요청 (기사 방문 없이 원격으로 처리되는 경우 많음)
8. 전환 완료 후 ASUS 공유기가 공인 IP를 직접 받는지 확인:
   ```
   ASUS 공유기 관리 페이지 → 네트워크 지도/상태 → WAN IP가 공인 IP(사설 IP 대역 192.168.x.x, 10.x.x.x, 172.16~31.x.x가 아님)인지 확인
   ```

## ⚙️ 6. Build & Setup Checklist (빌드 순서)
- [ ] 1. 모든 하드웨어 1차 가조립 (Node 304 전면->후면 쿨링 터널 확인)
- [ ] 2. 하드디스크(White 8TB, White 18TB, Gold 4TB) SATA 케이블 메인보드에서 분리해 두기 (OS 설치 시 데이터 보호)
- [ ] 3. Intel 710 SSD에 Proxmox VE 설치 (Host OS 전용) → [`01_proxmox_install.md`](docs/01_proxmox_install.md)
- [ ] 4. Proxmox 네트워크 설정 (관리용 vmbr0 / 10Gbps 맥북 직결 vmbr1) → [`02_network_setup.md`](docs/02_network_setup.md)
- [ ] 5. Intel 530 SSD(상시 고속 LXC 컨테이너 스토리지) Proxmox 스토리지 등록
- [ ] 6. 시스템 종료 후 White 8TB, White 18TB, Gold 4TB SATA 케이블 메인보드에 결착
- [ ] 7. Proxmox 부팅 후 터미널에서 HDD 3대(White 8TB, White 18TB, Gold 4TB) 패스스루 설정 → [`03_disk_passthrough.md`](docs/03_disk_passthrough.md), [`05_wd_gold_storage_setup.md`](docs/05_wd_gold_storage_setup.md)
- [ ] 8. 헤놀로지 VM(101) 부팅 및 순수 NAS 스토리지 풀(Samba/NFS) 구성 → [`04_xpenology_install.md`](docs/04_xpenology_install.md)
- [ ] 9. Intel 530 SSD 위에 Proxmox Native LXC 컨테이너 순차 구축 → [통합 미디어 마스터 가이드](docs/07_media_services_master_guide.md), [Immich/Jellyfin 아키텍처](docs/06_immich_jellyfin_architecture.md):
  - [ ] 9-1. `LXC 102 (AdGuard Home)` DNS 캐시 구축
  - [ ] 9-2. `LXC 103 (Immich Photo Server)` 구축 (4TB Gold 실시간 백업 + 18TB 아카이브)
  - [ ] 9-3. `LXC 105 (Jellyfin Media Server)` 구축 (18TB 영상 라이브러리 연동 & iGPU 가속) → [`lxc/jellyfin/README.md`](lxc/jellyfin/README.md)
  - [ ] 9-4. `LXC (Navidrome Music Server)` 구축 (18TB 음악 라이브러리 연동)
  - [ ] 9-5. `LXC 106 (Dev Web Server)` Spring Boot / Node.js 개발 서버 구축
- [ ] 10. (선택 확장) Windows VM 필요 시 Intel 530 SSD or WD Gold에 On-Demand 생성
