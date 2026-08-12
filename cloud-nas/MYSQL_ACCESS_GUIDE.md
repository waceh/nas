# MySQL 접속 가이드

## 📋 개요

현재 MySQL은 보안을 위해 **내부 Docker 네트워크에서만 접근 가능**하도록 설정되어 있습니다.

## 🔐 접속 정보

### 환경 변수 확인

```bash
cd ~/nas-oracle-cloud
cat .env | grep MYSQL
```

기본 설정:
- **Host**: `mysql` (Docker 네트워크 내)
- **Port**: `3306`
- **Database**: `nas_db` (기본값)
- **User**: `nas_user` (기본값)
- **Password**: `.env` 파일에서 확인

## 🔧 접속 방법

### 방법 1: Docker 컨테이너 내부에서 접속 (가장 간단)

```bash
# MySQL 컨테이너에 접속
docker exec -it nas-mysql bash

# MySQL 클라이언트로 접속
mysql -u nas_user -p nas_db
# 비밀번호 입력 (nas_password 또는 .env 파일의 값)
```

또는 한 번에:

```bash
docker exec -it nas-mysql mysql -u nas_user -p nas_db
```

### 방법 2: 호스트에서 직접 접속

```bash
# MySQL 클라이언트가 설치되어 있어야 함
docker exec -it nas-mysql mysql -u nas_user -p nas_db

# 또는 root로 접속
docker exec -it nas-mysql mysql -u root -p
```

### 방법 3: 외부에서 접속 (포트 열기 필요)

#### 3-1. docker-compose.yml 수정

```yaml
mysql:
  ports:
    - "3306:3306"  # 주석 해제
```

#### 3-2. OCI Security List에 3306 포트 추가

- Oracle Cloud Console → Networking → Security Lists
- Ingress Rule 추가:
  - Port: 3306
  - Protocol: TCP
  - Source: 특정 IP만 허용 (보안 강화)

#### 3-3. 외부에서 접속

```bash
# MySQL 클라이언트 사용
mysql -h YOUR_SERVER_IP -P 3306 -u nas_user -p nas_db

# 또는 MySQL Workbench, DBeaver 등 GUI 도구 사용
# Host: YOUR_SERVER_IP
# Port: 3306
# User: nas_user
# Password: .env 파일의 값
```

## 🛠️ 유용한 명령어

### 데이터베이스 목록 확인

```bash
docker exec -it nas-mysql mysql -u root -p -e "SHOW DATABASES;"
```

### 테이블 목록 확인

```bash
docker exec -it nas-mysql mysql -u nas_user -p nas_db -e "SHOW TABLES;"
```

### SQL 쿼리 실행

```bash
docker exec -it nas-mysql mysql -u nas_user -p nas_db -e "SELECT * FROM your_table;"
```

### SQL 파일 실행

```bash
docker exec -i nas-mysql mysql -u nas_user -p nas_db < your_script.sql
```

### 백업

```bash
# 데이터베이스 백업
docker exec nas-mysql mysqldump -u root -p nas_db > backup_$(date +%Y%m%d).sql

# 전체 백업
docker exec nas-mysql mysqldump -u root -p --all-databases > full_backup_$(date +%Y%m%d).sql
```

### 복원

```bash
docker exec -i nas-mysql mysql -u root -p nas_db < backup_20241129.sql
```

## 🔒 보안 권장사항

### 현재 설정 (권장)

- ✅ 외부 포트 노출 안 함 (내부 네트워크만)
- ✅ 강력한 비밀번호 사용
- ✅ 일반 사용자 계정 사용 (root 직접 접속 제한)

### 외부 접속이 필요한 경우

1. **SSH 터널링 사용 (가장 안전)**
   ```bash
   # 로컬에서 SSH 터널 생성
   ssh -i your-ssh-key.key -L 3306:localhost:3306 ubuntu@YOUR_SERVER_IP
   
   # 다른 터미널에서 로컬 MySQL로 접속
   mysql -h 127.0.0.1 -P 3306 -u nas_user -p nas_db
   ```

2. **특정 IP만 허용**
   - OCI Security List에서 특정 IP만 3306 포트 허용
   - 예: `YOUR_OFFICE_IP/32`

3. **VPN 사용**
   - OCI VPN 연결 후 내부 네트워크로 접속

## 📝 환경 변수 확인

```bash
cd ~/nas-oracle-cloud
cat .env
```

주요 변수:
- `MYSQL_ROOT_PASSWORD`: root 비밀번호
- `MYSQL_DATABASE`: 데이터베이스 이름
- `MYSQL_USER`: 사용자 이름
- `MYSQL_PASSWORD`: 사용자 비밀번호

## 🚨 문제 해결

### 접속 실패 시

1. **컨테이너 상태 확인**
   ```bash
   docker compose ps mysql
   ```

2. **로그 확인**
   ```bash
   docker logs nas-mysql --tail=50
   ```

3. **비밀번호 확인**
   ```bash
   cat ~/nas-oracle-cloud/.env | grep MYSQL_PASSWORD
   ```

4. **네트워크 확인**
   ```bash
   docker network inspect nas-oracle-cloud_nas-network
   ```

### 비밀번호를 잊은 경우

```bash
# root 비밀번호 재설정
docker exec -it nas-mysql mysql -u root -p
# 기존 root 비밀번호 입력 후:
ALTER USER 'root'@'localhost' IDENTIFIED BY 'new_password';
FLUSH PRIVILEGES;
```

## 💡 GUI 도구 사용

### MySQL Workbench

1. **SSH 터널 설정**:
   - SSH Hostname: `YOUR_SERVER_IP`
   - SSH Username: `ubuntu`
   - SSH Key File: `your-ssh-key.key`
   - MySQL Hostname: `localhost` (SSH 터널을 통해)
   - MySQL Port: `3306`
   - Username: `nas_user`
   - Password: `.env` 파일의 값

### DBeaver

1. **새 연결 생성** → MySQL
2. **SSH 터널 탭**:
   - Host: `YOUR_SERVER_IP`
   - Port: `22`
   - User: `ubuntu`
   - Authentication: Key file (`your-ssh-key.key`)
3. **Main 탭**:
   - Host: `localhost`
   - Port: `3306`
   - Database: `nas_db`
   - Username: `nas_user`
   - Password: `.env` 파일의 값

## ✅ 빠른 참조

```bash
# 가장 간단한 접속 방법
docker exec -it nas-mysql mysql -u nas_user -p nas_db

# 비밀번호: .env 파일의 MYSQL_PASSWORD 값
```

