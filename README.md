# NAS (Oracle Cloud) 개발 설정

이 저장소는 Oracle Cloud Infrastructure 인스턴스에서 Docker를 사용하여 개발 환경을 구성하기 위한 설정 파일과 가이드를 포함합니다.

## 📋 목차

- [소개](#소개)
- [아키텍처](#아키텍처)
- [요구사항](#요구사항)
- [설치 방법](#설치-방법)
- [Oracle Cloud 설정](#oracle-cloud-설정)
- [개발 환경 구성](#개발-환경-구성)
- [서비스별 가이드](#서비스별-가이드)
- [사용 방법](#사용-방법)
- [문제 해결](#문제-해결)
- [기여하기](#기여하기)

## 소개

이 프로젝트는 Oracle Cloud Infrastructure 인스턴스에서 Docker를 사용하여 다음 서비스들을 구성합니다:

- **Backend API Server (Spring Boot)**: Kotlin 기반 Spring Boot REST API 서버
- **Backend API Server (Kotlin)**: Ktor 프레임워크를 사용한 순수 Kotlin REST API 서버
- **Frontend Server (Vue.js)**: Vue 3 기반 프론트엔드 애플리케이션
- **Database (MySQL)**: MySQL 8.0 데이터베이스 서버

모든 서비스는 Docker Compose를 통해 오케스트레이션되며, 개발 환경과 프로덕션 환경을 모두 지원합니다.

## 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│         Internet                                        │
│         (Oracle Cloud Public IP)                        │
└───────────────┬──────────────────────────────────────────┘
                │
                │ (포트: 3000)
                ▼
┌─────────────────────────────────────────────────────────┐
│    Oracle Cloud Security Group                          │
│    - HTTP (80)                                          │
│    - HTTPS (443)                                        │
│    - Custom (3000) - 프론트엔드                          │
│    - SSH (22)                                           │
└───────────────┬──────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│         Frontend (Vue.js + nginx)                        │
│         Port: 3000                                       │
│         - 정적 파일 서빙                                  │
│         - API 프록시 (리버스 프록시)                      │
│         - 로드 밸런싱                                    │
└───────────────┬──────────────────────────────────────────┘
                │
                ├─────────────────┐
                │                 │
┌───────────────▼──────┐  ┌───────▼───────────────┐
│  Spring Boot API     │  │   Kotlin API (Ktor)   │
│  Port: 8080          │  │   Port: 8081          │
│  (내부 네트워크)      │  │   (내부 네트워크)      │
└───────────────┬──────┘  └───────┬───────────────┘
                │                 │
                └─────────┬───────┘
                          │
                ┌─────────▼─────────┐
                │   MySQL Database  │
                │   Port: 3306      │
                │   (내부 네트워크)   │
                └───────────────────┘
```

### API 엔드포인트

프론트엔드 서버가 리버스 프록시 역할을 수행하므로, 모든 API 요청은 프론트엔드를 통해 이루어집니다:

- **Spring Boot API**: `http://YOUR_SERVER_IP:3000/api/springboot/*`
- **Kotlin API**: `http://YOUR_SERVER_IP:3000/api/kotlin/*`
- **통합 API** (기본): `http://YOUR_SERVER_IP:3000/api/*` → Spring Boot로 라우팅

## 요구사항

- Oracle Cloud Infrastructure 인스턴스 (Ubuntu 22.04 권장)
- Docker 20.10 이상
- Docker Compose 2.0 이상
- 최소 4GB RAM (권장: 8GB 이상)
- 최소 20GB 디스크 공간
- Oracle Cloud Security Group 설정 (포트 22, 80, 443, 3000)

## 설치 방법

### 1. Oracle Cloud 인스턴스 준비

#### 1.1 시스템 업데이트 및 Docker 설치

```bash
# 시스템 업데이트
sudo apt update && sudo apt upgrade -y

# Docker 설치
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Docker Compose 설치
sudo apt install docker-compose-plugin -y

# 현재 사용자를 docker 그룹에 추가
sudo usermod -aG docker $USER
newgrp docker

# Docker 서비스 시작
sudo systemctl start docker
sudo systemctl enable docker
```

#### 1.2 Git 설치

```bash
sudo apt install git -y
```

### 2. 저장소 클론

```bash
git clone https://github.com/waceh/nas.git
cd nas
```

### 3. 환경 변수 설정

```bash
# 환경 변수 파일 생성
cp env.example .env

# .env 파일을 편집하여 필요한 환경 변수를 설정하세요
# 특히 MySQL 비밀번호와 Oracle Cloud IP를 변경하는 것을 권장합니다
nano .env
```

`.env` 파일의 주요 설정 항목:
- `MYSQL_ROOT_PASSWORD`: MySQL root 비밀번호
- `MYSQL_DATABASE`: 생성할 데이터베이스 이름
- `MYSQL_USER`: 데이터베이스 사용자 이름
- `MYSQL_PASSWORD`: 데이터베이스 사용자 비밀번호
- `SERVER_IP`: 서버의 공인 IP 주소
- 각 서비스의 포트 번호

## Oracle Cloud 설정

### Security Group 설정

Oracle Cloud 콘솔에서 다음 포트를 열어주세요:

1. **SSH (22)**: 인스턴스 접속용
2. **HTTP (80)**: 향후 HTTPS 리다이렉트용
3. **HTTPS (443)**: SSL/TLS 인증서 적용 시
4. **Custom (3000)**: Vue.js 프론트엔드 접근용

**Security Group 규칙 예시:**
```
인바운드 규칙:
- SSH (22): 특정 IP만 허용 (보안 강화 권장)
- HTTP (80): 0.0.0.0/0
- HTTPS (443): 0.0.0.0/0
- Custom (3000): 0.0.0.0/0
```

### 방화벽 설정 (선택사항)

UFW를 사용하여 방화벽을 설정할 수 있습니다:

```bash
# UFW 설치
sudo apt install ufw -y

# 기본 규칙 설정
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 필요한 포트 허용
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 3000/tcp  # Frontend

# 방화벽 활성화
sudo ufw enable
sudo ufw status
```

## 개발 환경 구성

### Docker Compose를 사용한 전체 환경 시작

```bash
# 모든 서비스 빌드 및 시작
docker-compose up -d

# 로그 확인
docker-compose logs -f

# 특정 서비스 로그만 확인
docker-compose logs -f backend-springboot
docker-compose logs -f backend-kotlin
docker-compose logs -f frontend-vue
docker-compose logs -f mysql
```

### 서비스별 개별 제어

```bash
# 특정 서비스만 시작
docker-compose up -d mysql
docker-compose up -d backend-springboot

# 특정 서비스만 중지
docker-compose stop backend-springboot

# 특정 서비스만 재시작
docker-compose restart frontend-vue

# 모든 서비스 중지
docker-compose down

# 모든 서비스 중지 및 볼륨 삭제 (주의: 데이터 삭제됨)
docker-compose down -v
```

## 서비스별 가이드

### MySQL Database

- **포트**: 내부 네트워크만 사용 (보안 강화)
- **데이터 영속성**: `mysql_data` 볼륨에 저장
- **초기화 스크립트**: `docker/mysql/init/init.sql`에 위치
- **설정 파일**: `docker/mysql/conf/my.cnf`

**연결 정보**:
```bash
Host: mysql (Docker 네트워크 내)
Port: 3306
Database: nas_db (기본값)
User: nas_user (기본값)
Password: .env 파일에서 설정한 값
```

### Spring Boot Backend API

- **포트**: 8080 (내부 네트워크)
- **Health Check**: `http://YOUR_SERVER_IP:3000/api/springboot/health`
- **프로젝트 위치**: `backend/springboot/`
- **빌드 도구**: Gradle
- **Java 버전**: 17

### Kotlin Backend API (Ktor)

- **포트**: 8081 (내부 네트워크)
- **Health Check**: `http://YOUR_SERVER_IP:3000/api/kotlin/health`
- **프로젝트 위치**: `backend/kotlin/`
- **프레임워크**: Ktor
- **Java 버전**: 17

### Vue.js Frontend

- **포트**: 3000 (외부 노출)
- **접속 URL**: `http://YOUR_SERVER_IP:3000`
- **프로젝트 위치**: `frontend/vue/`
- **Node 버전**: 18

## 사용 방법

### 전체 환경 시작

```bash
# 1. 환경 변수 설정
cp env.example .env
# .env 파일 편집

# 2. 모든 서비스 시작
docker-compose up -d

# 3. 서비스 상태 확인
docker-compose ps

# 4. 로그 확인
docker-compose logs -f
```

### API 테스트

```bash
# Spring Boot API Health Check
curl http://YOUR_SERVER_IP:3000/api/springboot/health

# Kotlin API Health Check
curl http://YOUR_SERVER_IP:3000/api/kotlin/health
```

### 프론트엔드 접속

브라우저에서 `http://YOUR_SERVER_IP:3000` 접속

### 데이터베이스 접속

```bash
# Docker 컨테이너 내부에서 MySQL 접속
docker-compose exec mysql mysql -u nas_user -p nas_db
```

## 문제 해결

### 일반적인 문제

**문제**: Docker 컨테이너가 시작되지 않음
- **해결**: Docker 서비스가 실행 중인지 확인하세요
```bash
docker ps
docker-compose ps
sudo systemctl status docker
```

**문제**: 포트 충돌
- **해결**: `.env` 파일에서 포트 번호를 변경하세요

**문제**: MySQL 연결 실패
- **해결**: MySQL 컨테이너가 완전히 시작될 때까지 기다리세요
```bash
docker-compose logs mysql
# "ready for connections" 메시지가 나올 때까지 대기
```

**문제**: Oracle Cloud에서 접속 불가
- **해결**: Security Group 설정을 확인하세요
  - 포트 3000이 열려있는지 확인
  - 인스턴스의 공인 IP 주소 확인

**문제**: 볼륨 권한 오류
- **해결**: Docker 볼륨 권한을 확인하세요
```bash
docker volume ls
docker volume inspect nas_mysql_data
```

## 주요 기능

- ✅ Docker Compose를 통한 통합 개발 환경
- ✅ Spring Boot (Kotlin) 백엔드 API 서버
- ✅ Ktor 기반 순수 Kotlin 백엔드 API 서버
- ✅ Vue.js 3 프론트엔드 애플리케이션
- ✅ MySQL 8.0 데이터베이스
- ✅ 핫 리로드 지원 (개발 모드)
- ✅ 데이터 영속성 보장 (Docker 볼륨)
- ✅ 네트워크 격리 및 서비스 간 통신
- ✅ nginx 리버스 프록시 및 로드 밸런싱
- ✅ Oracle Cloud 환경 최적화

## 기여하기

프로젝트에 기여하고 싶으시다면 다음 단계를 따르세요:

1. 저장소를 Fork합니다
2. `develop` 브랜치에서 `feature/your-feature-name` 브랜치를 생성합니다
3. 변경 사항을 커밋합니다
4. 브랜치를 푸시하고 Pull Request를 생성합니다

## 라이선스

이 프로젝트는 MIT 라이선스를 따릅니다.

## 📞 연락처

프로젝트 관련 문의사항이 있으시면 이슈를 등록해주세요.

