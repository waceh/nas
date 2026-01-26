# 로그 수집 및 모니터링 도구 추천

## 📋 개요

Spring Boot, Kotlin, Frontend 서버의 로그 수집 및 모니터링을 위한 도구를 추천합니다. 와탭(APM)이나 데이터독과 유사한 기능을 제공하는 오픈소스 솔루션을 중심으로 정리했습니다.

## 🎯 현재 구성: Netdata

현재 시스템은 **Netdata**를 사용하여 경량 모니터링을 제공합니다. 더 많은 로그 분석이 필요한 경우 아래 옵션들을 고려하세요.

### Netdata 특징
- ✅ 매우 경량 (200-400MB RAM)
- ✅ 실시간 모니터링
- ✅ 자동 설정
- ✅ Docker 컨테이너 자동 감지

> **업그레이드 가이드**: [MONITORING_UPGRADE_GUIDE.md](MONITORING_UPGRADE_GUIDE.md) 참조

## 🎯 업그레이드 옵션

### 1순위: Grafana + Prometheus + Loki (상세 분석용) ⭐⭐⭐⭐⭐

#### 구성
- **Prometheus**: 메트릭 수집 및 저장
- **Grafana**: 시각화 및 대시보드
- **Loki**: 로그 수집 및 저장
- **Promtail**: 로그 수집 에이전트

#### 특징
- **가벼움**: 약 1-2GB RAM (전체 스택)
- **통합 관리**: 메트릭과 로그를 한 곳에서 관리
- **강력한 시각화**: Grafana의 풍부한 대시보드
- **APM 기능**: 분산 추적 지원 (Jaeger 연동 가능)

#### 리소스
- **RAM**: 약 1-2GB
- **CPU**: 2 코어
- **디스크**: 약 10-20GB (로그 보관 기간에 따라)

#### Docker Compose 설정
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
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
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

---

### 2순위: ELK Stack (Elasticsearch, Logstash, Kibana) ⭐⭐⭐⭐

#### 구성
- **Elasticsearch**: 로그 저장 및 검색
- **Logstash**: 로그 수집 및 처리
- **Kibana**: 시각화 및 대시보드
- **Beats** (선택): 경량 로그 수집 에이전트

#### 특징
- **강력한 검색**: Elasticsearch의 강력한 검색 기능
- **로그 분석**: 복잡한 로그 분석 가능
- **APM**: Elastic APM 통합 가능
- **리소스**: 높음 (약 4-6GB RAM)

#### 리소스
- **RAM**: 약 4-6GB
- **CPU**: 4 코어
- **디스크**: 약 20-50GB

#### Docker Compose 설정
```yaml
  # Elasticsearch
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: nas-elasticsearch
    restart: unless-stopped
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
    ports:
      - "9200:9200"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    networks:
      - nas-network

  # Logstash
  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
    container_name: nas-logstash
    restart: unless-stopped
    volumes:
      - ./monitoring/logstash:/usr/share/logstash/pipeline
    ports:
      - "5044:5044"
    networks:
      - nas-network
    depends_on:
      - elasticsearch

  # Kibana
  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    container_name: nas-kibana
    restart: unless-stopped
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    networks:
      - nas-network
    depends_on:
      - elasticsearch
```

---

### 3순위: Graylog ⭐⭐⭐⭐

#### 구성
- **Graylog Server**: 로그 수집 및 처리
- **MongoDB**: 메타데이터 저장
- **Elasticsearch**: 로그 저장 (옵션)

#### 특징
- **로그 중심**: 로그 관리에 특화
- **검색 기능**: 강력한 로그 검색
- **알림**: 이메일, Slack 등 알림 지원
- **중간 리소스**: 약 2-3GB RAM

#### 리소스
- **RAM**: 약 2-3GB
- **CPU**: 2 코어
- **디스크**: 약 10-20GB

#### Docker Compose 설정
```yaml
  # MongoDB
  mongodb:
    image: mongo:latest
    container_name: nas-mongodb
    restart: unless-stopped
    volumes:
      - mongodb_data:/data/db
    networks:
      - nas-network

  # Elasticsearch (Graylog용)
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: nas-elasticsearch
    restart: unless-stopped
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    networks:
      - nas-network

  # Graylog
  graylog:
    image: graylog/graylog:latest
    container_name: nas-graylog
    restart: unless-stopped
    ports:
      - "9000:9000"
      - "12201:12201/udp"  # GELF UDP
      - "1514:1514"        # Syslog
    environment:
      - GRAYLOG_HTTP_EXTERNAL_URI=http://YOUR_SERVER_IP:9000/
      - GRAYLOG_ROOT_PASSWORD_SHA2=8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918
    volumes:
      - graylog_data:/usr/share/graylog/data
    networks:
      - nas-network
    depends_on:
      - mongodb
      - elasticsearch
```

---

### 4순위: Jaeger (분산 추적) + Grafana ⭐⭐⭐⭐

#### 구성
- **Jaeger**: 분산 추적 (APM)
- **Grafana**: 시각화
- **Prometheus**: 메트릭 수집

#### 특징
- **APM 특화**: 분산 추적에 최적화
- **마이크로서비스**: 여러 서비스 간 추적
- **성능 분석**: 요청 흐름 추적
- **가벼움**: 약 500MB RAM

#### 리소스
- **RAM**: 약 500MB
- **CPU**: 1 코어
- **디스크**: 약 5GB

---

### 5순위: OpenTelemetry + Grafana ⭐⭐⭐

#### 구성
- **OpenTelemetry Collector**: 관찰 가능성 데이터 수집
- **Grafana**: 시각화
- **Prometheus**: 메트릭 저장

#### 특징
- **표준**: OpenTelemetry 표준 사용
- **통합**: 메트릭, 로그, 트레이스 통합
- **유연성**: 다양한 백엔드 지원
- **복잡도**: 설정이 복잡할 수 있음

---

## 📊 비교표

| 도구 | 리소스 | 난이도 | 로그 | 메트릭 | APM | 검색 |
|------|--------|--------|------|--------|-----|------|
| Grafana + Prometheus + Loki | ⭐⭐⭐⭐ | ⭐⭐⭐ | ✅ | ✅ | ⚠️ | ⭐⭐⭐ |
| ELK Stack | ⭐⭐ | ⭐⭐⭐⭐ | ✅ | ⚠️ | ✅ | ⭐⭐⭐⭐⭐ |
| Graylog | ⭐⭐⭐ | ⭐⭐⭐ | ✅ | ❌ | ❌ | ⭐⭐⭐⭐ |
| Jaeger + Grafana | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ❌ | ⚠️ | ✅ | ❌ |
| OpenTelemetry | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ✅ | ✅ | ✅ | ⭐⭐⭐ |

## 💡 종합 추천

### 시나리오 1: 단일 서버, 가벼운 구성 (강력 추천) ⭐⭐⭐⭐⭐
**Grafana + Prometheus + Loki**
- 가벼움 (1-2GB RAM)
- 메트릭 + 로그 통합 관리
- 강력한 시각화
- APM 기능 (Jaeger 연동 가능)

### 시나리오 2: 강력한 로그 분석 필요
**ELK Stack**
- 강력한 검색 기능
- 복잡한 로그 분석
- 리소스 많이 사용 (4-6GB RAM)

### 시나리오 3: 로그 중심 관리
**Graylog**
- 로그 관리 특화
- 중간 리소스 (2-3GB RAM)
- 검색 기능 우수

### 시나리오 4: APM 중심
**Jaeger + Grafana + Prometheus**
- 분산 추적 특화
- 마이크로서비스 모니터링
- 가벼움

## 🎯 최종 추천

### 현재: Netdata (경량 모니터링)
- 문제 발생 시 체크용으로 충분
- 리소스 효율적
- 자동 설정

### 업그레이드: Grafana + Prometheus + Loki (상세 분석)

### 이유
1. **가벼움**: 단일 서버 환경에 적합
2. **통합 관리**: 메트릭과 로그를 한 곳에서
3. **강력한 시각화**: Grafana의 풍부한 대시보드
4. **확장성**: 필요 시 Jaeger 등 추가 가능
5. **비용**: 완전 무료 오픈소스

### 제공 기능
- ✅ 로그 수집 및 저장 (Loki)
- ✅ 메트릭 수집 및 저장 (Prometheus)
- ✅ 시각화 및 대시보드 (Grafana)
- ✅ 알림 (Grafana Alerting)
- ✅ APM (Jaeger 연동 가능)

### Spring Boot, Kotlin, Frontend 통합
- **Spring Boot**: Micrometer + Prometheus
- **Kotlin**: Micrometer + Prometheus
- **Frontend**: 로그를 Loki로 전송
- **Docker**: 컨테이너 로그 자동 수집 (Promtail)

## 📝 다음 단계

1. **Grafana + Prometheus + Loki 설치 가이드** 작성
2. **Spring Boot/Kotlin 통합** 가이드
3. **대시보드 템플릿** 제공
4. **알림 설정** 가이드

---

**작성일**: 2024년
**대상 환경**: Oracle Cloud Infrastructure 단일 인스턴스
**현재 권장**: Netdata (경량 모니터링)
**업그레이드 옵션**: Grafana + Prometheus + Loki (상세 분석 필요 시)

자세한 업그레이드 가이드: [MONITORING_UPGRADE_GUIDE.md](MONITORING_UPGRADE_GUIDE.md)


