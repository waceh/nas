# 스케일링 및 고가용성 전략

## 📋 개요

단일 서버 환경에서 롤링 배포 및 고가용성을 위한 스케일링 전략을 검토합니다.

## 🎯 요구사항

- Spring Boot 인스턴스: 2개 (롤링 배포)
- Kotlin 인스턴스: 2개 (롤링 배포)
- MySQL Master/Slave 구성 검토
- Frontend 서버 2개 구성 검토

## 🔍 구성 요소별 검토

### 1. Backend 인스턴스 (Spring Boot, Kotlin) - 2개 구성 ✅

#### 장점
- ✅ **롤링 배포**: 무중단 배포 가능
- ✅ **로드 밸런싱**: 트래픽 분산
- ✅ **고가용성**: 한 인스턴스 장애 시 다른 인스턴스로 서비스 지속
- ✅ **리소스 효율**: 단일 서버에서도 가능

#### 단점
- ⚠️ **리소스 사용**: 메모리 및 CPU 사용량 증가
- ⚠️ **세션 관리**: 세션 공유 필요 (Stateless 권장)

#### 권장 구성
```yaml
# docker-compose.yml
services:
  backend-springboot:
    deploy:
      replicas: 2
    # 또는
    scale: 2
```

#### 로드 밸런싱
- Nginx를 통한 로드 밸런싱
- Round-robin 또는 Least connections 방식

**결론**: ✅ **강력 추천** - 롤링 배포 및 고가용성을 위해 필수

---

### 2. MySQL Master/Slave 구성 검토

#### 시나리오 1: Master/Slave 구성 (단일 서버) ⚠️

**구성**:
```
Master MySQL (포트 3306)
    ↓
Slave MySQL (포트 3307)
```

#### 장점
- ✅ **읽기 성능 향상**: 읽기 쿼리를 Slave로 분산
- ✅ **백업**: 실시간 복제로 백업 용이
- ✅ **장애 복구**: Master 장애 시 Slave 승격 가능

#### 단점
- ⚠️ **리소스 사용**: 2배의 메모리 및 디스크 사용
- ⚠️ **복잡도**: 복제 설정 및 관리 필요
- ⚠️ **단일 서버 제한**: 실제 고가용성은 아님 (같은 서버)
- ⚠️ **디스크 I/O**: 단일 디스크에서 병목 가능

#### 시나리오 2: 단일 MySQL + 백업 (권장) ⭐⭐⭐⭐⭐

**구성**:
```
MySQL (단일 인스턴스)
    ↓
정기 백업 (cron)
```

#### 장점
- ✅ **단순함**: 설정 및 관리 용이
- ✅ **리소스 효율**: 메모리 및 디스크 절약
- ✅ **충분한 성능**: 소규모/중규모 프로젝트에 적합
- ✅ **백업 전략**: 정기 백업으로 데이터 보호

#### 단점
- ⚠️ **읽기 성능**: 읽기 쿼리 분산 불가
- ⚠️ **장애 복구**: 복구 시간 필요

#### 권장 사항

**단일 서버 환경**: ⭐⭐⭐⭐⭐ **단일 MySQL + 백업**
- Master/Slave는 실제 고가용성을 제공하지 않음 (같은 서버)
- 리소스 절약이 더 중요
- 정기 백업으로 충분

**Master/Slave가 필요한 경우**:
- 읽기 쿼리가 매우 많은 경우
- 별도 서버로 Slave 구성 가능한 경우
- 실제 고가용성이 필요한 경우

**결론**: ⚠️ **비추천** (단일 서버 환경)
- 단일 MySQL + 정기 백업 권장
- 필요 시 읽기 전용 복제본 추가 고려

---

### 3. Frontend 서버 2개 구성 검토

#### 시나리오 1: Frontend 2개 구성 ⚠️

**구성**:
```
Frontend 1 (포트 3000)
Frontend 2 (포트 3001)
    ↓
Nginx 로드 밸런서 (포트 80)
```

#### 장점
- ✅ **고가용성**: 한 인스턴스 장애 시 다른 인스턴스로 서비스 지속
- ✅ **로드 밸런싱**: 트래픽 분산
- ✅ **롤링 배포**: 무중단 배포 가능

#### 단점
- ⚠️ **리소스 사용**: 메모리 및 CPU 사용량 증가
- ⚠️ **복잡도**: 로드 밸런서 설정 필요
- ⚠️ **필요성 의문**: Frontend는 정적 파일 서빙이므로 장애 영향 적음

#### 시나리오 2: 단일 Frontend (권장) ⭐⭐⭐⭐

**구성**:
```
Frontend (단일 인스턴스)
    ↓
Nginx (정적 파일 캐싱)
```

#### 장점
- ✅ **단순함**: 설정 및 관리 용이
- ✅ **리소스 효율**: 메모리 및 CPU 절약
- ✅ **충분한 성능**: Frontend는 가벼움
- ✅ **캐싱**: Nginx 캐싱으로 성능 향상

#### 단점
- ⚠️ **단일 장애점**: Frontend 장애 시 서비스 중단
- ⚠️ **롤링 배포**: 배포 시 일시적 중단 가능

#### 권장 사항

**단일 서버 환경**: ⭐⭐⭐⭐ **단일 Frontend**
- Frontend는 정적 파일 서빙이므로 장애 영향 적음
- Nginx 캐싱으로 성능 향상 가능
- 리소스 절약이 더 중요

**Frontend 2개가 필요한 경우**:
- 매우 높은 트래픽
- 실제 고가용성 필요
- 롤링 배포 필수

**결론**: ⚠️ **선택사항**
- 소규모/중규모: 단일 Frontend 권장
- 대규모/고가용성 필요: Frontend 2개 고려

---

## 💡 최종 권장 구성

### 권장 구성 (단일 서버 환경)

```
Backend:
├── Spring Boot: 2개 (롤링 배포) ✅
├── Kotlin: 2개 (롤링 배포) ✅
└── 로드 밸런싱: Frontend Nginx

Database:
└── MySQL: 1개 (단일 인스턴스) ✅
    └── 정기 백업 (cron)

Frontend:
└── Vue.js: 1개 (단일 인스턴스) ✅
    └── Nginx 캐싱

Monitoring:
├── Grafana: 1개 (시각화) ✅
├── Prometheus: 1개 (메트릭 수집) ✅
├── Loki: 1개 (로그 저장) ✅
└── Promtail: 1개 (로그 수집) ✅
```

### 리소스 사용량 예상

| 구성 | RAM | CPU | 디스크 |
|------|-----|-----|--------|
| Backend 2개 | +500MB | +1 코어 | - |
| MySQL 1개 | 500MB | 0.5 코어 | 10GB |
| Frontend 1개 | 200MB | 0.2 코어 | 1GB |
| Monitoring 스택 | 1GB | 1 코어 | 10GB |
| **총계** | **약 3GB** | **약 3 코어** | **약 21GB** |

### Master/Slave 구성 시

| 구성 | RAM | CPU | 디스크 |
|------|-----|-----|--------|
| MySQL Master/Slave | +500MB | +0.5 코어 | +10GB |
| **총계** | **약 2.5GB** | **약 2.5 코어** | **약 21GB** |

---

## 🔧 Docker Compose 구성 예시

### Backend 2개 구성

```yaml
services:
  # Spring Boot - 2개 인스턴스
  backend-springboot:
    build:
      context: ./backend/springboot
      dockerfile: Dockerfile.dev
    deploy:
      replicas: 2
    environment:
      SPRING_PROFILES_ACTIVE: ${SPRING_PROFILES_ACTIVE:-dev}
      SPRING_DATASOURCE_URL: jdbc:mysql://mysql:3306/${MYSQL_DATABASE}
    networks:
      - nas-network
    # 포트는 내부 네트워크만 사용

  # Kotlin - 2개 인스턴스
  backend-kotlin:
    build:
      context: ./backend/kotlin
      dockerfile: Dockerfile.dev
    deploy:
      replicas: 2
    environment:
      DATABASE_URL: jdbc:mysql://mysql:3306/${MYSQL_DATABASE}
    networks:
      - nas-network

  # Nginx - 로드 밸런서
  nginx:
    image: nginx:stable-alpine
    container_name: nas-nginx
    restart: unless-stopped
    ports:
      - "3000:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
    networks:
      - nas-network
    depends_on:
      - backend-springboot
      - backend-kotlin
      - frontend-vue
```

### Nginx 로드 밸런싱 설정

```nginx
# nginx/nginx.conf
upstream springboot_backend {
    least_conn;
    server backend-springboot:8080;
    server backend-springboot:8080;
}

upstream kotlin_backend {
    least_conn;
    server backend-kotlin:8081;
    server backend-kotlin:8081;
}

server {
    listen 80;
    
    location /api/springboot/ {
        proxy_pass http://springboot_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /api/kotlin/ {
        proxy_pass http://kotlin_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location / {
        proxy_pass http://frontend-vue:3000;
    }
}
```

---

## 📊 비교표

### Backend 2개 구성

| 항목 | 1개 | 2개 |
|------|-----|-----|
| 롤링 배포 | ❌ | ✅ |
| 고가용성 | ❌ | ✅ |
| 리소스 사용 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| 복잡도 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **권장** | ❌ | ✅ |

### MySQL Master/Slave

| 항목 | 단일 | Master/Slave |
|------|------|--------------|
| 읽기 성능 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 고가용성 | ⭐⭐ | ⭐⭐⭐ (제한적) |
| 리소스 사용 | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| 복잡도 | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| **권장** | ✅ | ⚠️ (단일 서버) |

### Frontend 2개 구성

| 항목 | 1개 | 2개 |
|------|-----|-----|
| 고가용성 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 롤링 배포 | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| 리소스 사용 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| 복잡도 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **권장** | ✅ (소규모) | ⚠️ (대규모) |

---

## 🎯 최종 추천

### 단일 서버 환경 기준

1. **Backend 2개**: ✅ **강력 추천**
   - 롤링 배포 필수
   - 고가용성 제공
   - 리소스 사용량 적절

2. **MySQL 단일**: ✅ **강력 추천**
   - Master/Slave는 단일 서버에서 의미 제한적
   - 정기 백업으로 충분
   - 리소스 절약

3. **Frontend 단일**: ✅ **권장**
   - Frontend는 가벼움
   - Nginx 캐싱으로 성능 향상
   - 필요 시 2개로 확장 가능

### 확장 계획

**단기 (현재)**:
- Backend 2개
- MySQL 단일
- Frontend 단일

**중기 (트래픽 증가 시)**:
- Frontend 2개 추가
- Nginx 로드 밸런서 추가

**장기 (대규모 확장 시)**:
- 별도 서버로 MySQL Master/Slave
- 별도 서버로 Frontend
- Kubernetes 클러스터

---

## 📝 구현 가이드

### 1. Backend 2개 구성

```yaml
# docker-compose.yml 수정
services:
  backend-springboot:
    deploy:
      replicas: 2
    # 포트는 내부 네트워크만 사용
    # ports 제거
```

### 2. Nginx 로드 밸런서 추가

```yaml
nginx:
  image: nginx:stable-alpine
  container_name: nas-nginx
  restart: unless-stopped
  ports:
    - "3000:80"
  volumes:
    - ./nginx/nginx.conf:/etc/nginx/nginx.conf
  networks:
    - nas-network
  depends_on:
    - backend-springboot
    - backend-kotlin
    - frontend-vue
```

### 3. 롤링 배포 전략

```yaml
# .github/workflows/ci-cd.yml
deploy:
  steps:
    - name: Deploy to server
      script: |
        # 1. 새 인스턴스 1개 시작
        docker-compose up -d --scale backend-springboot=2 --no-deps backend-springboot
      
      # 2. 헬스 체크
      sleep 10
      curl -f http://localhost:3000/api/springboot/health
      
      # 3. 기존 인스턴스 1개 제거
      docker-compose up -d --scale backend-springboot=2
```

---

**작성일**: 2024년
**대상 환경**: Oracle Cloud Infrastructure 단일 인스턴스
**권장**: Backend 2개, MySQL 단일, Frontend 단일

