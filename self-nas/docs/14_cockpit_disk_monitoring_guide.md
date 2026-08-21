# 🖥️ Cockpit 웹 시스템 & 5대 물리 디스크 S.M.A.R.T 건강도 관제 가이드 (14)

> 💡 **본 문서는 Proxmox VE 호스트(Debian 12)에 경량 Cockpit 웹 콘솔을 구축하여, 5대 물리 디스크(Intel 710, Intel 530, WD Gold 4TB, WD White 18TB, WD White 8TB)의 실시간 온도, S.M.A.R.T 건강도, 불량 섹터 여부 및 시스템 로그를 웹 GUI로 관제하는 가이드입니다.**

---

## 📌 1. Cockpit 개요 및 운영 목적

* **웹 콘솔 주소**: `https://192.168.1.200:9090` (또는 `https://waceh.asuscomm.com:9090`)
* **로그인 계정**: Proxmox `root` 계정 및 비밀번호
* **소모 리소스**: **RAM 단 10MB 미만** (웹 접속 시에만 소켓이 반응하여 Proxmox 부하 제로)
* **핵심 기능**:
  1. **5대 물리 디스크 건강도(S.M.A.R.T) 실시간 진단**: 각 하드/SSD의 총 사용 시간(Power-On Hours), 불량 섹터(Reallocated Sectors), 온도 확인.
  2. **하드웨어 센서 모니터링**: CPU 코어별 온도 및 팬 속도 확인.
  3. **시스템 로그 및 성능 그래프**: 실시간 CPU/RAM/네트워크 I/O 부하 확인.

---

## 🚀 2. 원클릭 자동 설치 명령어

Proxmox VE 호스트 셸에서 아래 1줄 명령어를 실행합니다:

```bash
curl -fsSL https://raw.githubusercontent.com/waceh/nas/main/self-nas/scripts/setup_cockpit_pve.sh | bash
```

---

## 💾 3. 5대 물리 디스크 건강도 확인 방법

1. 브라우저에서 [`https://192.168.1.200:9090`](https://192.168.1.200:9090) 접속 (자체 서명 SSL 경고 시 '고급 ➔ 계속 진행' 클릭).
2. Proxmox `root` 아이디와 비밀번호로 로그인.
3. 좌측 메뉴 **[스토리지 (Storage)]** 클릭.
4. **드라이브 (Drives)** 목록에서 5대 물리 디스크를 클릭하여 상세 상태 확인:
   - **`Intel 710 SSD 100GB`**: Host OS (`/dev/sda` or nvme) - 수명 잔여율 및 eMLC TBW
   - **`Intel 530 SSD 120GB`**: LXC Fast Pool (`/dev/sdb`) - 건강도 및 쓰기 총량
   - **`WD Gold 4TB Enterprise`**: 홈/라이프 허브 - 실시간 작동 온도(약 35~40°C) 및 S.M.A.R.T PASSED
   - **`WD White 18TB Ultrastar`**: PDS1 콜드 미디어 - 스핀다운 유휴 상태 및 불량 섹터 0
   - **`WD White 8TB CMR`**: PDS2 콜드 미디어 - 드라이브 무결성 확인
