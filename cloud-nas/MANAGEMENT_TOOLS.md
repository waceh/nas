# Management Layer 도구 추천

## 📋 개요

단일 서버 환경(Oracle Cloud)에서 Management Layer에 추가할 수 있는 Wiki 및 프로젝트 관리 도구를 추천합니다.

## 🎯 추천 순위

### 1순위: GitHub 내장 기능 활용 (추가 설치 불필요) ⭐⭐⭐⭐⭐

#### GitHub Wiki
- **장점**: 
  - GitHub 저장소에 포함
  - 추가 리소스 불필요
  - GitHub와 완벽 통합
  - Markdown 지원
- **단점**: 
  - 기능이 제한적 (고급 위키 기능 부족)
- **리소스**: 0MB (이미 포함)

#### GitHub Issues
- **장점**: 
  - GitHub 저장소에 포함
  - 추가 리소스 불필요
  - GitHub와 완벽 통합
  - Milestone, Label, Assignee 지원
  - Projects 보드 기능
- **단점**: 
  - Jira만큼 강력하지 않음
- **리소스**: 0MB (이미 포함)

**결론**: GitHub Wiki + Issues로 시작하는 것을 **강력 추천**합니다.

---

### 2순위: Wiki.js (별도 Wiki 도구) ⭐⭐⭐⭐

#### 특징
- **가벼움**: 약 200-300MB RAM
- **현대적 UI**: 사용하기 쉬움
- **Markdown 지원**: GitHub와 유사한 편집 경험
- **다양한 저장소 연동**: Git, GitHub 등

#### Docker Compose 설정
```yaml
wiki:
  image: ghcr.io/requarks/wiki:2
  container_name: nas-wiki
  restart: unless-stopped
  ports:
    - "8090:3000"
  environment:
    DB_TYPE: mysql
    DB_HOST: mysql
    DB_PORT: 3306
    DB_USER: ${MYSQL_USER}
    DB_PASS: ${MYSQL_PASSWORD}
    DB_NAME: wiki_db
  volumes:
    - wiki_data:/wiki/content
  networks:
    - nas-network
  depends_on:
    - mysql
```

#### 리소스
- **RAM**: 약 200-300MB
- **CPU**: 최소
- **디스크**: 약 100MB

---

### 3순위: BookStack (문서 관리) ⭐⭐⭐⭐

#### 특징
- **사용하기 쉬움**: 직관적인 UI
- **책/페이지 구조**: 문서를 책처럼 구성
- **검색 기능**: 강력한 검색
- **권한 관리**: 세밀한 권한 제어

#### Docker Compose 설정
```yaml
bookstack:
  image: lscr.io/linuxserver/bookstack:latest
  container_name: nas-bookstack
  restart: unless-stopped
  ports:
    - "8091:80"
  environment:
    - DB_HOST=mysql
    - DB_USER=${MYSQL_USER}
    - DB_PASS=${MYSQL_PASSWORD}
    - DB_DATABASE=bookstack_db
    - APP_URL=http://YOUR_SERVER_IP:8091
  volumes:
    - bookstack_data:/config
  networks:
    - nas-network
  depends_on:
    - mysql
```

#### 리소스
- **RAM**: 약 300-400MB
- **CPU**: 최소
- **디스크**: 약 200MB

---

### 4순위: Taiga (Agile 프로젝트 관리) ⭐⭐⭐⭐

#### 특징
- **Jira 대안**: Agile 프로젝트 관리
- **칸반 보드**: 스크럼, 칸반 지원
- **이슈 추적**: 강력한 이슈 관리
- **GitHub 통합**: GitHub와 연동 가능

#### Docker Compose 설정
```yaml
taiga:
  image: taigaio/taiga-back:latest
  container_name: nas-taiga-back
  restart: unless-stopped
  environment:
    - DATABASE_HOST=mysql
    - DATABASE_NAME=taiga_db
    - DATABASE_USER=${MYSQL_USER}
    - DATABASE_PASSWORD=${MYSQL_PASSWORD}
  networks:
    - nas-network
  depends_on:
    - mysql

taiga-front:
  image: taigaio/taiga-front:latest
  container_name: nas-taiga-front
  restart: unless-stopped
  ports:
    - "8092:80"
  networks:
    - nas-network
  depends_on:
    - taiga
```

#### 리소스
- **RAM**: 약 500-600MB
- **CPU**: 1 코어
- **디스크**: 약 300MB

---

### 5순위: Wekan (칸반 보드) ⭐⭐⭐

#### 특징
- **가벼움**: 약 200MB RAM
- **칸반 보드**: 간단한 프로젝트 관리
- **실시간 협업**: 여러 사용자 동시 작업

#### Docker Compose 설정
```yaml
wekan:
  image: wekanteam/wekan:latest
  container_name: nas-wekan
  restart: unless-stopped
  ports:
    - "8093:8080"
  environment:
    - MONGO_URL=mongodb://mongo:27017/wekan
  networks:
    - nas-network
  depends_on:
    - mongo

mongo:
  image: mongo:latest
  container_name: nas-mongo
  restart: unless-stopped
  volumes:
    - mongo_data:/data/db
  networks:
    - nas-network
```

#### 리소스
- **RAM**: 약 200MB (Wekan) + 200MB (MongoDB)
- **CPU**: 최소
- **디스크**: 약 200MB

---

## 💡 종합 추천

### 시나리오 1: 최소 리소스 (강력 추천) ⭐⭐⭐⭐⭐
**GitHub Wiki + GitHub Issues**
- 추가 설치 불필요
- 리소스 사용 0MB
- GitHub와 완벽 통합
- 소규모 팀에 적합
- **Jira처럼 사용 가능**: Labels, Milestones, Projects 보드 활용

### 시나리오 2: 별도 Wiki 필요 시
**Wiki.js**
- 가볍고 현대적
- GitHub와 유사한 경험
- 약 300MB RAM

### 시나리오 3: 문서 중심 관리
**BookStack**
- 사용하기 쉬움
- 책/페이지 구조
- 약 400MB RAM

### 시나리오 4: Agile 프로젝트 관리
**Taiga**
- Jira 대안
- 강력한 기능
- 약 600MB RAM

### 시나리오 5: 간단한 칸반 보드
**Wekan**
- 매우 가벼움
- 간단한 프로젝트 관리
- 약 400MB RAM (MongoDB 포함)

## 📊 비교표

| 도구 | 리소스 | 난이도 | 기능 | GitHub 통합 |
|------|--------|--------|------|-------------|
| GitHub Wiki | 0MB | ⭐ | ⭐⭐⭐ | ✅ 완벽 |
| GitHub Issues | 0MB | ⭐ | ⭐⭐⭐ | ✅ 완벽 |
| Wiki.js | 300MB | ⭐⭐ | ⭐⭐⭐⭐ | ⚠️ 부분 |
| BookStack | 400MB | ⭐⭐ | ⭐⭐⭐⭐ | ❌ 없음 |
| Taiga | 600MB | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⚠️ 부분 |
| Wekan | 400MB | ⭐⭐ | ⭐⭐⭐ | ❌ 없음 |

## 🎯 최종 추천

### 단일 서버 환경 기준
1. **1순위**: GitHub Wiki + Issues (추가 설치 불필요)
2. **2순위**: Wiki.js (별도 Wiki 필요 시)
3. **3순위**: Taiga (Agile 프로젝트 관리 필요 시)

### 리소스 여유가 있다면
- GitHub Wiki + Issues (기본)
- Wiki.js (별도 Wiki)
- 또는 Taiga (프로젝트 관리)

## 📝 설치 가이드

각 도구의 상세 설치 가이드는 다음을 참조하세요:
- **Wiki.js 설치 가이드** (작성 예정)
- **BookStack 설치 가이드** (작성 예정)
- **Taiga 설치 가이드** (작성 예정)

---

**작성일**: 2024년
**대상 환경**: Oracle Cloud Infrastructure 단일 인스턴스
**권장**: GitHub Wiki + Issues (추가 설치 불필요)

