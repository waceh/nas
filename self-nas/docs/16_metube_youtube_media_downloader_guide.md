# 📹 MeTube 고화질 영상/음원 원클릭 웹 다운로더 구축 가이드 (16)

> 💡 **MeTube**는 최신 `yt-dlp` 엔진을 탑载한 초경량(~40MB RAM) 오픈소스 미디어 다운로더입니다. 웹 브라우저에서 유튜브, 치지직, 인스타그램, 틱톡 등의 영상 URL만 붙여넣으면 **최고화질(4K/1080p) 비디오** 또는 **최고음질(320k MP3/FLAC) 음원**을 내 자작 NAS의 **WD Gold 4TB**에 즉시 저장합니다.

---

## 🎯 1. 핵심 구축 목적 및 스토리지 연동 아키텍처

```mermaid
flowchart LR
    User["👤 사용자 (브라우저/스마트폰)"] -->|"1. 유튜브/웹 영상 URL 입력"| MeTube["📹 MeTube 웹 UI (LXC 107:8081)<br/>• yt-dlp 초고속 엔진<br/>• RAM 소모 ~40MB"]
    
    MeTube -->|"2-A. 비디오 다운로드 (4K/FHD)"| GoldVideo["💾 WD Gold 4TB (/volume1/video)<br/>➔ Jellyfin(LXC 105)에서 즉시 시청!"]
    MeTube -->|"2-B. 오디오 추출 (MP3/FLAC)"| GoldMusic["💾 WD Gold 4TB (/volume1/music)<br/>➔ Gonic(LXC 104)에서 즉시 스트리밍!"]
    MeTube -->|"2-C. 일반 임시 다운로드"| GoldTemp["💾 WD Gold 4TB (/volume1/temp)<br/>➔ 1차 검수 및 임시 보관"]
```

### 🌟 MeTube 도입의 3대 특장점
1. **음원 추출 즉시 Gonic 스트리밍 연동**:
   - Suno AI, 유튜브 라이브 음원, 믹스셋을 MP3로 다운로드하면 즉시 **LXC 104 Gonic 음악 서버에 반영**되어 스마트폰 Amperfy 및 CarPlay에서 바로 감상 가능.
2. **고화질 영상 Jellyfin 미디어 라이브러리 자동 반영**:
   - 유튜브 다큐멘터리, 고화질 영상 클립이 다운로드 즉시 **LXC 105 Jellyfin 홈비디오/유튜브 라이브러리**에 등록.
3. **초경량 리소스 소모**:
   - Docker 컨테이너 기준 평상시 **RAM 40MB 내외**만 소모하여 LXC 107(Homepage/Uptime Kuma)과 함께 완벽하게 공존.

---

## 🚀 2. 원클릭 자동 설치 스크립트 실행

Proxmox VE 호스트의 쉘(Web Shell 또는 SSH)에서 아래 명령어를 복사하여 실행합니다:

```bash
curl -fsSL https://raw.githubusercontent.com/waceh/nas/main/self-nas/scripts/setup_metube_lxc.sh | bash
```

---

## ⚙️ 3. 접속 주소 및 포트 정보

| 서비스 명칭 | 내부 접속 URL | 외부 접속 URL (ASUS DDNS) | 소모 RAM | 기본 저장 경로 |
| :--- | :--- | :--- | :---: | :--- |
| 📹 **MeTube 웹 UI** | `http://192.168.1.107:8081` | `http://waceh.asuscomm.com:8081` | ~40 MB | `/mnt/gold-video`, `/mnt/gold-music`, `/mnt/gold-temp` |

---

## 💻 4. 실전 활용법 및 팁

### 1) 최고화질 비디오 다운로드
1. 브라우저에서 `http://192.168.1.107:8081` 접속.
2. 다운로드할 유튜브/웹 영상 URL을 붙여넣기.
3. **Format** 드롭다운에서 `Any Video (Best Quality)` 선택 후 **Add** 클릭.
4. 자막(`ko`, `en`)이 자동으로 영상 파일 내부에 임베드되어 다운로드됩니다.

### 2) 음원(MP3/FLAC)만 추출하여 Gonic 음악 라이브러리에 저장
1. MeTube 화면 우측 상단 설정(톱니바퀴) 또는 포맷 선택에서 **`Audio (MP3 / Best Quality)`** 선택.
2. 다운로드 대상 폴더를 `/mnt/gold-music/YouTube_Music` 등으로 지정.
3. 다운로드가 완료되면 Gonic이 자동으로 음원을 스캔하여 스마트폰 앱에 즉시 노출됩니다.

### 3) 크롬 / 사파리 북마클릿(Bookmarklet) 원클릭 등록
브라우저 북마크에 아래 자바스크립트를 등록해두면, 유튜브를 보다가 클릭 한 번으로 현재 보고 있는 영상을 NAS로 다운로드 전송할 수 있습니다:

```javascript
javascript:(function(){window.open('http://192.168.1.107:8081/add?url='+encodeURIComponent(location.href));})();
```

---

## 🛠️ 5. 트러블슈팅 및 유지보수

* **MeTube 컨테이너 상태 확인**:
  ```bash
  pct exec 107 -- docker ps -a | grep metube
  ```
* **MeTube 실시간 다운로드 로그 확인**:
  ```bash
  pct exec 107 -- docker logs -f metube
  ```
* **yt-dlp 엔진 최신 버전 업데이트**:
  ```bash
  pct exec 107 -- bash -c "cd /opt/metube && docker compose pull && docker compose up -d"
  ```
