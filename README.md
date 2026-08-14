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
            SSD["Intel 710 SSD 100GB (MLC)<br/>Proxmox OS / Boot"]:::disk
            WD_Gold["WD Gold 4TB (7200RPM)<br/>VM High-Performance Storage"]:::disk
            WD_Red["WD Red 8TB (CMR)<br/>Storage Pool"]:::disk
            WD_White["WD White 18TB<br/>Media & Archive"]:::disk
        end
    end

    %% 2. 하단 박스: Proxmox VE
    subgraph PVE["⚡ Proxmox VE 8.x (Hypervisor)"]
        VMBR0["vmbr0 (1GbE LAN - 192.168.50.x)"]:::pve
        
        %% VM 102: Windows 11
        subgraph VM102["💻 VM 102: Windows 11 Pro"]
            WIN_SPEC["4 vCPU / 8GB RAM<br/>RDP 원격 접속 / 금융·관공서 / 스크래치 작업"]:::vm
        end

        %% VM 101: Xpenology
        subgraph VM101["📦 VM 101: 헤놀로지 Xpenology (DSM 7.2.1 / DS920+)"]
            NAS_SPEC["2 vCPU / 4GB RAM<br/>Boot: Virtual rr.img (sata0)<br/>OS: 32GB vDisk (sata1)"]:::vm
            
            subgraph Docker["🐳 Docker Services (Container Manager)"]
                D1["Nextcloud (외부 파일 공유/동기화)"]:::docker
                D2["Immich (AI 사진 백업)"]:::docker
                D3["*arr Stack (Radarr / Sonarr)"]:::docker
                D4["AdGuard Home (DNS 광고 차단)"]:::docker
                D5["Vaultwarden (패스워드 관리)"]:::docker
            end
        end

        %% LXC 105: Plex
        subgraph LXC105["🎬 LXC 105: Plex Media Server (Debian 12 CT)"]
            PLEX_SPEC["2 Cores / 2GB RAM<br/>Plex Media Server"]:::lxc
        end
    end

    %% 상하 세로 배치 제약
    CPU ~~~ SSD
    RAM ~~~ WD_Gold
    NIC ~~~ WD_Red

    %% Storage & Passthrough Links
    SSD -->|"Host OS & Boot"| VMBR0
    WD_Gold -->|"Virtual Disk"| WIN_SPEC
    WD_Red -->|"Disk Passthrough (qm set by-id)"| NAS_SPEC
    WD_White -->|"Disk Passthrough (qm set by-id)"| NAS_SPEC
    
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
| **물리 하드웨어** | CPU / RAM / Storage | Intel i5-9500T (6C/6T, UHD 630 iGPU), DDR4, Intel 710 SSD(100GB), WD Gold 4TB, WD Red 8TB, WD White 18TB |
| **하이퍼바이저** | Proxmox VE 8.x | 베이스 OS (SSD 구동), 가상 네트워크 브리지(`vmbr0`), 스토리지 & iGPU 패스스루 라우팅 |
| **가상 머신 (VM)** | VM 101: 헤놀로지 (DSM 7.2.1) | 2 Core / 4GB RAM, HDD 패스스루, 파일 공유(SMB/NFS), Docker 서비스(Nextcloud, Immich, *arr, AdGuard, Vaultwarden) |
| | VM 102: Windows 11 Pro | 4 Core / 8GB RAM, WD Gold 4TB 기반 고속 가상 디스크, RDP 원격 제어 및 작업 공간 |
| **LXC 컨테이너** | LXC 105: Plex Media Server | 2 Core / 2GB RAM (Debian 12), iGPU HW 트랜스코딩 가속, 헤놀로지 미디어 NFS 마운트 연동 |

### 💾 물리적 디스크 용도 및 역할 분담 (3-Tier Storage)

| 티어 (Tier) | 디스크 모델 | 연결 방식 / 마운트 위치 | 주요 용도 및 역할 |
| :--- | :--- | :--- | :--- |
| **`OS / Boot`** | **Intel 710 SSD 100GB** (MLC) | Proxmox 호스트 직접 설치 | - Proxmox VE 베이스 OS 및 가상 부팅 디스크(`rr.img` 등)<br>- VM/LXC 기본 시스템 템플릿 구동 |
| **`HOT (고속 작업)`** | **WD Gold 4TB** (7200RPM Enterprise) | VM 102 (Windows 11) 가상 디스크 할당 | - Windows 11 VM 전용 고속 스토리지<br>- RDP 원격 접속 기반 실시간 작업 공간 (영상/음악/문서 작업)<br>- 금융·관공서 업무 처리 |
| **`COLD (스토리지)`** | **WD Red 8TB** (CMR NAS 드라이브) | VM 101 (헤놀로지) Raw 패스스루 (`by-id`) | - 메인 NAS 스토리지 풀 및 개인 데이터 보관<br>- Nextcloud, Immich, Vaultwarden 등 Docker 앱 영구 데이터 저장 |
| **`COLD (미디어)`** | **WD White 18TB** (대용량 드라이브) | VM 101 (헤놀로지) Raw 패스스루 (`by-id`) | - 대용량 영상/음악 미디어 라이브러리 및 콜드 아카이빙<br>- Plex LXC에서 NFS 네트워크 마운트(`/volume1/media`)로 실시간 스트리밍 |

---

상세 구축 과정 및 세부 설정 가이드는 [`self-nas/README.md`](self-nas/README.md) 및 [`self-nas/POST_PROXMOX_SETUP_GUIDE.md`](self-nas/POST_PROXMOX_SETUP_GUIDE.md)를 참고하세요.
