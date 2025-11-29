# OCI Security List 설정 가이드

## 🔒 필요한 포트 열기

외부에서 접속하려면 OCI 콘솔에서 Security List에 다음 포트들을 열어야 합니다.

### OCI 콘솔에서 설정하는 방법

1. **Oracle Cloud Console 접속**
   - https://cloud.oracle.com 접속
   - 해당 리전 선택

2. **네트워킹 메뉴로 이동**
   - 좌측 메뉴: **Networking** → **Virtual Cloud Networks**
   - 인스턴스가 속한 VCN 선택

3. **Security List 선택**
   - VCN 상세 페이지에서 **Security Lists** 클릭
   - 인스턴스가 사용하는 Security List 선택 (보통 Default Security List)

4. **Ingress Rules 추가**
   - **Ingress Rules** 탭 클릭
   - **Add Ingress Rules** 버튼 클릭
   - 아래 포트들을 하나씩 추가:

### 필요한 포트 목록

| 포트 | 프로토콜 | 설명 | 소스 CIDR |
|------|---------|------|-----------|
| **22** | TCP | SSH 접속 | 0.0.0.0/0 (또는 특정 IP) |
| **3000** | TCP | Frontend (Vue) | 0.0.0.0/0 |
| **3030** | TCP | Grafana | 0.0.0.0/0 |
| **8080** | TCP | GitLab HTTP | 0.0.0.0/0 |
| **8443** | TCP | GitLab HTTPS | 0.0.0.0/0 |
| **2222** | TCP | GitLab SSH | 0.0.0.0/0 |
| **9000** | TCP | Portainer HTTP | 0.0.0.0/0 |
| **9443** | TCP | Portainer HTTPS | 0.0.0.0/0 |
| **9090** | TCP | Prometheus | 0.0.0.0/0 |
| **3100** | TCP | Loki | 0.0.0.0.0/0 |

### 보안 권장사항

**프로덕션 환경에서는:**
- SSH (22) 포트는 특정 IP만 허용하는 것을 권장합니다
- 예: `YOUR_OFFICE_IP/32` 또는 `YOUR_HOME_IP/32`

**개발/테스트 환경:**
- 모든 포트를 `0.0.0.0/0`으로 열어도 무방합니다

### OCI CLI를 사용한 설정 (선택사항)

OCI CLI가 설치되어 있다면 다음 명령으로도 설정할 수 있습니다:

```bash
# Security List OCID 확인 필요
# 각 포트에 대해 Ingress Rule 추가
oci network security-list ingress-rule create \
  --security-list-id <SECURITY_LIST_OCID> \
  --description "Allow Frontend" \
  --source "0.0.0.0/0" \
  --protocol "6" \
  --tcp-options '{"destinationPortRange": {"max": 3000, "min": 3000}}'
```

## 🔍 설정 확인 방법

### 1. OCI 콘솔에서 확인
- Security List의 Ingress Rules에 위 포트들이 모두 추가되어 있는지 확인

### 2. 외부에서 포트 테스트
```bash
# Windows PowerShell에서
Test-NetConnection -ComputerName 158.180.76.251 -Port 3000
Test-NetConnection -ComputerName 158.180.76.251 -Port 8080
Test-NetConnection -ComputerName 158.180.76.251 -Port 3030

# Linux/Mac에서
nc -zv 158.180.76.251 3000
nc -zv 158.180.76.251 8080
nc -zv 158.180.76.251 3030
```

### 3. 서버 내부에서 확인
```bash
# 서버에 SSH 접속 후
sudo netstat -tlnp | grep -E '3000|8080|3030|9000|9090'
```

## ⚠️ 문제 해결

### 포트를 열었는데도 접속이 안 되는 경우

1. **서버 내부 방화벽 확인**
   ```bash
   sudo ufw status
   # 필요시 포트 열기
   sudo ufw allow 3000/tcp
   sudo ufw allow 8080/tcp
   ```

2. **Docker 컨테이너 상태 확인**
   ```bash
   docker compose ps
   docker compose logs frontend-vue
   ```

3. **OCI 인스턴스의 Public IP 확인**
   - 인스턴스가 Public IP를 가지고 있는지 확인
   - Public IP가 없다면 추가 필요

4. **Subnet이 Public인지 확인**
   - VCN → Subnets에서 해당 Subnet이 Public Subnet인지 확인
   - Private Subnet이라면 Internet Gateway가 설정되어 있어야 함

## 📝 참고

- OCI Security List는 **네트워크 레벨**의 방화벽입니다
- 서버 내부의 UFW는 **호스트 레벨**의 방화벽입니다
- 두 곳 모두 포트가 열려있어야 외부 접속이 가능합니다

