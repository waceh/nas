# Oracle Cloud NAS 환경 구성 계획서

## 📋 개요

이 문서는 Oracle Cloud 인스턴스에 NAS 환경을 구성하기 위한 계획서입니다.

**현재 환경:**
- **서버**: Oracle Cloud 인스턴스 (Ubuntu 22.04, ARM64)
- **IP**: 158.180.76.251
- **사용자**: ubuntu
- **SSH 키**: ssh-key-2024-05-24.key

**목표:**
- Docker 기반 마이크로서비스 아키텍처 구성
- Spring Boot + Kotlin (Ktor) 백엔드 API 서버
- Vue.js 프론트엔드
- MySQL 데이터베이스
- nginx 리버스 프록시 및 로드 밸런싱

---

## 🏗️ 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│         Internet                                        │
│         (158.180.76.251)                                │
└───────────────┬──────────────────────────────────────────┘
                │
                │ (포트: 80, 443, 3000)
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
│         Port: 3000 (외부 노출)                           │
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

---

## 📝 작업 단계

### 1단계: Oracle Cloud 인스턴스 환경 준비

#### 1.1 시스템 업데이트 및 필수 패키지 설치
- [ ] 시스템 패키지 업데이트
- [ ] Docker 설치 및 설정
- [ ] Docker Compose 설치
- [ ] Git 설치
- [ ] 방화벽 설정 (UFW 또는 iptables)

#### 1.2 디스크 및 스토리지 확인
- [ ] 현재 디스크 사용량 확인
- [ ] Docker 볼륨 저장소 위치 확인
- [ ] 필요시 추가 스토리지 볼륨 마운트

#### 1.3 네트워크 및 보안 설정
- [ ] Oracle Cloud Security Group 설정
  - HTTP (80)
  - HTTPS (443)
  - Custom Port (3000) - 프론트엔드
  - SSH (22)
- [ ] UFW 방화벽 규칙 설정 (선택사항)

---

### 2단계: 프로젝트 저장소 설정

#### 2.1 GitHub 저장소 클론
- [ ] `waceh/nas` 저장소 클론 또는 초기화
- [ ] 프로젝트 구조 생성

#### 2.2 프로젝트 구조 생성
```
nas/
├── docker-compose.yml          # Docker Compose 설정 파일
├── docker-compose.prod.yml     # 프로덕션 환경 오버라이드
├── .env                        # 환경 변수 (보안상 .gitignore에 추가)
├── env.example                 # 환경 변수 예제
├── README.md                   # 프로젝트 문서
│
├── backend/
│   ├── springboot/            # Spring Boot 백엔드
│   │   ├── Dockerfile
│   │   ├── Dockerfile.dev
│   │   ├── build.gradle.kts
│   │   └── src/
│   │
│   └── kotlin/                # Kotlin (Ktor) 백엔드
│       ├── Dockerfile
│       ├── Dockerfile.dev
│       ├── build.gradle.kts
│       └── src/
│
├── frontend/
│   └── vue/                   # Vue.js 프론트엔드
│       ├── Dockerfile
│       ├── Dockerfile.dev
│       ├── nginx.conf
│       ├── package.json
│       └── src/
│
└── docker/
    └── mysql/                 # MySQL 설정
        ├── init/              # 초기화 스크립트
        └── conf/              # MySQL 설정 파일
```

---

### 3단계: Docker Compose 설정

#### 3.1 Oracle Cloud 환경 특징

- 공인 IP 기반 접근 (158.180.76.251)
- 외부 접근을 위한 포트 노출
- 클라우드 환경에 맞는 볼륨 경로
- 보안 강화 (HTTPS, 방화벽)

#### 3.2 docker-compose.yml 주요 설정

1. **프론트엔드 포트 노출**
   ```yaml
   frontend-vue:
     ports:
       - "3000:3000"  # 외부 접근 허용
   ```

2. **환경 변수 수정**
   - `VUE_APP_API_URL`: `http://158.180.76.251:8080` 또는 상대 경로
   - `VUE_APP_KOTLIN_API_URL`: `http://158.180.76.251:8081` 또는 상대 경로

3. **볼륨 경로**
   - Oracle Cloud 인스턴스에 맞는 경로 사용
   - 예: `/home/ubuntu/nas/data/...`

4. **네트워크 설정**
   - Docker 네트워크는 그대로 유지 (내부 통신)
   - 외부 접근은 Security Group에서 제어

---

### 4단계: 환경 변수 설정

#### 4.1 .env 파일 생성
```bash
# MySQL Database Configuration
MYSQL_ROOT_PASSWORD=<강력한_비밀번호>
MYSQL_DATABASE=nas_db
MYSQL_USER=nas_user
MYSQL_PASSWORD=<강력한_비밀번호>
MYSQL_PORT=3306

# Spring Boot Backend Configuration
SPRINGBOOT_PORT=8080
SPRING_PROFILES_ACTIVE=production

# Kotlin Backend Configuration
KOTLIN_PORT=8081

# Vue Frontend Configuration
VUE_PORT=3000
NODE_ENV=production

# API URLs (Oracle Cloud IP 사용)
VUE_APP_API_URL=http://158.180.76.251:8080
VUE_APP_KOTLIN_API_URL=http://158.180.76.251:8081
```

#### 4.2 보안 고려사항
- [ ] `.env` 파일을 `.gitignore`에 추가
- [ ] 강력한 비밀번호 사용
- [ ] 프로덕션 환경에서는 환경 변수 암호화 고려

---

### 5단계: Oracle Cloud Security Group 설정

#### 5.1 필요한 포트
- **22**: SSH 접속
- **80**: HTTP (향후 HTTPS 리다이렉트용)
- **443**: HTTPS (SSL/TLS 인증서 적용 시)
- **3000**: Vue.js 프론트엔드 (임시, 향후 80/443으로 변경)
- **8080**: Spring Boot API (선택사항, nginx 프록시 사용 시 불필요)
- **8081**: Kotlin API (선택사항, nginx 프록시 사용 시 불필요)

#### 5.2 Security Group 규칙
```
인바운드 규칙:
- SSH (22): 특정 IP만 허용 (보안 강화)
- HTTP (80): 0.0.0.0/0 (모든 IP)
- HTTPS (443): 0.0.0.0/0 (모든 IP)
- Custom (3000): 0.0.0.0/0 (프론트엔드 접근용)

아웃바운드 규칙:
- 모든 트래픽 허용 (기본값)
```

---

### 6단계: 서비스 배포 및 실행

#### 6.1 초기 배포
```bash
# 1. 프로젝트 디렉토리로 이동
cd /home/ubuntu/nas

# 2. 환경 변수 파일 생성
cp env.example .env
# .env 파일 편집

# 3. Docker 이미지 빌드
docker-compose build

# 4. 서비스 시작
docker-compose up -d

# 5. 로그 확인
docker-compose logs -f
```

#### 6.2 헬스 체크
- [ ] Spring Boot API: `http://158.180.76.251:3000/api/springboot/health`
- [ ] Kotlin API: `http://158.180.76.251:3000/api/kotlin/health`
- [ ] 프론트엔드: `http://158.180.76.251:3000`
- [ ] MySQL 연결 확인

---

### 7단계: 보안 강화 (선택사항)

#### 7.1 SSL/TLS 인증서 설정
- [ ] Let's Encrypt 인증서 발급 (Certbot 사용)
- [ ] nginx SSL 설정
- [ ] HTTP → HTTPS 리다이렉트

#### 7.2 방화벽 설정
- [ ] UFW 활성화
- [ ] 필요한 포트만 허용
- [ ] SSH 포트 제한 (특정 IP만)

#### 7.3 데이터베이스 보안
- [ ] MySQL 외부 접근 차단 (내부 네트워크만)
- [ ] 강력한 비밀번호 사용
- [ ] 정기적인 백업 설정

---

### 8단계: 모니터링 및 유지보수

#### 8.1 로그 관리
- [ ] Docker 로그 로테이션 설정
- [ ] 애플리케이션 로그 수집
- [ ] 에러 모니터링

#### 8.2 백업 전략
- [ ] MySQL 데이터베이스 정기 백업
- [ ] Docker 볼륨 백업
- [ ] 설정 파일 백업

#### 8.3 업데이트 및 패치
- [ ] 정기적인 시스템 업데이트
- [ ] Docker 이미지 업데이트
- [ ] 보안 패치 적용

---

## 🔄 Oracle Cloud 환경 특징

- **접근 방식**: 공인 IP (158.180.76.251)
- **포트 노출**: Security Group 설정 필요
- **볼륨 경로**: `/home/ubuntu/nas/data/...`
- **보안**: 클라우드 보안 그룹 + 방화벽
- **SSL/TLS**: 권장 (Let's Encrypt)
- **백업**: 클라우드 스토리지 연동 가능
- **모니터링**: 클라우드 모니터링 도구 활용

---

## 📌 다음 단계

1. **즉시 실행 가능한 작업**
   - [ ] Oracle Cloud 인스턴스에 Docker 설치
   - [ ] 프로젝트 구조 생성
   - [ ] docker-compose.yml 파일 작성

2. **단계별 진행**
   - [ ] 1단계: 환경 준비
   - [ ] 2단계: 프로젝트 설정
   - [ ] 3단계: Docker Compose 구성
   - [ ] 4단계: 배포 및 테스트

3. **향후 개선사항**
   - [ ] CI/CD 파이프라인 구축
   - [ ] 자동 백업 시스템
   - [ ] 모니터링 대시보드
   - [ ] 로드 밸런서 추가 (고가용성)

---

## 📚 참고 자료

- [waceh/nas 저장소](https://github.com/waceh/nas) - Oracle Cloud 적용 버전
- [Oracle Cloud Infrastructure 문서](https://docs.oracle.com/en-us/iaas/Content/home.htm)
- [Docker Compose 문서](https://docs.docker.com/compose/)

---

**작성일**: 2024년
**대상 환경**: Oracle Cloud Infrastructure (Ubuntu 22.04 ARM64)
**IP 주소**: 158.180.76.251

