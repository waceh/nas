# 🛠️ self-nas 자동화 구축 스크립트 모음

Proxmox VE 호스트 셸에서 **원클릭 복사-붙여넣기(`curl | bash`)**로 즉시 실행할 수 있는 실전 자동화 스크립트들입니다.

---

## 📸 1. Immich Photo Server LXC 자동 구축 (ID: 103)

Intel 530 SSD(`local-530`) 위에 Debian 12 컨테이너를 생성하고, 4TB Gold의 `/volume1/photo`를 NFS로 마운트하여 Immich 전체 스택을 1분 만에 배포합니다.

```bash
curl -fsSL https://raw.githubusercontent.com/waceh/nas/main/self-nas/scripts/setup_immich_lxc.sh | bash
```

- **컨테이너 ID**: `103` (Debian 12 Privileged, 2 Core, 4GB RAM, 16GB SSD)
- **NFS 스토리지**: `192.168.1.132:/volume1/photo` ➔ `/mnt/photo`
- **웹/API 포트**: `http://your-domain.asuscomm.com:2283`
- **상세 가이드**: [`docs/09_immich_caddy_https_and_storage_setup.md`](../docs/09_immich_caddy_https_and_storage_setup.md)

---

## 🎵 2. Gonic Music Server LXC 자동 구축 (ID: 104)

RAM을 단 30MB만 소비하는 Go 기반 초경량 **폴더(디렉토리) 기반 고음질 음악 스트리밍 서버**를 배포하고 4TB Gold의 `music` 폴더를 연동합니다.

```bash
curl -fsSL https://raw.githubusercontent.com/waceh/nas/main/self-nas/scripts/setup_gonic_lxc.sh | bash
```

- **컨테이너 ID**: `104` (Debian 12, 1 Core, 512MB RAM, 8GB SSD)
- **NFS 스토리지**: `192.168.1.132:/volume1/music` ➔ `/mnt/music`
- **웹/API 포트**: `http://your-domain.asuscomm.com:4747`
- **지원**: Amperfy(iOS 오픈소스 강추), Ultrasonic/DSub(Android FOSS), Substreamer, Feishin, Apple CarPlay / Android Auto (모두 100% 완전 무료)

---

## 🎬 3. Jellyfin Media Server LXC 자동 구축 (ID: 105)

Intel i5-9500T의 UHD 630 iGPU 하드웨어 가속(`/dev/dri`)을 패스스루하고, 4TB `video` 및 26TB 콜드 스토리지(`PDS1`, `PDS2`)를 연동합니다.

```bash
curl -fsSL https://raw.githubusercontent.com/waceh/nas/main/self-nas/scripts/setup_jellyfin_lxc.sh | bash
```

- **컨테이너 ID**: `105` (Debian 12, 2 Core, 2GB RAM, 12GB SSD)
- **iGPU 가속**: Intel QuickSync Video (QSV) 4K HW 트랜스코딩

---

## 📦 4. 헤놀로지 (Xpenology) VM 자동 생성 (ID: 101)

최신 RR 부트로더 기반 가상 USB 부팅 및 물리 HDD Raw 패스스루를 구성합니다.

```bash
curl -fsSL https://raw.githubusercontent.com/waceh/nas/main/self-nas/scripts/install_xpenology.sh | bash
```

---

## ⚡ 5. NAS 통합 Graceful 순차 전원 제어 (`nas_power.sh`)

NAS를 상시 켜두지 않고 작업할 때만 켜고 끌 때, **스토리지(NFS/Btrfs)와 미디어 서비스 컨테이너 간의 데이터 손상 없는 완벽한 순차 기동/종료**를 원클릭으로 수행합니다.

```bash
# 1. 스크립트 다운로드 및 실행 권한 부여
curl -fsSL https://raw.githubusercontent.com/waceh/nas/main/self-nas/scripts/nas_power.sh -o /root/nas_power.sh
chmod +x /root/nas_power.sh

# 2. 전체 상태 모니터링
bash /root/nas_power.sh status

# 3. 안전 순차 기동 (헤놀로지 101 먼저 ➔ Immich/Gonic/Jellyfin 순차 기동)
bash /root/nas_power.sh up

# 4. 안전 순차 종료 (Jellyfin/Gonic/Immich DB 플러시 ➔ 헤놀로지 101 종료)
bash /root/nas_power.sh down

# 5. 전체 안전 순차 종료 후 Proxmox 호스트 전원 끄기
bash /root/nas_power.sh shutdown-host

# 6. Proxmox 부팅/종료 순서(order/up/down) 일괄 등록
bash /root/nas_power.sh init-order
```

---

## 📊 6. Homepage 올인원 대시보드 자동 구축 (ID: 107)

가족과 사용자가 한 화면에서 홈 서버의 모든 서비스와 5대 물리 스토리지 상태를 확인할 수 있는 올인원 포털 대시보드를 배포합니다.

```bash
# 신규 배포
curl -fsSL https://raw.githubusercontent.com/waceh/nas/main/self-nas/scripts/setup_homepage_lxc.sh | bash

# 기존 대시보드 최신 레이아웃 및 스토리지 정보 갱신
curl -fsSL https://raw.githubusercontent.com/waceh/nas/main/self-nas/scripts/update_homepage_config.sh | bash
```

- **컨테이너 ID**: `107` (Debian 12, 1 Core, 512MB RAM, 4GB SSD on `local-530`)
- **접속 포트**: `http://192.168.1.107:3000` (외부: `http://your-domain.asuscomm.com:3000`)
- **상세 가이드**: [`docs/12_homepage_dashboard_and_disk_architecture.md`](../docs/12_homepage_dashboard_and_disk_architecture.md)

---

## 💾 7. Proxmox VE 710 SSD OS 파티션 100GB 확장 (`merge_pve_root_storage.sh`)

Intel 710 SSD의 미사용 LVM 풀(`pve-data` 70GB)을 안전하게 정리하고, OS 루트 파티션(`pve-root`)을 100GB 전체(94.5GB 여유)로 온라인 무중단 확장합니다.

```bash
curl -fsSL https://raw.githubusercontent.com/waceh/nas/main/self-nas/scripts/merge_pve_root_storage.sh | bash
```

---

## 🛡️ 8. AdGuard Home LXC 자동 구축 (ID: 102)

Intel 530 SSD(`local-530`) 위에 Debian 12 초경량 Native 바이너리로 AdGuard Home을 1분 만에 구축합니다.

```bash
curl -fsSL https://raw.githubusercontent.com/waceh/nas/main/self-nas/scripts/setup_adguard_lxc.sh | bash
```

- **컨테이너 ID**: `102` (Debian 12, 1 Core, 512MB RAM, 4GB SSD on `local-530`)
- **초기 설정 포트**: `http://192.168.1.102:3000`
- **DNS 서버 IP**: `192.168.1.102` (포트 53)
- **상세 가이드**: [`docs/13_adguard_home_dns_setup.md`](../docs/13_adguard_home_dns_setup.md)

---

## 🖥️ 9. Cockpit 웹 시스템 & 디스크 건강도 관리자 설치 (`setup_cockpit_pve.sh`)

Proxmox VE 호스트(Debian 12)에 경량 Cockpit 웹 콘솔을 설치하여 5대 물리 디스크의 실시간 온도, S.M.A.R.T 건강도, 불량 섹터를 확인합니다.

```bash
curl -fsSL https://raw.githubusercontent.com/waceh/nas/main/self-nas/scripts/setup_cockpit_pve.sh | bash
```

- **웹 콘솔 주소**: `https://192.168.1.200:9090` (Proxmox root 계정 로그인)
- **상세 가이드**: [`docs/14_cockpit_disk_monitoring_guide.md`](../docs/14_cockpit_disk_monitoring_guide.md)



