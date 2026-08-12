# 네트워크 설정 가이드

대상: Vpro C246 온보드 LAN x4
10Gbps PCIe NIC는 **아직 구매 전** → 관련 설정은 "6. 향후 확장" 참고, 현재는 온보드 LAN만으로 구성

## 0. 현재 네트워크 토폴로지
```
Internet(origin)
   │
통신사 공유기 (ISP 모뎀/공유기)
   │
ASUS 공유기 (내 방, 유무선)
   ├── NAS (유선)
   ├── PC (유선)
   └── MacBook M1 Pro 16" (WiFi)
```
- 통신사 공유기 → ASUS 공유기 구간은 **이중 NAT** 상태 (둘 다 라우터 역할 중)
- 외부에서 NAS 서비스 접근하려면 포트포워딩을 **두 단계** 다 설정해야 함 (5번 참고)
- 맥북은 현재 WiFi로만 접속 → 10G 직결은 NIC 구매 후 적용 (6번 참고)

## 1. 이중 NAT 정리 권장
포트포워딩/VPN 설정 전에 아래 중 하나 먼저 결정할 것.

**방법 A (권장): 통신사 공유기를 브리지 모드로 전환**
- 통신사 공유기 설정에서 "브리지 모드" 또는 "AP 모드"로 변경 가능하면 전환
- ASUS 공유기가 PPPoE/공인 IP 직접 수신 → 이중 NAT 해소, 포트포워딩 ASUS 한 곳에서만 처리
- 통신사(예: KT/SKB/LG U+)별로 브리지 모드 지원 여부/설정 방법 다름 → 고객센터 문의 필요

**방법 B: 이중 NAT 유지 + 양쪽 포트포워딩**
- 브리지 모드 불가능한 회선(공유기 일체형 등)이면 이 방법 사용
- 통신사 공유기: 외부 포트 → ASUS 공유기의 WAN(내부) IP:같은 포트로 포워딩
- ASUS 공유기: 그 포트 → NAS 내부 IP:포트로 포워딩
- 설정 두 배로 번거롭고 일부 UPnP/NAT-PMP 기능 제한됨 → 방법 A 가능하면 우선 시도

## 2. 온보드 LAN 포트 구성 (Vpro C246, 4포트)
현재는 10G NIC 없이 온보드 4포트만 사용 가능.

| 포트 | 용도 | 비고 |
|:---|:---|:---|
| LAN1 (eno1) | ASUS 공유기 연결, 관리 + 전체 VM/LXC 트래픽 | 현재 유일하게 사용 중인 포트 |
| LAN2~4 | 미사용 | 아래 활용 방안 참고 |

### 남는 포트 활용 방안 (선택)
1. **링크 애그리게이션(LACP)**: ASUS 공유기가 LAG/Link Aggregation 지원하는 모델(RT-AX88U 등 일부 상위 기종)이면 LAN2를 추가 연결해 대역폭 이중화·이중화(failover) 가능. ASUS 웹 UI에서 LACP 지원 포트 확인 필요.
2. **미사용 유지**: 당장 필요 없으면 그대로 두고 10G NIC 도입 후 재검토
3. **격리 용도**: 나중에 IoT/게스트 기기 등 별도 네트워크 분리가 필요해지면 그때 LAN2를 별도 vmbr용으로 활성화

현재 단계에서는 LAN1 하나만 vmbr0에 연결하는 것으로 충분.

## 3. NIC 인식 확인
```bash
lspci | grep -i ethernet
ip link show
```

## 4. Proxmox 브리지 설정 (현재 구성 — 온보드 LAN1만 사용)
`/etc/network/interfaces` 예시:
```
auto lo
iface lo inet loopback

auto eno1
iface eno1 inet manual

auto vmbr0
iface vmbr0 inet static
    address 192.168.50.10/24
    gateway 192.168.50.1
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
```
- 실제 인터페이스명(`eno1`)은 `ip link show` 결과로 교체
- IP 대역은 ASUS 공유기 DHCP 대역에 맞게 조정 (ASUS 기본값 `192.168.50.x` 또는 `192.168.1.x` 등 실제 설정 확인)
- ASUS 공유기에서 NAS는 **고정 IP 예약(DHCP Reservation)** 해두는 것 권장 — MAC 주소 기준으로 항상 같은 IP 부여, Proxmox 쪽 static 설정과 일치시킬 것
- 변경 후 적용:
```bash
systemctl restart networking
```

## 5. 외부 포트포워딩 기록
이중 NAT 상태면 통신사 공유기 + ASUS 공유기 **양쪽 다 기록**. 관리자 페이지(Proxmox 8006, DSM 5000/5001)는 외부 노출 금지 — 필요시 VPN(WireGuard)으로 접근.

| 서비스 | NAS 내부 IP:Port | ASUS 외부 Port | 통신사 공유기 Port (이중 NAT 시) | 프로토콜 | 비고 |
|:---|:---|:---|:---|:---|:---|
| Nextcloud | (기록 예정) | (기록 예정) | (기록 예정, 방법A면 불필요) | TCP | 리버스 프록시 경유 권장 |
| Immich | (기록 예정) | (기록 예정) | (기록 예정, 방법A면 불필요) | TCP | 리버스 프록시 경유 권장 |
| Vaultwarden | (기록 예정) | (기록 예정) | (기록 예정, 방법A면 불필요) | TCP | HTTPS 필수 |
| WireGuard (VPN) | (기록 예정) | (기록 예정) | (기록 예정, 방법A면 불필요) | UDP | 관리자 페이지 접근용 |

- 방법 A(브리지 모드)로 전환했다면 "통신사 공유기 Port" 칸은 해당 없음
- 외부 도메인/DDNS 쓸 경우 여기에 기록: (기록 예정)
- 리버스 프록시(Nginx Proxy Manager 등) 도입 시 80/443만 포워딩하고 나머지는 내부 라우팅 권장

## 6. 향후 확장 — 10Gbps NIC 구매 후
구매 후 아래 절차로 맥북 직결 구성 (현재는 미적용, 참고용으로 남겨둠).

- PCIe 10G NIC 장착 후 인식 확인: `lspci | grep -i ethernet`
- 맥북(M1 Pro 16", Thunderbolt 3/4 ↔ 10G 이더넷 어댑터 또는 카드 필요)과 스위치 없이 직결
- Proxmox에 추가 브리지 구성:
```
auto enp1s0
iface enp1s0 inet manual

auto vmbr1
iface vmbr1 inet static
    address 10.10.10.1/24
    bridge-ports enp1s0
    bridge-stp off
    bridge-fd 0
```
- 맥북 쪽: 시스템 설정 → 네트워크 → 10G 어댑터 → 수동 IP `10.10.10.2/24`, 라우터 비움
- 헤놀로지 VM에 NIC 추가해 vmbr1 연결하면 DSM에서 두 번째 고정 IP 부여 후 SMB/NFS로 10G 속도 접근 가능:
```bash
qm set 101 -net1 virtio,bridge=vmbr1
```

## 7. 방화벽
- Proxmox 자체 방화벽은 기본 비활성 상태 유지 (이미 이중 NAT 뒤에 있어 우선순위 낮음)
- 외부 노출 서비스 늘어나면 Datacenter → Firewall에서 vmbr0 기준 인바운드 룰 추가 검토
