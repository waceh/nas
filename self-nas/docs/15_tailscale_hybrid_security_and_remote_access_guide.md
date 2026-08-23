# 🔐 Tailscale WireGuard 하이브리드 보안망 및 원격 접속 가이드 (15)

> 💡 **본 문서는 Proxmox VE 자작 NAS 환경에서 Tailscale Subnet Router를 구축하여 관리자 포트를 외부 해킹 위협으로부터 100% 은폐하고, 외부 어디서나 집 안 내부 IP(`192.168.1.xxx`)로 안전하게 0초 접속하는 공식 보안/원격 접속 매뉴얼입니다.**

---

## 🏛️ 1. 하이브리드 보안 아키텍처 개요

가족들이 사용하는 미디어 서비스는 앱을 통한 간편 접속을 보장하고, 해킹 위험이 있는 핵심 관리자 콘솔은 외부 인터넷 포트포워딩을 폐쇄하여 **Tailscale WireGuard 2FA 암호화 터널**로만 접근을 허용하는 **엔터프라이즈 2원화 하이브리드 망**입니다.

```mermaid
flowchart TD
    subgraph External["🌐 외부 인터넷 망 (카페, LTE/5G, 회사)"]
        FamilyUser["👨‍👩‍👧 가족 & 지인<br/>(일반 스마트폰)"]
        AdminUser["👑 관리자 본인<br/>(Tailscale 2FA 앱 활성화)"]
    end

    subgraph ASUS_Router["🛡️ ASUS 공유기 (192.168.1.1)"]
        PortForward["🚪 포트포워딩 개방 포트<br/>• Immich (2283)<br/>• Gonic (4747)<br/>• Jellyfin (8096)"]
        BlockedPorts["🔒 폐쇄된 관리자 포트 (외부 차단)<br/>• PVE (8006), DSM (5000)<br/>• Cockpit (9090), SSH (22)"]
    end

    subgraph InternalLAN["🏰 내부 LAN 네트워크 (192.168.1.0/24)"]
        subgraph Proxmox_Host["🖥️ Proxmox VE 호스트 (192.168.1.200)"]
            SubnetRouter["🔑 Tailscale Subnet Router<br/>(192.168.1.0/24 광고)"]
            PVE_GUI["PVE 콘솔 (:8006)"]
            Cockpit_GUI["Cockpit 관제 (:9090)"]
            SSH_Daemon["SSH 데몬 (:22)"]
        end

        subgraph LXC_Stack["📦 LXC 미디어 & 관제 컨테이너"]
            LXC_102["🛡️ LXC 102: AdGuard Home (:80)"]
            LXC_103["📸 LXC 103: Immich Photo (:2283)"]
            LXC_104["🎵 LXC 104: Gonic Music (:4747)"]
            LXC_105["🎬 LXC 105: Jellyfin Video (:8096)"]
            LXC_107["📊 LXC 107: Homepage & Uptime Kuma"]
        end

        subgraph Synology_Core["💾 VM 101: Xpenology DSM (192.168.1.132)"]
            DSM_GUI["DSM 콘솔 (:5000)"]
        end
    end

    FamilyUser -->|"waceh.asuscomm.com:포트 (VPN 불필요)"| PortForward
    PortForward --> LXC_103
    PortForward --> LXC_104
    PortForward --> LXC_105

    AdminUser -->|"Tailscale WireGuard 암호화 터널"| SubnetRouter
    SubnetRouter -->|"내부 IP(192.168.1.xxx) 직통 라우팅"| PVE_GUI
    SubnetRouter -->|"내부 IP 직통"| DSM_GUI
    SubnetRouter -->|"내부 IP 직통"| Cockpit_GUI
    SubnetRouter -->|"내부 IP 직통"| LXC_102
    SubnetRouter -->|"내부 IP 직통"| LXC_107
```

---

## 🚀 2. 원격 접속 가이드

스마트폰이나 노트북에서 **`Tailscale` 앱을 [ON]**으로 켠 후, 집 안에서 사용하는 내부 IP로 직접 접속합니다:

| 서비스 | 접속 주소 (집 안 IP 그대로) | 접근 권한 |
| :--- | :--- | :---: |
| **🖥️ Proxmox VE** | `https://192.168.1.200:8006` | 관리자 전용 (Tailscale 필수) |
| **💾 Xpenology DSM** | `http://192.168.1.132:5000` | 관리자 전용 (Tailscale 필수) |
| **🌡️ Cockpit 디스크 관제** | `https://192.168.1.200:9090` | 관리자 전용 (Tailscale 필수) |
| **🛡️ AdGuard Home DNS** | `http://192.168.1.102` | 관리자 전용 (Tailscale 필수) |
| **📊 Homepage 대시보드** | `http://192.168.1.107:3000` | 전체 / 관리자 |
| **🔔 Uptime Kuma** | `http://192.168.1.107:3001` | 전체 / 관리자 |

---

## 📱 3. 일상 미디어 앱 설정 가이드 (가족 공용)

가족 구성원은 VPN을 켤 필요 없이 앱에 아래 주소를 입력하여 사용합니다:

- **📸 Immich iOS/Android 앱**: `http://waceh.asuscomm.com:2283`
- **🎵 Amperfy (음악) iOS 앱**: `http://waceh.asuscomm.com:4747`
- **🎬 Swiftfin / Jellyfin 비디오 앱**: `http://waceh.asuscomm.com:8096`

---

## 🛠️ 4. 관련 관리 스크립트

- [`setup_tailscale_subnet_router.sh`](../scripts/setup_tailscale_subnet_router.sh): Proxmox 호스트 커널 IP 포워딩 및 Tailscale 서브넷 라우터 자동 설치 스크립트
