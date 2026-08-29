# 🍿 미디어 완전 자동화 풀스택 가이드: Jellyseerr · Radarr · Sonarr · Prowlarr · FlareSolverr · qBittorrent (17)

> 💡 **Jellyseerr**를 프론트엔드로 삼고, **Radarr(영화)**, **Sonarr(드라마/애니)**, **Prowlarr(토렌트 허브)**, **FlareSolverr(차단 우회)**, **qBittorrent(다운로더)**를 유기적으로 결합하여 **"넷플릭스 스타일 UI에서 요청 버튼 하나만 누르면 최고화질 영상과 자막이 내 26TB 하드로 전자동 수집·분류되는 완전 무인 미디어 자동화 파이프라인"**을 구축합니다.
> 
> 특히 **'스마트 버퍼링(Smart Buffering)' 전략**을 적용하여, 토렌트의 자잘한 조각 파일 쓰기 부하는 **24시간 가동되는 WD Gold 4TB 엔터프라이즈 하드**에서 100% 흡수하고, **26TB WD White 대용량 콜드 하드는 모터를 끄고 깊은 절전(Spin-down) 수면을 유지**하다가 완성된 파일만 예쁘게 전달받습니다.

---

## 🎯 1. 완전 자동화 풀스택 아키텍처 다이어그램

```mermaid
flowchart TB
    User["👤 사용자 (스마트폰 / PC)"] -->|"1. 넷플릭스 스타일 탐색 & '요청' 원클릭"| Jellyseerr["🍿 Jellyseerr (LXC 109:5055)<br/>• Jellyfin(LXC 105) 연동<br/>• 방영/개봉 알림 및 요청 관리"]

    subgraph BotLayer["🤖 *Arr 스마트 지배인 계층 (LXC 109)"]
        Jellyseerr -->|"2. 영화 요청 전달"| Radarr["🎬 Radarr (LXC 109:7878)<br/>• 4K/FHD 화질 판별 & 한글 자막 매칭"]
        Jellyseerr -->|"2. 드라마/애니 요청 전달"| Sonarr["📺 Sonarr (LXC 109:8989)<br/>• 시즌/에피소드 방영 추적 & 자동 채번"]

        Radarr & Sonarr <-->|"3. 토렌트 인덱서 실시간 조회"| Prowlarr["🔍 Prowlarr (LXC 109:9696)<br/>• 1337x, YTS, EZTV 등 통합 검색"]
        Prowlarr <-->|"4. Cloudflare 보안 자동 우회"| Flare["🛡️ FlareSolverr (LXC 109:8191)<br/>• 봇 차단 방어막 무력화"]
    end

    Radarr & Sonarr -->|"5. 다운로드 지시 (API)"| Qbit["⚡ qBittorrent-nox (LXC 109:8080)<br/>• 스마트 백그라운드 다운로더"]

    subgraph StorageTier["💾 4-Tier 스토리지 스마트 분기"]
        Qbit -->|"6. [1차 조각 쓰기 버퍼]"| Gold["💾 WD Gold 4TB (/mnt/temp)<br/>• 24시간 가동 HDD가 I/O 부하 100% 흡수!"]
        
        Gold -->|"7. 다운로드 완료 후 자동 이동 & 정리"| White["💾 WD White 18TB / 8TB (/mnt/pds1, pds2)<br/>• 평소 완전 절전(Spin-down) 수면 유지<br/>• /pds1/Video/Movie & drama & animation"]
    end

    White -->|"8. 최종 미디어 스트리밍"| Jellyfin["🎬 Jellyfin (LXC 105:8096)<br/>• iGPU QSV 4K 하드웨어 가속"]
```

---

## 🌟 2. 6대 서비스 포트 및 역할 정의

| 서비스 명칭 | 내부 접속 포트 | 외부 접속 포트 (ASUS DDNS) | 소모 RAM | 핵심 역할 |
| :--- | :--- | :--- | :---: | :--- |
| 🍿 **Jellyseerr** | `http://192.168.1.109:5055` | `http://waceh.asuscomm.com:5055` | ~100 MB | 넷플릭스 스타일 미디어 탐색 및 원클릭 요청 UI |
| 🤖 **Radarr** | `http://192.168.1.109:7878` | - | ~90 MB | 영화 전담 자동 탐색, 화질 매칭 및 `/pds1/Video/Movie` 자동 분류 |
| 📺 **Sonarr** | `http://192.168.1.109:8989` | - | ~90 MB | 드라마/예능/애니 전담 에피소드 추적 및 `/pds1/Video/drama` 자동 분류 |
| 🔍 **Prowlarr** | `http://192.168.1.109:9696` | - | ~80 MB | 1337x, YTS, EZTV 등 전 세계 토렌트 인덱서 통합 관리 및 Radarr/Sonarr 자동 공급 |
| 🛡️ **FlareSolverr** | `http://192.168.1.109:8191` | - | ~90 MB | 국내 통신사 SNI 차단 및 Cloudflare 봇 방어벽 자동 우회 프록시 |
| ⚡ **qBittorrent** | `http://192.168.1.109:8080` | `http://waceh.asuscomm.com:8080` | ~80 MB | 스마트 버퍼링 다운로더 (WD Gold 4TB 임시 조각 쓰기) |

---

## 🚀 3. 원클릭 자동 배포 명령어

Proxmox VE 호스트 쉘(Web Shell 또는 SSH)에서 아래 명령어를 실행하여 LXC 109에 6대 풀스택을 한 번에 배포합니다:

```bash
curl -fsSL https://raw.githubusercontent.com/waceh/nas/main/self-nas/scripts/setup_media_automation_lxc.sh | bash
```

---

## 🛠️ 4. 실전 상호 연동 가이드

### 1) qBittorrent 보안 차단 해제 및 스핀다운 보호
* **API CSRF 보호 해제**: Radarr/Sonarr의 API 통신을 위해 `WebUI\CSRFProtection=false` 설정 완료.
* **스핀다운 보호 (하드 수명 극대화)**:
  * [http://192.168.1.109:8080](http://192.168.1.109:8080) ➔ **`도구` ➔ `옵션` ➔ `BitTorrent`**:
  * `공유 비율이 다음에 도달할 때:` 체크 ➔ **`0.00`** 입력 ➔ `작업:` **`토렌트 일시 중지`** 선택.

### 2) Radarr (영화 봇) 설정
1. [http://192.168.1.109:7878](http://192.168.1.109:7878) 접속 ➔ `Settings` ➔ `Media Management` ➔ `Root Folders`:
   * **루트 폴더**: **`/movies/Video/Movie`** (18TB White 하드) 추가.
2. `Settings` ➔ `Download Clients` ➔ `+` ➔ `qBittorrent`:
   * **Host**: `qbittorrent` (또는 `192.168.1.109`), **Port**: `8080`, **User/Pass**: `admin`/비밀번호 ➔ `Test & Save`.

### 3) Sonarr (드라마/애니 봇) 설정
1. [http://192.168.1.109:8989](http://192.168.1.109:8989) 접속 ➔ `Settings` ➔ `Media Management` ➔ `Root Folders`:
   * **드라마 루트 폴더**: **`/pds1/Video/drama`**
   * **예능 루트 폴더**: **`/pds1/Video/entertainment`**
   * **애니 루트 폴더**: **`/pds1/Video/animation`** 추가.
2. `Settings` ➔ `Download Clients` ➔ `+` ➔ `qBittorrent` 추가 ➔ `Test & Save`.

### 4) Prowlarr (토렌트 허브 & FlareSolverr & 통신사 SNI 우회 연동)
1. **통신사 SNI 차단 무력화 (인증서 검증 해제)**:
   * `Settings` ➔ `General` ➔ 상단 `Show Advanced: Shown` ➔ `Security` 항목:
   * **`Certificate Validation`**: **`Disabled`** (또는 `Permissive`) 선택 후 `Save`.
2. **FlareSolverr 프록시 등록 & 태그 지정**:
   * `Settings` ➔ `Indexers` ➔ `Proxies +` ➔ `FlareSolverr` 선택:
   * **Host**: `http://flaresolverr:8191` (또는 `http://192.168.1.109:8191`)
   * **Tags**: **`flaresolverr`** 입력 후 `Test & Save`.
3. **토렌트 인덱서 추가 (Indexers ➔ + Add Indexer)**:
   * **`1337x`**: Tags에 **`flaresolverr`** 입력 후 `Save` (Cloudflare 우회)
   * **`EZTV`**: Tags에 **`flaresolverr`** 입력 후 `Save` (Cloudflare 우회)
   * **`TorrentGalaxy`**: Tags에 **`flaresolverr`** 입력 후 `Save` (Cloudflare 우회)
   * **`YTS`**, **`ThePirateBay`**, **`SolidTorrents`**, **`LimeTorrents`**: Tags 없이 즉시 `Save`.
4. **Radarr & Sonarr 앱 자동 동기화 (`Settings` ➔ `Apps` ➔ `+`)**:
   * **Radarr 연동**: Host `http://radarr:7878`, API Key 입력 ➔ `Test & Save`.
   * **Sonarr 연동**: Host `http://sonarr:8989`, API Key 입력 ➔ `Test & Save`.

### 5) Jellyseerr (요청 UI) 설정 및 500 에러 방지
1. [http://192.168.1.109:5055](http://192.168.1.109:5055) 접속 ➔ `Settings (설정)` ➔ `General (일반)`:
   * 표시 언어: **`한국어`**, 탐색 지역: **`대한민국`**, 탐색 언어: **`한국어 (ko)`**.
2. `Settings (설정)` ➔ `Services (서비스)`:
   * **Radarr 추가**:
     - Host: `127.0.0.1` (또는 `192.168.1.109`), Port: `7878`, API Key 입력 (Radarr `:7878` ➔ Settings ➔ General ➔ Security에서 복사)
     - `Default Server`: `[x]` 체크, `Test` 클릭 후
     - **Default Quality Profile**: `HD-1080p` (또는 `Any`) 선택
     - **Default Root Folder**: **`/pds1/Video/Movie`** (또는 `/movies/Video/Movie`) 선택 ➔ `Save Changes`
   * **Sonarr 추가**:
     - Host: `127.0.0.1`, Port: `8989`, API Key 입력
     - `Default Server`: `[x]` 체크, `Test` 클릭 후
     - **Default Quality Profile**: `HD-1080p` (또는 `Any`)
     - **Default Root Folder**: **`/pds1/Video/drama`** 선택 ➔ `Save Changes`

---

## 📁 5. 스토리지 저장 경로 최종 맵핑표

| 서비스 | 컨테이너 내부 경로 | 실제 NAS 스토리지 매핑 | 용도 |
| :--- | :--- | :--- | :--- |
| **qBittorrent** | `/downloads/temp` | **WD Gold 4TB (`/volume1/temp`)** | 1차 토렌트 조각 파일 쓰기 버퍼 |
| **Radarr** | `/movies/Video/Movie` | **WD White 18TB (`/volume2/PDS1/Video/Movie`)** | 최종 완성 영화 영구 보관 |
| **Sonarr** | `/pds1/Video/drama` | **WD White 18TB (`/volume2/PDS1/Video/drama`)** | 최종 드라마 시리즈 영구 보관 |
| **Sonarr** | `/pds1/Video/entertainment` | **WD White 18TB (`/volume2/PDS1/Video/entertainment`)** | 최종 TV 예능 프로그램 보관 |
| **Sonarr** | `/pds1/Video/animation` | **WD White 18TB (`/volume2/PDS1/Video/animation`)** | 최종 애니메이션 시리즈 보관 |

---

## 🔍 6. 컨테이너 상태 점검 및 유지보수

```bash
# LXC 109 컨테이너 상태 및 6대 도커 프로세스 확인
pct status 109
pct exec 109 -- docker compose -f /opt/media-stack/docker-compose.yml ps

# NFS 마운트 상태 확인
pct exec 109 -- df -h | grep -E "temp|video|pds"

# 서비스 전체 재기동
pct exec 109 -- bash -c "cd /opt/media-stack && docker compose restart"
```

---

## 💡 7. 실전 미디어 수집 & 운영 꿀팁

### 1) 가족 친화형 미디어 운영 모델 (권한 분리)
* **👑 관리자 (나)**:
  - **Jellyseerr (`:5055`)**: 침대나 소파에서 스마트폰으로 트렌딩/평점을 보며 1-Click [요청]으로 2.5G 전용선 다운로드 지시.
  - **콘텐츠 품질 통제**: 최고화질(4K/1080p HDR) + 한글 자막 릴리즈 위주로 26TB 저장소를 깔끔하게 큐레이션.
* **📱 가족 / 일반 사용자**:
  - 복잡한 다운로드/서버를 알 필요 없이 **Swiftfin (iOS/Apple TV)**, **Jellyfin (스마트TV/Android)** 전용 앱만 열어 넷플릭스 보듯이 즉시 감상.

### 2) 다운로드 100% 완료 후 qBittorrent 목록 자동 정리
* **원리**: Radarr/Sonarr가 다운로드된 영화를 `/pds1/Video/Movie`로 안전하게 이동시킨 직후, qBittorrent 목록에서 토렌트 작업만 쏙 삭제. (영화 파일은 100% 영구 보존).
* **설정 방법**:
  1. **qBittorrent (`:8080`)**: [도구] ➔ [옵션] ➔ [BitTorrent] ➔ `시딩 제한: 비율 0.00` ➔ `토렌트 일시 정지` (또는 `토렌트 삭제`) 설정.
  2. **Radarr (`:7878`) / Sonarr (`:8989`)**: [Settings] ➔ [Download Clients] ➔ `qBittorrent` 카드 클릭 ➔ 하단 `Remove Completed` (또는 `Remove Imported Downloads`) **`[x]` 체크**!

### 3) 다운로드 속도와 시더(Seeders) 관계
* 토렌트는 중앙 서버가 아닌 P2P 전송이므로, **배포자(Seeders) 수와 그들의 업로드 대역폭**에 따라 속도가 결정됩니다.
* 시더가 많은 최신 인기작은 2.5G 전용선(`vmbr1`) 대역폭을 100% 활용하여 초당 50MB~200MB/s로 1~2분 만에 완료됩니다.
* 시더가 적은 고전/희귀작은 qBittorrent가 백그라운드에서 조각을 모으며 천천히 다운로드합니다.

### 4) TMDb 캐싱 메커니즘과 성능 최적화
* **1회차 조회**: 미국 TMDb 서버에서 메타데이터를 수신하여 LXC 109 메모리/SQLite DB 및 브라우저 디스크에 캐싱.
* **2회차 조회부터**: 로컬 캐시에서 `0.001초` 만에 즉시 렌더링.
* **LXC 109 자원**: 4 vCPU / 4GB RAM 할당으로 6개 봇 동시 구동 시 렉 제로 보장.

