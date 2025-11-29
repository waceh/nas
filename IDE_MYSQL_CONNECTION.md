# IDE에서 MySQL 접속 가이드

## 📋 개요

로컬 PC의 IDE(IntelliJ IDEA, DBeaver, MySQL Workbench 등)에서 원격 MySQL 서버에 접속하는 방법입니다.

## 🔧 설정 완료 사항

✅ MySQL 포트 외부 노출 (3306)
✅ 서버 내부 방화벽 설정 완료

## ⚠️ OCI Security List 설정 필요

**중요**: OCI 콘솔에서 3306 포트를 열어야 합니다.

### OCI Security List 설정

1. **Oracle Cloud Console 접속**
   - https://cloud.oracle.com 접속
   - 해당 리전 선택

2. **네트워킹 메뉴 이동**
   - 좌측 메뉴: **Networking** → **Virtual Cloud Networks**
   - 인스턴스가 속한 VCN 선택

3. **Security List 선택**
   - VCN 상세 페이지에서 **Security Lists** 클릭
   - 인스턴스가 사용하는 Security List 선택

4. **Ingress Rule 추가**
   - **Ingress Rules** 탭 클릭
   - **Add Ingress Rules** 버튼 클릭
   - 설정:
     - **Source Type**: CIDR
     - **Source CIDR**: `YOUR_IP/32` (본인 IP만 허용 - 보안 강화)
       - 또는 `0.0.0.0/0` (모든 IP 허용 - 개발용)
     - **IP Protocol**: TCP
     - **Destination Port Range**: 3306
     - **Description**: MySQL Development Access

## 🔐 접속 정보

### 기본 정보

- **Host**: `158.180.76.251`
- **Port**: `3306`
- **Database**: `nas_db`
- **Username**: `nas_user`
- **Password**: `nas_password`

### Root 접속 (필요 시)

- **Username**: `root`
- **Password**: `rootpassword`

## 💻 IDE별 설정 방법

### 1. IntelliJ IDEA / DataGrip

1. **Database 도구 창 열기**
   - View → Tool Windows → Database

2. **새 데이터 소스 추가**
   - `+` 버튼 클릭 → **MySQL**

3. **연결 정보 입력**
   ```
   Host: 158.180.76.251
   Port: 3306
   Database: nas_db
   User: nas_user
   Password: nas_password
   ```

4. **테스트 연결**
   - **Test Connection** 클릭
   - 드라이버 다운로드 필요 시 자동 설치

5. **연결 완료**
   - **OK** 클릭하여 저장

### 2. DBeaver

1. **새 데이터베이스 연결**
   - 상단 메뉴: **Database** → **New Database Connection**
   - **MySQL** 선택 → **Next**

2. **연결 정보 입력**
   ```
   Server Host: 158.180.76.251
   Port: 3306
   Database: nas_db
   Username: nas_user
   Password: nas_password
   ```

3. **연결 테스트**
   - **Test Connection** 클릭
   - 드라이버 다운로드 필요 시 자동 설치

4. **연결 완료**
   - **Finish** 클릭

### 3. MySQL Workbench

1. **새 연결 생성**
   - 상단 메뉴: **Database** → **Manage Connections**
   - **+** 버튼 클릭

2. **연결 정보 입력**
   ```
   Connection Name: NAS MySQL
   Hostname: 158.180.76.251
   Port: 3306
   Username: nas_user
   Password: nas_password
   Default Schema: nas_db
   ```

3. **연결 테스트**
   - **Test Connection** 클릭

4. **연결 저장 및 접속**
   - **OK** 클릭
   - 연결 목록에서 더블클릭하여 접속

### 4. VS Code (MySQL Extension)

1. **확장 프로그램 설치**
   - MySQL (by Jun Han) 또는 MySQL (by cweijan)

2. **연결 추가**
   - 확장 프로그램 패널에서 **+** 버튼 클릭
   - 연결 정보 입력:
     ```
     Host: 158.180.76.251
     Port: 3306
     User: nas_user
     Password: nas_password
     Database: nas_db
     ```

3. **연결**
   - 연결 정보 저장 후 접속

## 🧪 연결 테스트

### 명령줄에서 테스트

```bash
# Windows PowerShell 또는 CMD
mysql -h 158.180.76.251 -P 3306 -u nas_user -p nas_db
# 비밀번호: nas_password
```

또는 MySQL 클라이언트가 설치되어 있지 않은 경우:

```bash
# 서버를 통해 테스트
ssh -i ssh-key-2024-05-24.key ubuntu@158.180.76.251 "docker exec nas-mysql mysql -u nas_user -pnas_password nas_db -e 'SELECT VERSION(), DATABASE();'"
```

## 🔒 보안 권장사항

### 개발 환경

1. **특정 IP만 허용** (권장)
   - OCI Security List에서 본인 IP만 허용
   - 예: `YOUR_IP/32`

2. **강력한 비밀번호 사용**
   - 현재 비밀번호가 약한 경우 변경 권장

3. **VPN 사용** (가장 안전)
   - OCI VPN 연결 후 내부 네트워크로 접속

### 프로덕션 환경

- ❌ **외부 포트 노출 금지**
- ✅ **SSH 터널링 사용**
- ✅ **VPN 사용**

## 🛠️ 문제 해결

### 연결 실패 시

1. **OCI Security List 확인**
   - 3306 포트가 열려있는지 확인
   - 본인 IP가 허용되어 있는지 확인

2. **서버 방화벽 확인**
   ```bash
   sudo ufw status | grep 3306
   ```

3. **MySQL 컨테이너 상태 확인**
   ```bash
   docker compose ps mysql
   docker logs nas-mysql --tail=50
   ```

4. **포트 확인**
   ```bash
   sudo netstat -tlnp | grep 3306
   ```

5. **본인 IP 확인**
   - https://whatismyipaddress.com/ 에서 확인
   - OCI Security List에 해당 IP 추가

### 타임아웃 오류

- OCI Security List에 포트가 열려있는지 확인
- 방화벽 설정 확인

### 접근 거부 오류

- 사용자명/비밀번호 확인
- 사용자 권한 확인:
  ```bash
  docker exec nas-mysql mysql -u root -prootpassword -e "SELECT user, host FROM mysql.user WHERE user='nas_user';"
  ```

## 📝 사용 예시

### 테이블 생성

```sql
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 데이터 조회

```sql
SELECT * FROM users;
```

### 인덱스 생성

```sql
CREATE INDEX idx_username ON users(username);
```

## ✅ 체크리스트

- [ ] OCI Security List에 3306 포트 추가
- [ ] 서버 내부 방화벽 확인 (UFW)
- [ ] IDE에서 연결 테스트
- [ ] 테이블 생성 테스트
- [ ] 데이터 조회 테스트

## 🔄 프로덕션 환경 전환 시

프로덕션 환경에서는 외부 포트를 닫고 SSH 터널링을 사용하세요:

```yaml
# docker-compose.yml
mysql:
  # ports:
  #   - "${MYSQL_PORT:-3306}:3306"  # 주석 처리
```

그리고 SSH 터널링 사용:
```bash
ssh -i ssh-key-2024-05-24.key -L 3306:localhost:3306 ubuntu@158.180.76.251
```

