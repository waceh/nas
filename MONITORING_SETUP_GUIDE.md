# Grafana + Prometheus + Loki 설치 및 통합 가이드

## 📋 개요

Spring Boot, Kotlin, Frontend 서버의 로그 및 메트릭을 수집하고 모니터링하기 위한 Grafana + Prometheus + Loki 스택 설치 가이드입니다.

## 🚀 설치 단계

### 1단계: Docker Compose에 모니터링 스택 추가

`docker-compose.yml`에 다음 서비스를 추가합니다:

```yaml
  # Prometheus - 메트릭 수집
  prometheus:
    image: prom/prometheus:latest
    container_name: nas-prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus:/etc/prometheus
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
    networks:
      - nas-network

  # Grafana - 시각화
  grafana:
    image: grafana/grafana:latest
    container_name: nas-grafana
    restart: unless-stopped
    ports:
      - "3030:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-admin}
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
      - GF_SERVER_ROOT_URL=http://YOUR_SERVER_IP:3030
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana/dashboards:/etc/grafana/provisioning/dashboards
      - ./monitoring/grafana/datasources:/etc/grafana/provisioning/datasources
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
      - ./monitoring/loki:/etc/loki
      - loki_data:/loki
    command: -config.file=/etc/loki/loki-config.yml
    networks:
      - nas-network

  # Promtail - 로그 수집 에이전트
  promtail:
    image: grafana/promtail:latest
    container_name: nas-promtail
    restart: unless-stopped
    volumes:
      - ./monitoring/promtail:/etc/promtail
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
    command: -config.file=/etc/promtail/promtail-config.yml
    networks:
      - nas-network
    depends_on:
      - loki
```

### 2단계: 설정 파일 생성

#### Prometheus 설정 (`monitoring/prometheus/prometheus.yml`)

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  # Spring Boot 메트릭
  - job_name: 'springboot'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['backend-springboot:8080']
        labels:
          service: 'springboot-api'

  # Kotlin 메트릭
  - job_name: 'kotlin'
    metrics_path: '/metrics'
    static_configs:
      - targets: ['backend-kotlin:8081']
        labels:
          service: 'kotlin-api'

  # Prometheus 자체 메트릭
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
    - from: 2024-01-01
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://localhost:9093
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
  # Docker 컨테이너 로그
  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        regex: '/(.*)'
        target_label: 'container'
      - source_labels: ['__meta_docker_container_log_stream']
        target_label: 'stream'
      - source_labels: ['__meta_docker_container_label_com_docker_compose_service']
        target_label: 'service'

  # Spring Boot 로그
  - job_name: springboot
    static_configs:
      - targets:
          - localhost
        labels:
          job: springboot
          service: springboot-api
          __path__: /var/log/springboot/*.log

  # Kotlin 로그
  - job_name: kotlin
    static_configs:
      - targets:
          - localhost
        labels:
          job: kotlin
          service: kotlin-api
          __path__: /var/log/kotlin/*.log

  # Frontend 로그
  - job_name: frontend
    static_configs:
      - targets:
          - localhost
        labels:
          job: frontend
          service: frontend-vue
          __path__: /var/log/frontend/*.log
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
    editable: true

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: true
```

### 3단계: 디렉토리 구조 생성

```bash
mkdir -p monitoring/prometheus
mkdir -p monitoring/loki
mkdir -p monitoring/promtail
mkdir -p monitoring/grafana/dashboards
mkdir -p monitoring/grafana/datasources
```

### 4단계: 서비스 시작

```bash
docker-compose up -d prometheus loki promtail grafana
```

## 🔧 Spring Boot 통합

### 1. build.gradle.kts에 의존성 추가

```kotlin
dependencies {
    // Micrometer Prometheus
    implementation("io.micrometer:micrometer-registry-prometheus")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
}
```

### 2. application.yml 설정

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
  endpoint:
    prometheus:
      enabled: true
```

### 3. 로그 설정 (logback-spring.xml)

```xml
<configuration>
    <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>/var/log/springboot/application.log</file>
        <rollingPolicy class="ch.qos.logback.core.rolling.TimeBasedRollingPolicy">
            <fileNamePattern>/var/log/springboot/application.%d{yyyy-MM-dd}.log</fileNamePattern>
            <maxHistory>30</maxHistory>
        </rollingPolicy>
        <encoder>
            <pattern>%d{yyyy-MM-dd HH:mm:ss} [%thread] %-5level %logger{36} - %msg%n</pattern>
        </encoder>
    </appender>

    <root level="INFO">
        <appender-ref ref="FILE" />
    </root>
</configuration>
```

## 🔧 Kotlin (Ktor) 통합

### 1. build.gradle.kts에 의존성 추가

```kotlin
dependencies {
    // Micrometer Prometheus
    implementation("io.micrometer:micrometer-registry-prometheus")
    implementation("io.micrometer:micrometer-core")
}
```

### 2. 메트릭 엔드포인트 설정

```kotlin
import io.micrometer.prometheus.PrometheusConfig
import io.micrometer.prometheus.PrometheusMeterRegistry
import io.ktor.server.application.*
import io.ktor.server.response.*
import io.ktor.server.routing.*

fun Application.configureMetrics() {
    val prometheusRegistry = PrometheusMeterRegistry(PrometheusConfig.DEFAULT)
    
    routing {
        get("/metrics") {
            call.respond(prometheusRegistry.scrape())
        }
    }
}
```

### 3. 로그 설정

```kotlin
import org.slf4j.LoggerFactory
import java.io.File

fun configureLogging() {
    val logFile = File("/var/log/kotlin/application.log")
    // 로그 설정
}
```

## 🔧 Frontend (Vue.js) 통합

### 1. 로그 수집 라이브러리

```javascript
// utils/logger.js
export const logger = {
  error: (message, error) => {
    console.error(message, error)
    // Loki로 전송
    fetch('/api/logs', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        level: 'error',
        message,
        error: error?.message,
        timestamp: new Date().toISOString()
      })
    })
  },
  
  info: (message) => {
    console.info(message)
    fetch('/api/logs', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        level: 'info',
        message,
        timestamp: new Date().toISOString()
      })
    })
  }
}
```

### 2. 에러 핸들러

```javascript
// main.js
import { logger } from './utils/logger'

Vue.config.errorHandler = (err, vm, info) => {
  logger.error('Vue Error', {
    error: err.message,
    component: vm.$options.name,
    info
  })
}

window.addEventListener('error', (event) => {
  logger.error('Global Error', {
    message: event.message,
    filename: event.filename,
    lineno: event.lineno
  })
})
```

## 📊 Grafana 대시보드 설정

### 1. 기본 대시보드 생성

Grafana에서 다음 대시보드를 생성:

#### Spring Boot 메트릭 대시보드
- HTTP 요청 수
- 응답 시간
- 에러율
- JVM 메모리 사용량
- CPU 사용량

#### 로그 대시보드
- 로그 레벨별 분포
- 에러 로그 추적
- 서비스별 로그

### 2. 대시보드 JSON 예시

`monitoring/grafana/dashboards/springboot.json`:

```json
{
  "dashboard": {
    "title": "Spring Boot Metrics",
    "panels": [
      {
        "title": "HTTP Requests",
        "targets": [
          {
            "expr": "rate(http_server_requests_seconds_count[5m])",
            "legendFormat": "{{method}} {{uri}}"
          }
        ]
      }
    ]
  }
}
```

## 🔔 알림 설정

### Grafana Alerting 설정

1. Grafana → Alerting → Notification channels
2. 이메일 또는 Slack 채널 추가
3. Alert 규칙 생성:

```yaml
# 예시: 에러율이 5% 초과 시 알림
- alert: HighErrorRate
  expr: rate(http_server_requests_seconds_count{status=~"5.."}[5m]) > 0.05
  for: 5m
  annotations:
    summary: "High error rate detected"
```

## 📈 사용 방법

### 1. Grafana 접속
- URL: `http://YOUR_SERVER_IP:3030`
- 기본 계정: `admin` / `admin` (첫 로그인 시 변경)

### 2. Prometheus 접속
- URL: `http://YOUR_SERVER_IP:9090`
- 메트릭 쿼리 및 확인

### 3. 로그 확인
- Grafana → Explore → Loki 선택
- LogQL 쿼리로 로그 검색:
  ```
  {service="springboot-api"} |= "error"
  ```

## 🔍 로그 쿼리 예시

### LogQL 쿼리

```logql
# Spring Boot 에러 로그
{service="springboot-api"} |= "ERROR"

# 특정 시간대 로그
{service="springboot-api"} [5m]

# 로그 레벨별 필터
{service="springboot-api"} | json | level="ERROR"

# 여러 서비스 로그
{service=~"springboot-api|kotlin-api"}
```

## 📊 메트릭 쿼리 예시

### PromQL 쿼리

```promql
# HTTP 요청 수
rate(http_server_requests_seconds_count[5m])

# 응답 시간
histogram_quantile(0.95, rate(http_server_requests_seconds_bucket[5m]))

# 에러율
rate(http_server_requests_seconds_count{status=~"5.."}[5m]) / 
rate(http_server_requests_seconds_count[5m])

# JVM 메모리 사용량
jvm_memory_used_bytes / jvm_memory_max_bytes
```

## 🎯 모니터링 체크리스트

### 기본 모니터링
- [ ] HTTP 요청 수
- [ ] 응답 시간
- [ ] 에러율
- [ ] 서버 리소스 (CPU, Memory, Disk)

### 애플리케이션 모니터링
- [ ] 데이터베이스 연결 풀
- [ ] 캐시 히트율
- [ ] 큐 길이
- [ ] 비즈니스 메트릭

### 로그 모니터링
- [ ] 에러 로그 추적
- [ ] 로그 레벨별 분포
- [ ] 서비스별 로그 분석

## ⚠️ 주의사항

### 1. 리소스 관리
- Prometheus 데이터 보관 기간 설정 (기본 30일)
- Loki 로그 보관 기간 설정
- 디스크 공간 모니터링

### 2. 보안
- Grafana 기본 비밀번호 변경
- 방화벽 규칙 설정
- HTTPS 설정 (프로덕션)

### 3. 성능
- 스크랩 간격 조정 (기본 15초)
- 로그 샘플링 (대용량 로그 시)

## 📚 참고 자료

- [Prometheus 공식 문서](https://prometheus.io/docs/)
- [Grafana 공식 문서](https://grafana.com/docs/)
- [Loki 공식 문서](https://grafana.com/docs/loki/)
- [Micrometer 공식 문서](https://micrometer.io/)

---

**작성일**: 2024년
**대상 환경**: Oracle Cloud Infrastructure 단일 인스턴스
**스택**: Grafana + Prometheus + Loki


