# 웹 접근 가능한 서비스 가이드

OCI 서버에서 실행 중인 웹 GUI 기반 서비스들의 접속 정보 및 사용 가이드입니다.

---

## 📋 목차

- [서비스 요약](#서비스-요약)
- [1. Portainer - Docker 관리](#1-portainer---docker-관리)
- [2. Netdata - 시스템 모니터링](#2-netdata---시스템-모니터링)
- [3. Plane - 프로젝트 관리](#3-plane---프로젝트-관리)
- [4. NAS Frontend - 애플리케이션](#4-nas-frontend---애플리케이션)
- [5. MySQL - 데이터베이스](#5-mysql---데이터베이스)
- [보안 권장사항](#보안-권장사항)

---

## 서비스 요약

| 서비스 | 포트 | 접속 URL | 용도 | 상태 |
|--------|------|----------|------|------|
| **Portainer** | 9000, 9443 | http://158.180.76.251:9000 | Docker 관리 | ✅ 실행 중 |
| **Netdata Cloud** | - | https://app.netdata.cloud | 시스템 모니터링 (권장) | ✅ 연동 완료 |
| **Netdata 로컬** | 19999 | http://158.180.76.251:19999 | 시스템 모니터링 | ✅ 실행 중 |
| **Plane** | 80 | http://158.180.76.251 | 프로젝트 관리 | ✅ 실행 중 |
| **Frontend (Vue)** | 3000 | http://158.180.76.251:3000 | NAS 애플리케이션 | ✅ 실행 중 |
| **MySQL** | 3306 | 158.180.76.251:3306 | 데이터베이스 | ✅ 실행 중 |

---

## 1. Portainer - Docker 관리

### 📊 기본 정보

**접속 URL:**
- HTTP: http://158.180.76.251:9000
- HTTPS: https://158.180.76.251:9443 (권장)

**용도:**
- Docker 컨테이너 관리
- Docker Compose 스택 관리
- 이미지, 볼륨, 네트워크 관리
- 컨테이너 로그 실시간 확인
- 리소스 모니터링

### 🔐 초기 설정

**최초 접속 시 (5분 이내 설정 필요):**
1. 관리자 계정 생성
   - Username: admin (또는 원하는 이름)
   - Password: 최소 12자 이상 강력한 비밀번호
2. "Get Started" 클릭
3. "Local" 환경 자동 연결

**계정 잊어버렸거나 잠긴 경우:**
```bash
# 서버에 SSH 접속 후
cd ~/nas-oracle-cloud
docker compose restart portainer
# 재시작 후 5분 이내 재설정
```

### ✨ 주요 기능

**1. 대시보드**
- 전체 컨테이너 상태 한눈에 확인
- 리소스 사용량 (CPU, 메모리)
- 빠른 액션 버튼

**2. 컨테이너 관리**
```
Containers 메뉴:
├─ 컨테이너 목록 및 필터링
├─ 실행/중지/재시작/삭제
├─ 로그 실시간 스트리밍
├─ 컨테이너 상세 정보
├─ 환경 변수 확인
└─ 터미널 접속 (Console)
```

**3. 스택 관리 (Docker Compose)**
```
Stacks 메뉴:
├─ docker-compose.yml 업로드/편집
├─ 스택 배포 및 업데이트
├─ 환경 변수 관리
└─ 스택 삭제
```

**4. 이미지 관리**
```
Images 메뉴:
├─ 이미지 목록 및 검색
├─ 이미지 빌드 (Dockerfile)
├─ 이미지 Pull/Push
└─ 이미지 삭제
```

**5. 볼륨 관리**
```
Volumes 메뉴:
├─ 볼륨 목록 및 사용량
├─ 볼륨 생성/삭제
└─ 볼륨 상세 정보
```

**6. 네트워크 관리**
```
Networks 메뉴:
├─ 네트워크 목록
├─ 네트워크 생성/삭제
└─ 컨테이너 연결 관리
```

### 💡 유용한 기능

**컨테이너 로그 확인:**
1. Containers → 컨테이너 선택
2. "Logs" 탭 클릭
3. 실시간 로그 스트리밍
4. 검색 및 필터링 가능

**컨테이너 터미널 접속:**
1. Containers → 컨테이너 선택
2. "Console" 탭 클릭
3. "/bin/sh" 또는 "/bin/bash" 선택
4. "Connect" 클릭

**스택 업데이트:**
1. Stacks → nas-oracle-cloud 선택
2. "Editor" 클릭
3. docker-compose.yml 수정
4. "Update the stack" 클릭

---

## 2. Netdata - 시스템 모니터링

### 📊 기본 정보

**접속 URL:**
- **Netdata Cloud (권장)**: https://app.netdata.cloud
- 로컬: http://158.180.76.251:19999

**버전:** v2.8.0-324-nightly

**용도:**
- 실시간 시스템 모니터링
- CPU, 메모리, 디스크, 네트워크 모니터링
- Docker 컨테이너 메트릭
- 애플리케이션 성능 추적
- 알림 및 경고

**✨ Netdata Cloud 연동 완료**
- 동적 IP 환경에서도 언제든지 접속 가능
- https://app.netdata.cloud 에서 "nas-server" 호스트 확인
- 모바일 앱 지원 (iOS/Android)
- 여러 서버 통합 관리 가능
- 알림 및 경고 클라우드 동기화

### ✨ 주요 기능

**1. 시스템 메트릭**
```
대시보드:
├─ CPU 사용률 (코어별)
├─ 메모리 사용률 (RAM)
├─ 디스크 I/O 및 사용량
├─ 네트워크 트래픽
└─ 시스템 로드
```

**2. Docker 모니터링**
```
Docker 섹션:
├─ 컨테이너별 CPU 사용률
├─ 컨테이너별 메모리 사용량
├─ 네트워크 트래픽
└─ 디스크 I/O
```

**3. 애플리케이션 메트릭**
```
Applications 섹션:
├─ MySQL 쿼리 성능
├─ Nginx 연결 수
├─ Redis 메트릭 (설치 시)
└─ 기타 애플리케이션 모니터링
```

### 💡 유용한 기능

**실시간 대시보드:**
- 모든 메트릭이 1초마다 실시간 업데이트
- 그래프 확대/축소 (드래그)
- 시간 범위 선택 (1분, 5분, 1시간, 1일)

**알람 설정:**
- CPU 사용률 90% 초과 시 알림
- 메모리 부족 경고
- 디스크 공간 부족 알림

**성능 분석:**
- 특정 시간대 성능 이슈 분석
- 컨테이너별 리소스 사용 추적
- 병목 지점 파악

### 📱 모바일 접속

모바일 브라우저에서도 완벽하게 작동:
- 반응형 디자인
- 터치 제스처 지원
- 실시간 모니터링

---

## 3. Plane - 프로젝트 관리

### 📊 기본 정보

**접속 URL:**
- http://158.180.76.251

**버전:** v1.2.1

**용도:**
- 이슈 트래킹 & 프로젝트 관리
- Sprint, 칸반, 사이클 관리
- 배포 티켓 관리
- 작업 로그 추적
- 팀 협업 및 문서화

**기술 스택:**
- 마이크로서비스 아키텍처 (12개 컨테이너)
- PostgreSQL 15.7
- Redis (Valkey 7.2.11)
- RabbitMQ 3.13.6
- MinIO (파일 스토리지)

### ✨ 주요 기능

**1. 프로젝트 관리**
```
프로젝트:
├─ 이슈 (Issues) - 작업 항목 생성 및 추적
├─ 사이클 (Cycles) - Sprint 관리
├─ 모듈 (Modules) - 기능별 그룹화
├─ 뷰 (Views) - 커스텀 필터 및 정렬
└─ 페이지 (Pages) - 문서 및 노트
```

**2. 보드 & 뷰**
```
뷰 타입:
├─ 리스트 뷰 - 전통적인 이슈 목록
├─ 칸반 보드 - 드래그 앤 드롭
├─ 테이블 뷰 - 스프레드시트 스타일
├─ 갠트 차트 - 타임라인 시각화
└─ 캘린더 - 일정 기반 뷰
```

**3. 이슈 관리**
```
이슈 기능:
├─ 우선순위 (Urgent, High, Medium, Low)
├─ 상태 (Backlog, Todo, In Progress, Done)
├─ 담당자 할당
├─ 라벨 및 태그
├─ 첨부파일
├─ 댓글 및 멘션
└─ 이슈 링크 (blocks, blocked by, relates to)
```

**4. Sprint (Cycle) 관리**
```
사이클:
├─ 기간 설정 (시작일, 종료일)
├─ 이슈 할당
├─ 번다운 차트
├─ 진행률 추적
└─ 자동 완료
```

**5. 협업 기능**
```
팀 협업:
├─ 실시간 동시 편집 (Live)
├─ 멘션 (@사용자)
├─ 댓글 스레드
├─ 활동 피드
└─ 알림
```

### 💡 사용 방법

**첫 실행 (관리자 계정 생성):**

1. http://158.180.76.251 접속
2. "Create your account" 클릭
3. 계정 정보 입력:
   - Full Name
   - Email
   - Password
4. 워크스페이스 생성 (예: "NAS Development")

**프로젝트 생성:**

1. 대시보드에서 "Create Project" 클릭
2. 프로젝트 정보 입력:
   - 이름 (예: "Release Management")
   - 식별자 (예: "REL")
   - 설명
3. "Create Project" 클릭

**배포 티켓 생성 예시:**

1. 프로젝트 → "New Issue" 클릭
2. 제목: "Deploy Spring Boot v1.2.0 to Production"
3. 설명:
   ```
   ## 배포 정보
   - 서비스: Spring Boot Backend
   - 버전: v1.2.0
   - 환경: Production

   ## 체크리스트
   - [ ] 코드 리뷰 완료
   - [ ] 테스트 통과
   - [ ] Docker 이미지 빌드
   - [ ] 배포 실행
   - [ ] 헬스 체크
   - [ ] Slack 알림
   ```
4. 라벨: "deployment", "backend"
5. 우선순위: High
6. 담당자 할당

**GitHub Actions 통합 (향후):**

Plane Webhook → GitHub Actions → 배포 → Slack 알림

### 🔧 관리 명령어

```bash
# Plane 디렉토리로 이동
cd ~/plane-app/plane-app

# 전체 상태 확인
docker compose ps

# 전체 로그 확인
docker compose logs -f

# 특정 서비스 로그
docker compose logs -f web
docker compose logs -f api

# 재시작
docker compose restart

# 중지
docker compose stop

# 시작
docker compose start

# 업데이트 (새 버전 배포 시)
docker compose pull
docker compose up -d
```

### 📁 설치 위치

```
/home/ubuntu/plane-app/plane-app/
├── docker-compose.yaml    # Docker Compose 설정
├── .env                   # 환경 변수
└── custom-Caddyfile       # 프록시 설정
```

### ⚙️ 컨테이너 구성

**12개 컨테이너 (마이크로서비스):**
- `plane-app-web-1` - 메인 웹 인터페이스
- `plane-app-admin-1` - 관리자 대시보드
- `plane-app-space-1` - 공개 스페이스 (외부 공유)
- `plane-app-live-1` - 실시간 협업
- `plane-app-api-1` - REST API 서버
- `plane-app-worker-1` - 백그라운드 작업
- `plane-app-beat-worker-1` - 스케줄 작업
- `plane-app-plane-db-1` - PostgreSQL
- `plane-app-plane-redis-1` - Redis
- `plane-app-plane-mq-1` - RabbitMQ
- `plane-app-plane-minio-1` - MinIO
- `plane-app-proxy-1` - Caddy 프록시

**리소스 사용량:**
- 메모리: 약 1.14GB (전체의 5%)
- CPU: Idle 시 거의 0%

### 🔗 통합 기능

**GitHub 통합 (설정 가능):**
- Settings → Integrations → GitHub
- 리포지토리 연결
- 이슈 동기화
- PR 링크

**Slack 통합 (설정 가능):**
- Settings → Integrations → Slack
- 이슈 알림
- 댓글 알림
- 배포 알림

### 💡 팁

**배포 티켓 관리 워크플로우:**

1. **티켓 생성**: 배포할 내용을 이슈로 작성
2. **Sprint 할당**: 해당 Cycle에 추가
3. **상태 관리**: Backlog → In Progress → Done
4. **GitHub Actions**: Webhook으로 자동 배포 트리거
5. **완료 확인**: 배포 후 댓글로 결과 기록

**라벨 활용:**
- `deployment`: 배포 관련
- `backend`: 백엔드 배포
- `frontend`: 프론트엔드 배포
- `hotfix`: 긴급 수정
- `rollback`: 롤백 필요

---

## 4. NAS Frontend - 애플리케이션

### 📊 기본 정보

**접속 URL:**
- http://158.180.76.251:3000

**용도:**
- NAS 웹 애플리케이션
- 파일 관리 (예정)
- 사용자 인터페이스

**기술 스택:**
- Vue.js 3
- Node.js 24.13.0 LTS
- Nginx 프록시

### 🔗 API 엔드포인트

**내부적으로 다음 API와 연결:**
- Spring Boot API: `/api/springboot/*`
- Kotlin API: `/api/kotlin/*`

**예시:**
```
http://158.180.76.251:3000/api/springboot/health
http://158.180.76.251:3000/api/kotlin/health
```

### 💡 개발 모드

현재 개발 모드로 실행 중:
- Hot Module Replacement (HMR) 지원
- 코드 변경 시 자동 리로드
- 개발 도구 활성화

---

## 5. MySQL - 데이터베이스

### 📊 기본 정보

**접속 정보:**
- Host: 158.180.76.251
- Port: 3306
- Database: nas_db
- User: nas_user
- Password: (`.env` 파일 참조)

**접속 방법:**

**1. IDE에서 접속 (IntelliJ, DataGrip 등)**
```
Host: 158.180.76.251
Port: 3306
Database: nas_db
User: nas_user
Password: [.env 파일의 MYSQL_PASSWORD]
```

**2. MySQL Workbench**
```
Connection Name: NAS OCI MySQL
Hostname: 158.180.76.251
Port: 3306
Username: nas_user
```

**3. 커맨드라인 (서버 내부)**
```bash
docker compose exec mysql mysql -u nas_user -p nas_db
```

### ⚠️ 보안 주의사항

**현재 상태:**
- ⚠️ 외부에서 직접 접근 가능 (포트 3306 노출)
- 개발 편의를 위해 열어둠

**프로덕션 권장:**
```yaml
# docker-compose.yml에서 포트 노출 제거
mysql:
  # ports:
  #   - "3306:3306"  # 이 부분 주석 처리
```

**SSH 터널링 사용 (권장):**
```bash
# 로컬에서 실행
ssh -L 3306:localhost:3306 -i ~/.ssh/oci-nas-key ubuntu@158.180.76.251

# 이후 localhost:3306으로 접속
```

---

## 🔐 보안 권장사항

### 1. Portainer 보안

**강화 방법:**
```yaml
# OCI Security Group에서 특정 IP만 허용
Portainer (9000, 9443):
- 현재: 0.0.0.0/0 (모든 IP 허용)
- 권장: YOUR_OFFICE_IP/32 (특정 IP만)
```

**2단계 인증 (Enterprise 기능):**
- Community Edition은 미지원
- 강력한 비밀번호 + 정기 변경

### 2. Netdata 보안

**인증 추가 (선택사항):**
```bash
# Netdata 설정 파일 수정
# /etc/netdata/netdata.conf
[web]
    bind to = localhost  # 외부 접근 차단
```

**Nginx 리버스 프록시 + 인증:**
- Basic Auth 추가
- IP 화이트리스트

### 3. MySQL 보안

**포트 닫기 (프로덕션 필수):**
```yaml
# docker-compose.yml
mysql:
  # ports 섹션 제거 또는 주석 처리
  # ports:
  #   - "3306:3306"
```

**SSH 터널링 사용:**
```bash
# 안전한 접속 방법
ssh -L 3306:localhost:3306 ubuntu@158.180.76.251
```

### 4. 전체 보안 체크리스트

- [ ] Portainer 관리자 비밀번호 강력하게 설정
- [ ] OCI Security Group에서 불필요한 포트 제거
- [ ] MySQL 외부 포트 닫기 (SSH 터널 사용)
- [ ] Netdata IP 제한 또는 인증 추가
- [ ] 정기적인 Docker 이미지 업데이트
- [ ] 로그 모니터링 및 이상 접근 감지

---

## 🌐 OCI Security Group 설정

**현재 열려있는 포트:**
```
필수 포트:
- 22: SSH
- 3000: Frontend (NAS 애플리케이션)
- 9000: Portainer HTTP
- 9443: Portainer HTTPS
- 19999: Netdata

선택적 포트:
- 3306: MySQL (개발 시만, 프로덕션은 닫기 권장)
```

**보안 강화 시 설정:**
```
포트 22 (SSH):
- Source: YOUR_HOME_IP/32 (특정 IP만)

포트 3000 (Frontend):
- Source: 0.0.0.0/0 (모든 사용자)

포트 9000, 9443 (Portainer):
- Source: YOUR_HOME_IP/32 (관리자만)

포트 19999 (Netdata):
- Source: YOUR_HOME_IP/32 (관리자만)

포트 3306 (MySQL):
- 닫기 (내부 네트워크만 사용)
```

---

## 📱 빠른 접속 링크

**관리 도구:**
- [Portainer](http://158.180.76.251:9000) - Docker 관리
- [Netdata Cloud](https://app.netdata.cloud) - 시스템 모니터링 (권장, 동적 IP 지원)
- [Netdata 로컬](http://158.180.76.251:19999) - 시스템 모니터링 (로컬)

**프로젝트 관리:**
- [Plane](http://158.180.76.251) - 이슈 트래킹, Sprint, 칸반, 배포 관리

**애플리케이션:**
- [NAS Frontend](http://158.180.76.251:3000) - 메인 애플리케이션

**API 헬스 체크:**
- [Spring Boot Health](http://158.180.76.251:3000/api/springboot/health)
- [Kotlin Health](http://158.180.76.251:3000/api/kotlin/health)

---


## 🔧 문제 해결

### Portainer 접속 불가

**원인:** 5분 타임아웃 또는 설정 미완료

**해결:**
```bash
# SSH 접속 후
cd ~/nas-oracle-cloud
docker compose restart portainer
# 재시작 후 5분 이내 접속하여 계정 생성
```

### Netdata 접속 불가

**원인:** 컨테이너 중지 또는 포트 문제

**확인:**
```bash
# 컨테이너 상태 확인
docker compose ps netdata

# 로그 확인
docker compose logs netdata

# 재시작
docker compose restart netdata
```

### MySQL 연결 실패

**원인:** 비밀번호 오류 또는 네트워크 문제

**확인:**
```bash
# .env 파일에서 비밀번호 확인
cat ~/nas-oracle-cloud/.env | grep MYSQL_PASSWORD

# MySQL 컨테이너 상태 확인
docker compose ps mysql

# 컨테이너 내부에서 연결 테스트
docker compose exec mysql mysql -u nas_user -p nas_db
```

---

**작성일:** 2026-01-31
**서버:** OCI Ubuntu 22.04 ARM64 (158.180.76.251)
**업데이트:** 필요 시 이 문서를 업데이트하세요
