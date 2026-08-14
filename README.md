# 🗄️ NAS 프로젝트 모음

NAS 인프라 구축 및 클라우드 아키텍처 설계를 다루는 저장소입니다.

## 📂 프로젝트 구성

- [`self-nas/`](self-nas) — 자작 홈서버(MTK Studio) 구축 기록. 10Gbps 네트워크, Proxmox 가상화, Xpenology(헤놀로지) 기반 미디어/백업 서비스 구성.
- [`cloud-nas/`](cloud-nas) — Oracle Cloud Infrastructure 인스턴스 기반 NAS 아키텍처 설계 문서. Docker Compose, Spring Boot/Kotlin 백엔드, Vue 프론트엔드, 모니터링, CI/CD 포함.

---

## 🏗️ Self-NAS 아키텍처 및 구성도

자작 홈서버(`self-nas`)의 하드웨어 스펙 및 Proxmox VE 가상화(VM / LXC / Docker) 구성도입니다.

```mermaid
flowchart TB
    %% Styles
    classDef hw fill:#24292e,stroke:#444d56,stroke-width:2px,color:#fff;
    classDef pve fill:#1a365d,stroke:#2b6cb0,stroke-width:2px,color:#fff;
    classDef vm fill:#1c4532,stroke:#276749,stroke-width:2px,color:#fff;
    classDef lxc fill:#744210,stroke:#d69e2e,stroke-width:2px,color:#fff;
    classDef docker fill:#2c5282,stroke:#3182ce,stroke-width:1px,color:#fff;
    classDef disk fill:#2d3748,stroke:#4a5568,stroke-width:1px,color:#fff;

    %% 1. 상단 박스: Physical Hardware
    subgraph HW["🖥️ Physical Hardware (Fractal Node 304 / Vpro C246)"]
        CPU["Intel Core i5-9500T (6C/6T)<br/>Intel UHD Graphics 630 (iGPU)"]:::hw
        RAM["DDR4 RAM 8GB X 2"]:::hw
        NIC["Onboard 1GbE LAN x4<br/>(10Gbps PCIe NIC 확장 예정)"]:::hw
        
        subgraph Disks["💾 Physical Storage"]
            SSD_710["Intel 710 SSD 100GB (MLC)<br/>Proxmox Host OS 전용"]:::disk
            SSD_530["Intel 530 SSD 120GB (Non-Disk)<br/>상시 서비스 & VM/LXC 스토리지"]:::disk
            WD_Gold["WD Gold 4TB (7200RPM)<br/>Immich 사진/동영상 & 설정/백업"]:::disk
            WD_Red["WD Red 8TB (CMR)<br/>Cold Storage Pool"]:::disk
            WD_White["WD White 18TB<br/>Cold Media & Archive"]:::disk
        end
    end

    %% 2. 하단 박스: Proxmox VE
    subgraph PVE["⚡ Proxmox VE 8.x (Hypervisor)"]
        VMBR0["vmbr0 (1GbE LAN - 192.168.50.x)"]:::pve
        
        %% VM 102: Windows 11
        subgraph VM102["💻 VM 102: Windows 11 Pro"]
            WIN_SPEC["4 vCPU / 8GB RAM<br/>Intel 530 SSD 가상 디스크<br/>RDP 원격 접속 / 금융·작업"]:::vm
        end

        %% VM 101: Xpenology
        subgraph VM101["📦 VM 101: 헤놀로지 Xpenology (DSM 7.2.1 / DS920+)"]
            NAS_SPEC["2 vCPU / 4GB RAM<br/>Boot: Virtual rr.img (sata0)<br/>OS: 32GB vDisk (sata1)"]:::vm
            
            subgraph Docker["🐳 Docker Services (Container Manager)"]
                D2["Immich (AI 사진 백업 - 4TB Gold 저장 / 530 SSD DB)"]:::docker
                D4["AdGuard Home (DNS 24/7 무소음 캐시 - 530 SSD)"]:::docker
                D1["Nextcloud (외부 파일 공유/동기화)"]:::docker
                D3["*arr Stack (Radarr / Sonarr)"]:::docker
                D5["Vaultwarden (패스워드 관리)"]:::docker
                
                D2 ~~~ D4
                D4 ~~~ D1
                D1 ~~~ D3
                D3 ~~~ D5
            end
        end

        %% LXC 105: Plex
        subgraph LXC105["🎬 LXC 105: Plex Media Server (Debian 12 CT)"]
            PLEX_SPEC["2 Cores / 2GB RAM<br/>Intel 530 SSD 루트/캐시<br/>Plex Media Server"]:::lxc
        end
    end

    %% 상하 세로 배치 제약
    CPU ~~~ SSD_710
    RAM ~~~ SSD_530
    NIC ~~~ WD_Gold

    %% Storage & Passthrough Links
    SSD_710 -->|"Host OS & Boot"| VMBR0
    SSD_530 -->|"VM Virtual Disk"| WIN_SPEC
    SSD_530 -->|"LXC Root Disk"| PLEX_SPEC
    SSD_530 -.->|"DB / App Cache"| D2
    SSD_530 -.->|"24/7 DNS Cache"| D4
    WD_Gold -.->|"Photo & Video Storage"| D2
    WD_Gold -.->|"Config & System Backup"| VM101
    WD_Red -->|"Cold Passthrough (qm set)"| NAS_SPEC
    WD_White -->|"Cold Passthrough (qm set)"| NAS_SPEC
    
    %% Hardware Acceleration
    CPU -.->|"iGPU Passthrough (/dev/dri/renderD128)"| PLEX_SPEC
    
    %% Network & Shared Storage
    VMBR0 --- VM102
    VMBR0 --- VM101
    VMBR0 --- LXC105
    NAS_SPEC -.->|"NFS Mount (/volume1/media)"| PLEX_SPEC
```

### 📋 주요 구성 요약

| 레이어 | 구성 요소 | 상세 내용 |
| :--- | :--- | :--- |
| **물리 하드웨어** | CPU / RAM / Storage | Intel i5-9500T (6C/6T, UHD 630 iGPU), DDR4 16GB, Intel 710 SSD(100GB), Intel 530 SSD(120GB), WD Gold 4TB, WD Red 8TB, WD White 18TB |
| **하이퍼바이저** | Proxmox VE 8.x | 베이스 OS (Intel 710 SSD 전용 구동), 가상 네트워크 브리지(`vmbr0`), 스토리지 & iGPU 패스스루 라우팅 |
| **가상 머신 (VM)** | VM 101: 헤놀로지 (DSM 7.2.1) | 2 Core / 4GB RAM, HDD Cold 패스스루(Red 8TB, White 18TB), Docker 서비스(Immich, AdGuard, Nextcloud, *arr, Vaultwarden) |
| | VM 102: Windows 11 Pro | 4 Core / 8GB RAM, Intel 530 SSD 기반 고속 가상 디스크, RDP 원격 제어 및 작업 공간 |
| **LXC 컨테이너** | LXC 105: Plex Media Server | 2 Core / 2GB RAM (Debian 12), Intel 530 SSD 기반 루트/캐시, iGPU HW 트랜스코딩 가속, 헤놀로지 미디어 NFS 마운트 연동 |

### 💾 물리적 디스크 용도 및 역할 분담 (4-Tier Storage)

| 티어 (Tier) | 디스크 모델 | 연결 방식 / 마운트 위치 | 주요 용도 및 역할 |
| :--- | :--- | :--- | :--- |
| **`HOST OS 전용`** | **Intel 710 SSD 100GB** (MLC) | Proxmox 호스트 직접 설치 | - **Proxmox VE Host OS 전용** 구동 (안정성 최우선)<br>- Host OS 외 별도 서비스 설치 없음 |
| **`상시 고속 서비스 (Non-Disk)`** | **Intel 530 SSD 120GB** | Proxmox 로컬 고속 스토리지 / VM | - **상시/빈번 호출 서비스 무소음 구동** (HDD 스핀다운 유지)<br>- **Windows 11 (VM 102)** 고속 가상 디스크<br>- **Plex Media Server (LXC 105)** 루트 컨테이너 및 트랜스코딩 캐시/메타데이터<br>- **Immich** 고속 앱 실행 및 PostgreSQL/벡터 메타데이터 DB I/O 가속<br>- **AdGuard Home** 24/7 DNS 쿼리 로그 및 필터 캐시 |
| **`사진 저장 & 백업`** | **WD Gold 4TB** (7200RPM Enterprise) | Proxmox 스토리지 / 볼륨 할당 | - **Immich 사진/동영상 저장소** (대용량 원본 미디어 보관)<br>- **시스템 설정 파일 및 핵심 데이터 백업 보관소**<br>- 기타 추가 용도 확장 가능 (검토 중) |
| **`COLD (스토리지)`** | **WD Red 8TB** (CMR NAS 드라이브) | VM 101 (헤놀로지) Raw 패스스루 (`by-id`) | - **Cold Disk**: 헤놀로지 메인 스토리지 풀 및 개인 데이터 보관<br>- Nextcloud, Vaultwarden, *arr 등 일반 Docker 앱 영구 데이터 저장 |
| **`COLD (미디어)`** | **WD White 18TB** (대용량 드라이브) | VM 101 (헤놀로지) Raw 패스스루 (`by-id`) | - **Cold Disk**: 대용량 영상/음악 미디어 라이브러리 및 콜드 아카이빙<br>- Plex LXC에서 NFS 네트워크 마운트(`/volume1/media`)로 필요 시에만 호출 |

---

상세 구축 과정 및 세부 설정 가이드는 [`self-nas/README.md`](self-nas/README.md) 및 [`self-nas/POST_PROXMOX_SETUP_GUIDE.md`](self-nas/POST_PROXMOX_SETUP_GUIDE.md)를 참고하세요.
