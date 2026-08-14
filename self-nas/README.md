# 🚀 My Home Server Infrastructure (MTK Studio)

개인 영상 편집(Final Cut Pro), 음악 작업(Suno AI) 및 미디어 스트리밍을 위한 고성능 10Gbps 홈 서버 구축 기록입니다.

> 📘 **[Proxmox 설치 이후 전체 과정 한눈에 보기 (통합 가이드)](POST_PROXMOX_SETUP_GUIDE.md)**

## 🖥️ 1. Hardware Specifications
| 부품              | 모델명                                  | 비고                         |
|:----------------|:-------------------------------------|:---------------------------|
| **CPU**         | Intel Core i5-9500T (6 Cores)        | 저전력 고효율 (T모델)              |
| **CPU Cooler**  | TDP <= 200W, 120mm, PWM              | XUANFENG 가성비 CPU 쿨러        |
| **Motherboard** | Server(NAS) Board Vpro C246          | 서버급 안정성, 확장성(SATAX8, LANX4) |
| **Case**        | Fractal Design Node 304 (Black)      | 미니 ITX, 쿨링 최적화 구조          |
| **Power**       | Cooler Master MWE 550 V3 80plus GOLD | HDB 저소음 팬 (자동 팬 조절)        |
| **Network**     | 10Gbps Server NIC (PCIe)             | 맥북 직결 초고속 네트워크(추후 필요시)     |

## 💾 2. Storage Architecture
디스크의 성격과 속도에 따라 역할을 완벽히 분리한 3-Tier 스토리지 구성입니다.

- **`OS` Intel 710 SSD (MLC 100GB):** Proxmox 베이스 시스템 및 가벼운 도커 앱
- **`HOT` WD Gold 4TB (7200RPM):** 고성능 VM(Windows 11) 및 10Gbps 실시간 영상/음악 작업용 스크래치 디스크
- **`COLD` WD Red 8TB + White 12TB:** 헤놀로지(NAS) 패스스루, 아카이빙 및 미디어 보관소

## 🏗️ 3. Virtualization (Proxmox VE)
| 가상 머신 (VM) | 할당 자원 | 스토리지 (위치) | 주요 역할 |
| :--- | :--- | :--- | :--- |
| **VM 1: 헤놀로지** | 2 Core / 4GB | WD Red & White (Passthrough) | 메인 NAS 환경 복구, Docker 컨테이너 호스트 |
| **VM 2: Windows 11** | 4 Core / 8GB | WD Gold 4TB (가상 디스크) | RDP 원격 제어용, 관공서/금융 업무 및 고속 작업 공간 |
| **LXC: Plex** | - | WD Red & White (Mount/Passthrough) | 별도 LXC 컨테이너로 구동하는 Plex 미디어 서버 |

## 🐳 4. Services (Docker on Xpenology)
헤놀로지 내부의 Container Manager를 통해 구동되는 핵심 서비스 목록입니다. (Plex는 별도 LXC로 분리 구동)

* **Media & Entertainment**
  * `*arr Stack (Radarr, Sonarr)`: 미디어 자동화 및 관리
* **Cloud & Backup**
  * `Nextcloud`: 프로젝트 파일 외부 공유 및 10Gbps 동기화
  * `Immich`: AI 기반 무제한 사진 백업 클라우드
* **Network & Security**
  * `AdGuard Home`: 네트워크 단 광고 차단
  * `Vaultwarden`: 프라이빗 비밀번호 관리 지갑

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
- [ ] 2. 하드디스크(Red, White) SATA 케이블 메인보드에서 분리해 두기 (데이터 보호)
- [ ] 3. Intel 710 SSD에 Proxmox VE 설치 → [`01_proxmox_install.md`](docs/01_proxmox_install.md)
- [ ] 4. Proxmox 네트워크 설정 (관리용 vmbr0 / 10Gbps 맥북 직결 vmbr1) → [`02_network_setup.md`](docs/02_network_setup.md)
- [ ] 5. WD Gold 4TB에 Windows 11 VM 구성 및 RDP 원격 테스트
- [ ] 6. 시스템 종료 후 Red, White SATA 케이블 메인보드에 결착
- [ ] 7. Proxmox 부팅 후 터미널에서 디스크 패스스루(Passthrough) 설정 → [`03_disk_passthrough.md`](docs/03_disk_passthrough.md)
- [ ] 8. 헤놀로지 VM 설치 및 기존 데이터 인식 확인 → [`04_xpenology_install.md`](docs/04_xpenology_install.md)
- [ ] 9. Plex LXC 컨테이너 생성 및 미디어 디스크 마운트 → [`lxc/plex/README.md`](lxc/plex/README.md)
- [ ] 10. 도커 서비스 순차적 배포 (*arr -> Nextcloud 등)
