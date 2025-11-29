# Frontend Nginx를 통한 Backend 로드 밸런싱

## 📋 개요

별도의 Nginx 컨테이너 없이 **Frontend의 Nginx**에서 Backend 로드 밸런싱을 처리합니다.

## 🎯 왜 Frontend Nginx를 사용하는가?

### 장점
- ✅ **단순함**: 별도 컨테이너 불필요
- ✅ **리소스 절약**: 추가 컨테이너 없음
- ✅ **통합 관리**: Frontend와 Backend 프록시를 한 곳에서 관리
- ✅ **Docker Compose scale 지원**: 자동 로드 밸런싱

### 구조
```
사용자 요청
    ↓
Frontend Nginx (포트 3000)
    ├── / → Frontend 정적 파일
    ├── /api/springboot/* → Backend Spring Boot (2개 인스턴스)
    └── /api/kotlin/* → Backend Kotlin (2개 인스턴스)
```

## 🔧 Frontend Nginx 설정

### Vue.js 프로젝트의 Nginx 설정

Frontend Vue.js 프로젝트의 `nginx.conf` 또는 `default.conf` 파일을 수정:

```nginx
upstream springboot_backend {
    least_conn;
    # Docker Compose scale을 사용하면 자동으로 여러 인스턴스에 분산
    server backend-springboot:8080 max_fails=3 fail_timeout=30s;
    keepalive 32;
}

upstream kotlin_backend {
    least_conn;
    server backend-kotlin:8081 max_fails=3 fail_timeout=30s;
    keepalive 32;
}

server {
    listen 3000;
    server_name _;

    # Frontend 정적 파일
    root /app/dist;
    index index.html;

    # Frontend 라우팅 (SPA)
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Spring Boot API 프록시 (로드 밸런싱)
    location /api/springboot/ {
        proxy_pass http://springboot_backend/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # 타임아웃 설정
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # 헬스 체크 및 장애 복구
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
    }

    # Kotlin API 프록시 (로드 밸런싱)
    location /api/kotlin/ {
        proxy_pass http://kotlin_backend/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # 타임아웃 설정
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # 헬스 체크 및 장애 복구
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
    }
}
```

## 🐳 Docker Compose Scale과의 통합

### Docker Compose의 내장 로드 밸런싱

Docker Compose의 `scale` 기능을 사용하면:

```bash
docker-compose up -d --scale backend-springboot=2 --scale backend-kotlin=2
```

이 경우 Docker의 내장 DNS가 자동으로 여러 인스턴스에 요청을 분산합니다.

### Nginx 설정 최적화

```nginx
upstream springboot_backend {
    least_conn;
    # Docker Compose scale을 사용하면 같은 서비스 이름으로 여러 인스턴스 접근
    # Docker의 내장 DNS가 자동으로 로드 밸런싱
    server backend-springboot:8080 max_fails=3 fail_timeout=30s;
    keepalive 32;
}
```

**주의**: Docker Compose의 내장 DNS는 Round-robin 방식이므로, `least_conn`을 사용하려면 명시적으로 여러 서버를 나열해야 합니다.

### 명시적 서버 나열 (권장)

```nginx
upstream springboot_backend {
    least_conn;
    # Docker Compose scale 사용 시 명시적으로 나열
    server backend-springboot_1:8080 max_fails=3 fail_timeout=30s;
    server backend-springboot_2:8080 max_fails=3 fail_timeout=30s;
    keepalive 32;
}
```

하지만 Docker Compose의 scale은 컨테이너 이름을 자동 생성하므로, 더 나은 방법은:

```nginx
upstream springboot_backend {
    least_conn;
    # Docker Compose의 서비스 이름 사용 (자동 로드 밸런싱)
    server backend-springboot:8080 max_fails=3 fail_timeout=30s;
    keepalive 32;
}
```

Docker의 내장 DNS가 자동으로 여러 인스턴스에 분산합니다.

## 📊 로드 밸런싱 방식

### 1. Round-robin (기본)
```nginx
upstream springboot_backend {
    server backend-springboot:8080;
    server backend-springboot:8080;
}
```

### 2. Least connections (권장)
```nginx
upstream springboot_backend {
    least_conn;
    server backend-springboot:8080;
}
```

### 3. IP Hash (세션 고정)
```nginx
upstream springboot_backend {
    ip_hash;
    server backend-springboot:8080;
}
```

## 🔄 롤링 배포 시나리오

### 시나리오 1: Docker Compose Scale 사용

```bash
# 1. 새 인스턴스 1개 추가 (총 3개)
docker-compose up -d --scale backend-springboot=3

# 2. 헬스 체크
sleep 10
curl http://localhost:3000/api/springboot/health

# 3. 기존 인스턴스 1개 제거 (총 2개)
docker-compose up -d --scale backend-springboot=2
```

### 시나리오 2: 수동 롤링 배포

```bash
# 1. 새 인스턴스 시작
docker-compose up -d backend-springboot

# 2. 헬스 체크
curl http://localhost:3000/api/springboot/health

# 3. 기존 인스턴스 중지
docker-compose stop backend-springboot_old
docker-compose rm -f backend-springboot_old
```

## ⚠️ 주의사항

### 1. Stateless 구성
- Backend는 Stateless로 구성해야 함
- 세션을 서버에 저장하지 않음
- 세션은 Redis 등 외부 저장소 사용

### 2. 헬스 체크
- Nginx의 `max_fails`와 `fail_timeout` 설정
- 장애 인스턴스 자동 제외

### 3. Docker Compose Scale 제한
- Docker Compose의 scale은 개발 환경에 적합
- 프로덕션에서는 Kubernetes 등 고급 오케스트레이션 권장

## 💡 결론

**Frontend의 Nginx로 충분합니다!**

- ✅ 별도의 Nginx 컨테이너 불필요
- ✅ Frontend Nginx 설정만 수정
- ✅ 리소스 절약
- ✅ 통합 관리 용이

---

**작성일**: 2024년
**대상 환경**: Oracle Cloud Infrastructure 단일 인스턴스
**권장**: Frontend Nginx에서 Backend 로드 밸런싱 처리

