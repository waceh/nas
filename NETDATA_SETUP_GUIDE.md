# Netdata 설치 및 설정 가이드

## 📋 개요

Netdata는 실시간 모니터링을 위한 경량 모니터링 도구입니다. 문제 발생 시 체크하기에 충분한 기능을 제공하며, 리소스 사용량이 매우 낮습니다.

## 🎯 Netdata 특징

- ✅ 매우 경량 (200-400MB RAM)
- ✅ 실시간 모니터링
- ✅ 자동 설정 (설정 파일 최소화)
- ✅ Docker 컨테이너 자동 감지
- ✅ 아름다운 UI
- ✅ 알림 기능 내장

## 🚀 설치

### docker-compose.yml에 이미 포함됨

Netdata는 `docker-compose.yml`에 이미 설정되어 있습니다:

```yaml
netdata:
  image: netdata/netdata:latest
  container_name: nas-netdata
  hostname: nas-server
  restart: unless-stopped
  ports:
    - "19999:19999"
  cap_add:
    - SYS_PTRACE
    - SYS_ADMIN
  security_opt:
    - apparmor:unconfined
  volumes:
    - netdata_config:/etc/netdata
    - netdata_lib:/var/lib/netdata
    - netdata_cache:/var/cache/netdata
    - /etc/passwd:/host/etc/passwd:ro
    - /etc/group:/host/etc/group:ro
    - /proc:/host/proc:ro
    - /sys:/host/sys:ro
    - /etc/os-release:/host/etc/os-release:ro
    - /var/run/docker.sock:/var/run/docker.sock:ro
  networks:
    - nas-network
```

### 서비스 시작

```bash
# Netdata 시작
docker-compose up -d netdata

# 로그 확인
docker-compose logs -f netdata
```

### 접속

브라우저에서 다음 URL로 접속:
```
http://YOUR_SERVER_IP:19999
```

## 📊 모니터링 기능

### 자동 수집 메트릭

Netdata는 다음을 자동으로 모니터링합니다:

1. **시스템 메트릭**
   - CPU 사용률
   - 메모리 사용량
   - 디스크 I/O
   - 네트워크 트래픽
   - 프로세스 정보

2. **Docker 컨테이너 메트릭**
   - 컨테이너별 CPU, 메모리 사용량
   - 컨테이너별 네트워크 I/O
   - 컨테이너별 디스크 I/O
   - 자동 감지 및 모니터링

3. **애플리케이션 메트릭**
   - MySQL 메트릭
   - Spring Boot 메트릭 (Actuator 연동 가능)
   - 기타 애플리케이션 메트릭

## 🔔 알림 설정

### 기본 알림

Netdata는 기본적으로 다음 알림을 제공합니다:
- CPU 사용률 높음
- 메모리 부족
- 디스크 공간 부족
- 네트워크 오류

### 커스텀 알림 설정

Netdata 설정 파일에서 알림 규칙을 커스터마이징할 수 있습니다:

```bash
# Netdata 설정 디렉토리
docker exec -it nas-netdata ls /etc/netdata/health.d/
```

## 🎨 대시보드

### 기본 대시보드

Netdata는 다음 대시보드를 자동으로 제공합니다:
- 시스템 개요
- 컨테이너별 메트릭
- 네트워크 모니터링
- 디스크 I/O 모니터링

### 커스텀 대시보드

Netdata 웹 UI에서 대시보드를 커스터마이징할 수 있습니다.

## 🔧 설정 최적화

### 리소스 제한 (선택사항)

```yaml
netdata:
  # ... 기존 설정 ...
  deploy:
    resources:
      limits:
        memory: 500M
        cpus: '0.5'
      reservations:
        memory: 256M
        cpus: '0.3'
```

### 데이터 보관 기간 설정

Netdata는 기본적으로 실시간 데이터만 표시합니다. 장기 데이터 저장이 필요한 경우 Grafana + Prometheus로 업그레이드를 고려하세요.

## 📈 사용 예시

### 1. 시스템 리소스 확인
- Netdata 대시보드에서 CPU, RAM, 디스크 사용률 확인
- 실시간 그래프로 트렌드 파악

### 2. 컨테이너 모니터링
- 각 Docker 컨테이너의 리소스 사용량 확인
- 문제가 있는 컨테이너 식별

### 3. 문제 해결
- CPU/메모리 스파이크 발생 시점 확인
- 디스크 I/O 병목 지점 파악
- 네트워크 문제 진단

## ⚠️ 제한사항

### Netdata의 제한
- ⚠️ 장기 데이터 저장 제한적 (실시간 중심)
- ⚠️ 상세 로그 분석 기능 제한적
- ⚠️ 커스텀 대시보드 제한적

### 언제 업그레이드해야 하나?

다음과 같은 경우 Grafana + Prometheus + Loki로 업그레이드를 고려하세요:
- 장기 데이터 저장 필요
- 상세 로그 분석 필요
- 커스텀 대시보드 필요
- 복잡한 알림 규칙 필요

자세한 내용: [MONITORING_UPGRADE_GUIDE.md](MONITORING_UPGRADE_GUIDE.md)

## 🔄 업그레이드

더 많은 로그 분석이 필요한 경우:

1. [MONITORING_UPGRADE_GUIDE.md](MONITORING_UPGRADE_GUIDE.md) 참조
2. Grafana + Prometheus + Loki 스택 추가
3. Netdata와 함께 사용 가능 (하이브리드 구성)

---

**작성일**: 2026-01-26
**현재 구성**: Netdata (경량 모니터링)
**리소스**: 약 200-400MB RAM
