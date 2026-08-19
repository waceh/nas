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
