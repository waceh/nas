# 🛠️ self-nas 자동화 구축 스크립트 모음

Proxmox VE 호스트(`192.168.1.200`) 셸 또는 다른 터미널 세션에서 **원클릭 복사-붙여넣기**로 실행할 수 있는 자동화 스크립트들입니다.

---

## 📸 1. Immich Photo Server LXC 자동 구축 (ID: 103)

헤놀로지 4TB의 `/volume2/photo` 폴더를 NFS로 자동 마운트하고, Docker Compose로 Immich 전체 스택을 1분 만에 배포합니다.

### 🚀 원클릭 실행 명령어 (Proxmox 호스트 셸에서 복사-붙여넣기)
```bash
bash /Users/w/IdeaProjects/nas/self-nas/scripts/setup_immich_lxc.sh
```
*(또는 Proxmox 직접 다운로드 실행: `curl -fsSL https://raw.githubusercontent.com/waceh/nas/main/self-nas/scripts/setup_immich_lxc.sh | bash`)*

* **컨테이너 ID**: `103` (Debian 12, 2 Core, 4GB RAM, 16GB SSD)
* **IP 주소**: `192.168.1.103:2283`
* **NFS 스토리지**: `192.168.1.132:/volume2/photo` ➔ `/mnt/photo`

---

## 🎬 2. Jellyfin Media Server LXC 자동 구축 (ID: 105)

Intel Core i5-9500T의 UHD 630 iGPU 하드웨어 가속(`/dev/dri`)을 패스스루하고, 헤놀로지 4TB의 `/volume2/video`를 NFS로 마운트하여 Jellyfin을 공식 설치합니다.

### 🚀 원클릭 실행 명령어 (Proxmox 호스트 셸에서 복사-붙여넣기)
```bash
bash /Users/w/IdeaProjects/nas/self-nas/scripts/setup_jellyfin_lxc.sh
```
*(또는 Proxmox 직접 다운로드 실행: `curl -fsSL https://raw.githubusercontent.com/waceh/nas/main/self-nas/scripts/setup_jellyfin_lxc.sh | bash`)*

* **컨테이너 ID**: `105` (Debian 12, 2 Core, 2GB RAM, 12GB SSD)
* **IP 주소**: `192.168.1.105:8096`
* **iGPU 가속**: Intel UHD Graphics 630 QuickSync (QSV)
* **NFS 스토리지**: `192.168.1.132:/volume2/video` ➔ `/mnt/video`

---

## 📦 3. 헤놀로지 (Xpenology) VM 자동 생성 (ID: 101)

최신 RR (Redpill Recovery) 부트로더를 다운로드하고 가상 USB 부팅 및 SATA 패스스루를 구성합니다.

```bash
bash /Users/w/IdeaProjects/nas/self-nas/scripts/install_xpenology.sh
```
*(TUI 대화형 마법사: `bash /Users/w/IdeaProjects/nas/self-nas/scripts/pve_xpenol_install.sh`)*

---

## ⚙️ 실행 전 필수 체크: 헤놀로지 NFS 공유 폴더 준비 (최초 1회)

스크립트를 돌리기 전, **헤놀로지 DSM(`https://waceh.asuscomm.com:5001`)**에서 아래 2개 폴더가 생성되어 있어야 합니다:
1. `photo` 폴더 생성 (볼륨 2 4TB) ➔ NFS 권한: `192.168.1.0/24` (읽기/쓰기, 비동기 ON)
2. `video` 폴더 생성 (볼륨 2 4TB) ➔ NFS 권한: `192.168.1.0/24` (읽기/쓰기, 비동기 ON)
