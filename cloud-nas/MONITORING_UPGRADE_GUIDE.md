# 모니터링 업그레이드 가이드

## 📋 개요

현재 시스템은 **Netdata**를 사용하여 경량 모니터링을 제공합니다. 더 많은 로그 분석이나 장기 데이터 저장이 필요한 경우 **Grafana + Prometheus + Loki** 스택으로 업그레이드할 수 있습니다.

## 🎯 현재 구성: Netdata

### Netdata 특징
- ✅ 매우 경량 (200-400MB RAM)
- ✅ 실시간 모니터링
- ✅ 자동 설정 (설정 파일 최소화)
- ✅ Docker 컨테이너 자동 감지
- ✅ 아름다운 UI
- ✅ 알림 기능

### Netdata 제한사항
- ⚠️ 장기 데이터 저장 제한적
- ⚠️ 상세 로그 분석 기능 제한적
- ⚠️ 커스텀 대시보드 제한적

---

## 🔄 업그레이드: Grafana + Prometheus + Loki

### 언제 업그레이드해야 하나?

다음과 같은 경우 Grafana + Prometheus + Loki로 업그레이드를 고려하세요:

1. **장기 데이터 저장 필요**
   - 몇 주/몇 달간의 메트릭 데이터 보관
   - 트렌드 분석 필요

2. **상세 로그 분석 필요**
   - 애플리케이션 로그 검색 및 분석
   - 로그 기반 문제 해결

3. **커스텀 대시보드 필요**
   - 특정 비즈니스 메트릭 시각화
   - 복잡한 쿼리 및 분석

4. **알림 규칙 세밀화 필요**
   - 복잡한 알림 조건
   - 여러 데이터 소스 기반 알림

---

## 📊 리소스 비교

| 항목 | Netdata | Grafana + Prometheus + Loki |
|------|---------|----------------------------|
| **RAM** | 200-400MB | 550-1000MB |
| **CPU** | 0.3-0.5 코어 | 0.8-1.1 코어 |
| **디스크** | 1-2GB | 10-20GB |
| **설정 복잡도** | ⭐ (매우 간단) | ⭐⭐⭐ (복잡) |
| **실시간 모니터링** | ✅ 우수 | ✅ 우수 |
| **장기 데이터 저장** | ❌ 제한적 | ✅ 우수 |
| **로그 분석** | ⚠️ 기본 | ✅ 강력 |

---

## 🚀 업그레이드 방법

### 1단계: docker-compose.yml 수정

#### Netdata 제거 (선택사항)
```yaml
# Netdata 서비스 주석 처리 또는 제거
# netdata:
#   ...
```

#### Grafana + Prometheus + Loki 추가

`docker-compose.yml`에 다음 서비스를 추가:

```yaml
  # Prometheus - 메트릭 수집
  prometheus:
    image: prom/prometheus:latest
    container_name: nas-prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.enable-lifecycle'
    networks:
      - nas-network

  # Grafana - 시각화
  grafana:
    image: grafana/grafana:latest
    container_name: nas-grafana
    restart: unless-stopped
    ports:
      - "3030:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana/datasources:/etc/grafana/provisioning/datasources
      - ./monitoring/grafana/dashboards:/etc/grafana/provisioning/dashboards
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD:-admin}
    networks:
      - nas-network
    depends_on:
      - prometheus
      - loki

  # Loki - 로그 수집
  loki:
    image: grafana/loki:latest
    container_name: nas-loki
    restart: unless-stopped
    ports:
      - "3100:3100"
    volumes:
      - ./monitoring/loki/loki-config.yml:/etc/loki/local-config.yaml
      - loki_data:/loki
    command: -config.file=/etc/loki/local-config.yaml
    networks:
      - nas-network

  # Promtail - 로그 수집 에이전트
  promtail:
    image: grafana/promtail:latest
    container_name: nas-promtail
    restart: unless-stopped
    volumes:
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - ./monitoring/promtail/promtail-config.yml:/etc/promtail/config.yml
    command: -config.file=/etc/promtail/config.yml
    networks:
      - nas-network
    depends_on:
      - loki
```

#### 볼륨 추가
```yaml
volumes:
  # ... 기존 볼륨들 ...
  prometheus_data:
  grafana_data:
  loki_data:
```

### 2단계: 설정 파일 생성

#### Prometheus 설정 (`monitoring/prometheus/prometheus.yml`)
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'springboot'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['backend-springboot:8080']
  
  - job_name: 'kotlin'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['backend-kotlin:8081']
  
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
```

#### Loki 설정 (`monitoring/loki/loki-config.yml`)
```yaml
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h
```

#### Promtail 설정 (`monitoring/promtail/promtail-config.yml`)
```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: docker
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          __path__: /var/lib/docker/containers/*/*log
```

#### Grafana 데이터소스 설정 (`monitoring/grafana/datasources/prometheus.yml`)
```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
  
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
```

### 3단계: 디렉토리 생성

```bash
mkdir -p monitoring/prometheus
mkdir -p monitoring/loki
mkdir -p monitoring/promtail
mkdir -p monitoring/grafana/datasources
mkdir -p monitoring/grafana/dashboards
```

### 4단계: 서비스 시작

```bash
# Netdata 중지 (선택사항)
docker-compose stop netdata

# Grafana + Prometheus + Loki 시작
docker-compose up -d prometheus loki promtail grafana
```

### 5단계: 접속 확인

- **Grafana**: `http://YOUR_SERVER_IP:3030` (기본: admin/admin)
- **Prometheus**: `http://YOUR_SERVER_IP:9090`
- **Loki**: `http://YOUR_SERVER_IP:3100`

---

## 🔄 하이브리드 구성 (권장)

Netdata와 Grafana + Prometheus를 동시에 사용할 수 있습니다:

### 구성
- **Netdata**: 실시간 모니터링 (경량)
- **Grafana + Prometheus + Loki**: 상세 분석 및 장기 저장

### 장점
- ✅ 평상시: Netdata로 경량 모니터링
- ✅ 문제 발생 시: Grafana로 상세 분석
- ✅ 리소스 효율적 (필요 시만 Grafana 사용)

### 리소스 사용량
- **Netdata만**: 200-400MB RAM
- **Netdata + Grafana 스택**: 750-1400MB RAM

---

## 📝 백엔드 설정 (Prometheus 메트릭 수집)

### Spring Boot 설정

`build.gradle`에 추가:
```gradle
dependencies {
    implementation 'io.micrometer:micrometer-registry-prometheus'
}
```

`application.yml`:
```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus,metrics
  metrics:
    export:
      prometheus:
        enabled: true
```

### Kotlin Backend 설정

`build.gradle.kts`에 추가:
```kotlin
dependencies {
    implementation("io.micrometer:micrometer-registry-prometheus")
}
```

---

## ⚠️ 주의사항

### 리소스 사용량 증가
- RAM: +350-600MB (Netdata 대비)
- CPU: +0.5-0.6 코어
- 디스크: +9-18GB

### 현재 시스템 (OCPU 4, RAM 24GB, 디스크 47GB)
- **RAM**: 충분 ✅
- **CPU**: 충분 ✅
- **디스크**: 주의 필요 ⚠️ (47GB → 56-65GB 사용)

---

## 🎯 권장사항

### 단계적 도입
1. **1단계**: Netdata로 시작 (현재)
2. **2단계**: 필요 시 Grafana + Prometheus 추가
3. **3단계**: 로그 분석 필요 시 Loki 추가

### 언제 Netdata만 사용?
- ✅ 실시간 모니터링만 필요
- ✅ 리소스 절약 중요
- ✅ 간단한 설정 선호

### 언제 Grafana + Prometheus로 업그레이드?
- ✅ 장기 데이터 저장 필요
- ✅ 상세 로그 분석 필요
- ✅ 커스텀 대시보드 필요
- ✅ 복잡한 알림 규칙 필요

---

**작성일**: 2026-01-26
**현재 구성**: Netdata (경량 모니터링)
**업그레이드 옵션**: Grafana + Prometheus + Loki (상세 분석)
