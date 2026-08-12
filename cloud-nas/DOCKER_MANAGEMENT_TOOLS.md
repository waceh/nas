# Docker 환경 관리 도구 가이드

## 📋 개요

Docker Compose 기반 환경에서 사용할 수 있는 Rancher와 유사한 관리 도구들입니다.

## 🛠️ Docker 환경 관리 도구 비교

### 1. Portainer (강력 추천) ⭐

**특징:**
- Docker 및 Docker Compose 완전 지원
- 웹 기반 UI
- 스택 관리 (Docker Compose)
- 컨테이너 모니터링
- 로그 뷰어
- 볼륨 및 네트워크 관리

**장점:**
- 설치 및 사용이 매우 쉬움
- 가볍고 빠름 (약 50MB)
- Docker Compose 스택 관리에 최적화
- 무료 오픈소스
- Kubernetes도 지원 (향후 확장 가능)

**단점:**
- Rancher만큼 강력하지는 않음
- 멀티 클러스터 관리 제한적

**리소스:**
- RAM: 약 100-200MB
- CPU: 최소

### 2. Rancher (Docker 모드)

**특징:**
- Docker Compose 지원
- 웹 기반 UI
- 앱 카탈로그
- 사용자 권한 관리

**장점:**
- 매우 강력한 기능
- 엔터프라이즈급

**단점:**
- 리소스 사용량 많음 (최소 4GB RAM)
- Kubernetes에 최적화되어 있음
- Docker Compose보다는 Kubernetes에 더 적합

### 3. Docker Swarm (네이티브)

**특징:**
- Docker 네이티브 오케스트레이션
- Docker Compose와 호환
- 클러스터링 지원

**장점:**
- Docker에 내장
- Kubernetes보다 가벼움

**단점:**
- 웹 UI가 없음 (Portainer와 함께 사용)
- Kubernetes만큼 기능이 많지 않음

### 4. Lazydocker (터미널 UI)

**특징:**
- 터미널 기반 UI
- 빠른 컨테이너 관리
- 로그 뷰어

**장점:**
- 매우 가볍음
- 빠른 접근

**단점:**
- 웹 UI 없음
- 시스템 관리자용으로는 제한적

## 💡 추천: Portainer

**이유:**
1. Docker Compose에 최적화
2. 설치 및 사용이 쉬움
3. 가볍고 빠름
4. 웹 기반 UI
5. 무료 오픈소스
6. 향후 Kubernetes 확장 가능

## 📊 Portainer 포함 전체 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│         Internet                                        │
│         (YOUR_SERVER_IP)                                │
└───────────────┬──────────────────────────────────────────┘
                │
                │ (포트: 80, 443, 3000, 9000)
                ▼
┌─────────────────────────────────────────────────────────┐
│    Oracle Cloud Security Group                          │
│    - HTTP (80)                                          │
│    - HTTPS (443)                                        │
│    - Custom (3000) - NAS Frontend                       │
│    - Custom (9000) - Portainer                          │
│    - SSH (22)                                           │
└───────────────┬──────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│         Oracle Cloud Instance                           │
│         (Ubuntu 22.04 ARM64)                            │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Management Layer                                │  │
│  │                                                  │  │
│  │  ┌────────────────────────────────────────────┐ │  │
│  │  │  Portainer                                 │ │  │
│  │  │  - Docker 관리                             │ │  │
│  │  │  - Docker Compose 스택 관리                │ │  │
│  │  │  - 컨테이너 모니터링                       │ │  │
│  │  │  - 로그 뷰어                               │ │  │
│  │  │  - 볼륨/네트워크 관리                      │ │  │
│  │  │  Port: 9000                                │ │  │
│  │  └────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────┘  │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Docker Engine                                    │  │
│  │                                                   │  │
│  │  ┌─────────────────────────────────────────────┐ │  │
│  │  │  NAS Application Stack                      │ │  │
│  │  │  (Docker Compose)                           │ │  │
│  │  │                                              │ │  │
│  │  │  ┌──────────────┐  ┌──────────────┐       │ │  │
│  │  │  │  Frontend    │  │  Ingress     │       │ │  │
│  │  │  │  (Vue.js)    │  │  (nginx)     │       │ │  │
│  │  │  │  Port: 3000  │  │              │       │ │  │
│  │  │  └──────┬───────┘  └──────┬───────┘       │ │  │
│  │  │         │                  │                │ │  │
│  │  │  ┌──────▼───────┐  ┌───────▼──────┐      │ │  │
│  │  │  │  Spring Boot │  │  Kotlin API  │      │ │  │
│  │  │  │  API         │  │  (Ktor)      │      │ │  │
│  │  │  │  Port: 8080  │  │  Port: 8081  │      │ │  │
│  │  │  └──────┬───────┘  └───────┬──────┘      │ │  │
│  │  │         │                  │                │ │  │
│  │  │         └─────────┬─────────┘                │ │  │
│  │  │                   │                          │ │  │
│  │  │         ┌─────────▼─────────┐                │ │  │
│  │  │         │  MySQL Database   │                │ │  │
│  │  │         │  Port: 3306       │                │ │  │
│  │  │         │  Volume: mysql_data│                │ │  │
│  │  │         └───────────────────┘                │ │  │
│  │  └─────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────┘  │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

## 🔧 Portainer 설치 방법

### Docker Compose에 추가

```yaml
# docker-compose.yml에 추가
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: nas-portainer
    restart: unless-stopped
    ports:
      - "9000:9000"
      - "9443:9443"  # HTTPS (선택사항)
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    networks:
      - nas-network

volumes:
  portainer_data:
```

### 또는 별도 실행

```bash
docker volume create portainer_data
docker run -d -p 9000:9000 -p 9443:9443 \
  --name portainer --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
```

## 📊 Portainer 주요 기능

### 1. 대시보드
- 컨테이너 상태 모니터링
- 리소스 사용량 확인
- 빠른 액션 (시작/중지/재시작)

### 2. 컨테이너 관리
- 컨테이너 목록 및 상태
- 로그 실시간 확인
- 컨테이너 실행/중지/삭제
- 컨테이너 설정 편집

### 3. 스택 관리 (Docker Compose)
- docker-compose.yml 업로드 및 관리
- 스택 배포 및 업데이트
- 스택 상태 모니터링
- 환경 변수 관리

### 4. 이미지 관리
- 이미지 목록
- 이미지 빌드
- 이미지 삭제

### 5. 볼륨 관리
- 볼륨 목록 및 사용량
- 볼륨 생성/삭제
- 볼륨 백업

### 6. 네트워크 관리
- 네트워크 목록
- 네트워크 생성/삭제
- 네트워크 연결 관리

### 7. 사용자 관리
- 사용자 생성 및 권한 관리
- 팀 관리
- RBAC (Role-Based Access Control)

## 🎛️ 추가 관리 도구 (선택사항)

### 1. Watchtower (자동 업데이트)
- 컨테이너 이미지 자동 업데이트
- 무중단 업데이트

### 2. Traefik (리버스 프록시)
- 자동 SSL 인증서
- 라우팅 관리
- 로드 밸런싱

### 3. Netdata (모니터링)
- **현재 구성**: Netdata로 경량 모니터링
- **업그레이드 옵션**: 필요 시 Grafana + Prometheus + Loki로 업그레이드 가능
- 자세한 내용: [MONITORING_UPGRADE_GUIDE.md](MONITORING_UPGRADE_GUIDE.md)
- 메트릭 수집
- 대시보드 시각화
- 알림 설정

## 📝 Docker Compose 통합 예시

```yaml
version: '3.8'

services:
  # Portainer - Docker 관리 도구
  portainer:
    image: portainer/portainer-ce:latest
    container_name: nas-portainer
    restart: unless-stopped
    ports:
      - "9000:9000"
      - "9443:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    networks:
      - nas-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portainer.rule=Host(`portainer.local`)"

  # 기존 NAS 서비스들...
  mysql:
    # ... 기존 설정

  backend-springboot:
    # ... 기존 설정

  backend-kotlin:
    # ... 기존 설정

  frontend-vue:
    # ... 기존 설정

volumes:
  portainer_data:
  mysql_data:
  springboot_data:
  kotlin_data:

networks:
  nas-network:
    driver: bridge
```

## 🔐 보안 설정

### Portainer 접근 제어

1. **초기 설정**
   - 첫 접속 시 관리자 계정 생성
   - 강력한 비밀번호 사용

2. **HTTPS 설정**
   - 포트 9443 사용
   - SSL 인증서 설정

3. **방화벽 규칙**
   - 특정 IP만 접근 허용
   - VPN 사용 권장

## 💰 리소스 사용량

### Portainer
- **RAM**: 약 100-200MB
- **CPU**: 최소
- **디스크**: 약 50MB

### 전체 시스템
- **기존 Docker Compose**: 그대로 유지
- **추가 리소스**: Portainer만 추가 (약 200MB)

## 🚀 사용 방법

### 1. Portainer 접속
```
http://YOUR_SERVER_IP:9000
```

### 2. 초기 설정
- 관리자 계정 생성
- 로컬 Docker 환경 선택

### 3. 스택 관리
- "Stacks" 메뉴에서 docker-compose.yml 업로드
- 또는 기존 스택 모니터링

### 4. 컨테이너 관리
- "Containers" 메뉴에서 모든 컨테이너 확인
- 로그, 상태, 리소스 모니터링

## 📚 참고 자료

- [Portainer 공식 문서](https://docs.portainer.io/)
- [Portainer GitHub](https://github.com/portainer/portainer)
- [Docker Compose 문서](https://docs.docker.com/compose/)

---

**작성일**: 2024년
**대상 환경**: Docker Compose
**관리 도구**: Portainer


