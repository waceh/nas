# 📊 Homepage 대시보드 구축 및 5대 물리 디스크 티어링 관제 가이드 (12)

> 💡 **본 문서는 Proxmox VE 상에서 Native LXC 107로 구동되는 올인원 홈 NAS 포털 대시보드(Homepage)의 아키텍처, 4단 레이아웃 설계, Proxmox 호스트 하드웨어 패스스루 기법, 그리고 710 SSD 100GB 확장 과정을 완벽하게 정리한 마스터 가이드입니다.**

---

## 📌 1. Homepage 대시보드 개요 및 운영 목적

* **접속 주소**: `http://192.168.1.107:3000` (외부: `http://waceh.asuscomm.com:3000`)
* **구동 환경**: Proxmox Native LXC (Debian 12, 1 Core, 512MB RAM, Intel 530 SSD `local-530`)
* **핵심 목적**:
  1. 가족 및 사용자가 복잡한 포트 번호(`2283`, `4747`, `8096`, `8006`, `5000`)를 외울 필요 없이 **한 화면에서 모든 홈 서버 서비스로 원클릭 접속**
  2. 서버 전체 하드웨어(i5-9500T 6코어 / DDR4 16GB RAM)와 **5대 물리 디스크의 실제 여유 용량 및 역할**을 한눈에 실시간 모니터링
  3. 초경량 리소스(RAM 50MB 미만 점유)로 상시 쾌적한 반응 속도 보장

---

## 🖥️ 2. 대시보드 4단 컴팩트 레이아웃 구성

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ [헤더] 🖥️ Waceh NAS & Media Hub  |  CPU 12%  |  RAM 4.8GB (31%)  |  Google 검색바        │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ [1층] 💾 4-Tier 물리 스토리지 (가로 1줄 5칸)                                            │
│  ├─ Intel 710 100GB (94.5GB 여유) : Host OS (Proxmox VE)                                │
│  ├─ Intel 530 120GB (98.0GB 여유) : VM / LXC / DB 풀                                    │
│  ├─ WD Gold 4TB (3.4TB 여유)     : 사진(Immich), 음악(Gonic), 영상                     │
│  ├─ WD White 18TB (9.2TB 여유)   : PDS1 (Cold Storage / Jellyfin)                      │
│  └─ WD White 8TB (7.0TB 여유)    : PDS2 (Cold Storage / Jellyfin)                      │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ [2층] 🎬 미디어 서비스 (가로 1줄 3칸)                                                   │
│  ├─ Immich Photo   : AI 사진 백업 / 앨범 인식 (포트 2283)                              │
│  ├─ Gonic Music    : 무손실 음악 스트리밍 / Amperfy (포트 4747)                         │
│  └─ Jellyfin Video : 4K QuickSync 하드웨어 가속 비디오 (포트 8096)                       │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ [3층] 🛠️ 인프라 & 스토리지 (가로 1줄 2칸)                                               │
│  ├─ Proxmox VE     : 하이퍼바이저 호스트 (포트 8006)                                    │
│  └─ Xpenology DSM  : Pure Storage Core (포트 5000)                                     │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ [4층] 🌐 Developer & Social (가로 1줄 3칸)                                             │
│  ├─ GitHub         : github.com/waceh                                                  │
│  ├─ Instagram      : @legato____                                                       │
│  └─ YouTube        : @mtk-ey                                                           │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## ⚡ 3. 핵심 기술 구현 내역

### 1) Proxmox 호스트 전체 하드웨어(6C / 16GB) LXC 패스스루
* **문제**: LXC 컨테이너 격리로 인해 기본 상태에서는 LXC에 할당된 512MB RAM만 대시보드 상단에 표시됨.
* **해결**: `/etc/pve/lxc/107.conf`에 호스트의 실제 `/proc` 정보를 읽기 전용으로 바인드 마운트:
  ```ini
  lxc.mount.entry: /proc/meminfo proc/meminfo none bind,ro,create=file 0 0
  lxc.mount.entry: /proc/stat proc/stat none bind,ro,create=file 0 0
  lxc.mount.entry: /proc/cpuinfo proc/cpuinfo none bind,ro,create=file 0 0
  ```
  ➔ 대시보드 상단에 호스트 전체의 **i5-9500T 6코어 실제 CPU 사용률과 16GB 전체 RAM 점유율**이 정확하게 실시간 연동됨.

### 2) Intel 710 SSD OS 파티션 100GB 전체 확장 (`merge_pve_root_storage.sh`)
* **배경**: Proxmox 기본 설치 시 100GB 중 OS 파티션(`pve-root`)으로 30GB만 떼어주고 나머지 70GB를 빈 `local-lvm` 풀로 잡아둠.
* **조치**: VM/LXC를 Intel 530 SSD(`local-530`)로 완전 분리했으므로, 710의 미사용 `pve-data` 풀을 안전하게 제거하고 OS 파티션을 100GB(94.5GB 여유) 전체로 온라인 무중단 확장:
  ```bash
  lvremove -y /dev/pve/data
  pvesm remove local-lvm || true
  lvextend -l +100%FREE /dev/pve/root
  resize2fs /dev/pve/root
  ```

### 3) 실시간 0ms 생존 확인(Health Check) 핑 연동
* `services.yaml`의 각 서비스에 `ping: http://192.168.1.xxx:port`를 주입하여, 서비스 정상 작동 시 **초록색 0MS 뱃지(온라인)**가 표시되고 장애 시 즉시 빨간색 에러로 감지.

### 4) 30초 저부하 하드웨어 센서 & CPU/디스크 실시간 온도 (`setup_hardware_sensors_pve.sh`)
* **설계 철학**: 1초 단위의 과도한 폴링 대신 **30초 주기 저부하(Low-Overhead)**로 호스트 온도를 수집하여 **CPU 부하 0.1% 미만** 유지 및 **콜드 디스크(WD White 18T/8T) 스핀다운 절전 완벽 보호**.
* **구현**: Proxmox 호스트에 `glances` 30초 주기 데몬(`:61208`) 구동 ➔ Homepage 상단 헤더에 **CPU 실시간 온도(°C)**와 리소스 사용량이 실시간 연동됨.

---

## 🛠️ 4. 주요 관리 및 업데이트 스크립트

| 스크립트 파일 | 용도 및 기능 |
| :--- | :--- |
| [`setup_homepage_lxc.sh`](../scripts/setup_homepage_lxc.sh) | LXC 107 생성부터 Docker, Homepage, 4단 레이아웃 자동 일괄 설치 |
| [`update_homepage_config.sh`](../scripts/update_homepage_config.sh) | 대시보드 레이아웃, 스토리지 정보, 소셜 링크, Glances 센서 최신 갱신 |
| [`setup_hardware_sensors_pve.sh`](../scripts/setup_hardware_sensors_pve.sh) | 30초 주기 저부하 CPU/디스크 온도 센서 데몬 설치 (포트 61208) |
| [`merge_pve_root_storage.sh`](../scripts/merge_pve_root_storage.sh) | Intel 710 SSD OS 루트 파티션을 100GB 전체로 무중단 확장 |
| [`enable_homepage_auth.sh`](../scripts/enable_homepage_auth.sh) | 외부 접속 보안을 위한 Nginx HTTP Basic Auth 계정 암호화 적용 |
| [`preview_dashboard.html`](../preview_dashboard.html) | 로컬 Mac 브라우저에서 서버 배포 전 즉시 화면을 확인하는 HTML 프리뷰어 |

