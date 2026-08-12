# 모니터링 레이어 경량화 분석

## 📊 현재 모니터링 스택

### 현재 구성
1. **Prometheus** - 메트릭 수집 (200-400MB RAM)
2. **Grafana** - 시각화 (100-200MB RAM)
3. **Loki** - 로그 수집 (200-300MB RAM)
4. **Promtail** - 로그 에이전트 (50-100MB RAM)

### 현재 리소스 사용량
- **RAM**: 약 550-1000MB
- **CPU**: 약 0.8-1.1 코어
- **디스크**: 약 10-20GB

---

## 🎯 경량화 옵션

### 옵션 1: Grafana + Prometheus만 유지 (권장) ⭐⭐⭐⭐⭐

#### 구성
- **Prometheus**: 메트릭 수집
- **Grafana**: 시각화 UI

#### 리소스 절감
- **제거**: Loki (-200-300MB), Promtail (-50-100MB)
- **절감량**: 약 250-400MB RAM
- **최종 사용량**: 약 300-600MB RAM

#### 장점
- ✅ 기존 UI 유지 (Grafana)
- ✅ 메트릭 모니터링 유지
- ✅ 리소스 절약 (약 40% 감소)
- ✅ 설정 간단

#### 단점
- ⚠️ 로그 수집 기능 제거 (Docker 로그 직접 확인 필요)

#### 적합한 경우
- 메트릭 모니터링 중심
- 로그는 필요 시 직접 확인
- 문제 발생 시 체크용

---

### 옵션 2: Netdata (통합 솔루션) ⭐⭐⭐⭐⭐

#### 구성
- **Netdata**: 메트릭 + 로그 + 시각화 통합

#### 리소스 사용량
- **RAM**: 약 200-400MB
- **CPU**: 약 0.3-0.5 코어
- **디스크**: 약 1-2GB

#### 장점
- ✅ 매우 경량 (현재 스택의 1/3 수준)
- ✅ 실시간 모니터링
- ✅ 자동 설정 (설정 파일 최소화)
- ✅ 아름다운 UI
- ✅ 알림 기능 내장

#### 단점
- ⚠️ Grafana보다 기능 제한적
- ⚠️ 장기 데이터 저장 제한적

#### 적합한 경우
- 경량화 최우선
- 실시간 모니터링 중심
- 간단한 설정 원함

---

### 옵션 3: Uptime Kuma (간단한 모니터링) ⭐⭐⭐⭐

#### 구성
- **Uptime Kuma**: 서비스 상태 모니터링

#### 리소스 사용량
- **RAM**: 약 100-200MB
- **CPU**: 약 0.1-0.2 코어
- **디스크**: 약 500MB

#### 장점
- ✅ 매우 경량
- ✅ 서비스 상태 체크 중심
- ✅ 간단한 UI
- ✅ 알림 기능

#### 단점
- ⚠️ 상세 메트릭 부족
- ⚠️ 로그 수집 없음

#### 적합한 경우
- 서비스 가동 상태만 확인
- 최소한의 모니터링
- 알림 중심

---

### 옵션 4: Grafana + Node Exporter만 (최소 구성) ⭐⭐⭐

#### 구성
- **Node Exporter**: 시스템 메트릭 수집
- **Grafana**: 시각화

#### 리소스 사용량
- **RAM**: 약 150-300MB
- **CPU**: 약 0.2-0.4 코어
- **디스크**: 약 2-5GB

#### 장점
- ✅ Grafana UI 유지
- ✅ 시스템 메트릭만 수집 (경량)
- ✅ Prometheus 없이도 가능

#### 단점
- ⚠️ 애플리케이션 메트릭 제한적

---

## 📊 비교표

| 옵션 | RAM | CPU | 디스크 | UI | 메트릭 | 로그 | 평가 |
|------|-----|-----|--------|-----|--------|------|------|
| **현재 (전체)** | 550-1000MB | 0.8-1.1 | 10-20GB | ✅ | ✅ | ✅ | ⚠️ 과함 |
| **Grafana + Prometheus** | 300-600MB | 0.5-0.7 | 5-10GB | ✅ | ✅ | ❌ | ✅ 권장 |
| **Netdata** | 200-400MB | 0.3-0.5 | 1-2GB | ✅ | ✅ | ✅ | ✅ 최경량 |
| **Uptime Kuma** | 100-200MB | 0.1-0.2 | 500MB | ✅ | ⚠️ | ❌ | ✅ 최소 |
| **Grafana + Node Exporter** | 150-300MB | 0.2-0.4 | 2-5GB | ✅ | ⚠️ | ❌ | ⚠️ 제한적 |

---

## 🎯 최종 권장사항

### 시나리오 1: 문제 발생 시 체크용 (권장) ⭐⭐⭐⭐⭐

**Netdata 사용**

#### 이유
- ✅ 매우 경량 (200-400MB RAM)
- ✅ 실시간 모니터링
- ✅ 아름다운 UI
- ✅ 자동 설정
- ✅ 알림 기능 내장

#### 리소스 절감
- **절감량**: 약 350-600MB RAM (현재 대비 60-70% 감소)
- **최종 사용량**: 200-400MB RAM

#### Docker Compose 설정 예시
```yaml
netdata:
  image: netdata/netdata:latest
  container_name: nas-netdata
  restart: unless-stopped
  hostname: nas-server
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
  environment:
    - NETDATA_CLAIM_TOKEN=YOUR_TOKEN
    - NETDATA_CLAIM_URL=https://app.netdata.cloud
    - NETDATA_CLAIM_ROOMS=YOUR_ROOM_ID
  networks:
    - nas-network
```

---

### 시나리오 2: Grafana UI 유지하면서 경량화 ⭐⭐⭐⭐

**Grafana + Prometheus만 유지**

#### 이유
- ✅ 기존 Grafana UI 유지
- ✅ 메트릭 모니터링 유지
- ✅ 리소스 절약 (약 40% 감소)

#### 리소스 절감
- **절감량**: 약 250-400MB RAM
- **최종 사용량**: 300-600MB RAM

#### 변경사항
- Loki 제거 (-200-300MB)
- Promtail 제거 (-50-100MB)
- Grafana + Prometheus만 유지

---

### 시나리오 3: 최소한의 모니터링 ⭐⭐⭐

**Uptime Kuma 사용**

#### 이유
- ✅ 매우 경량 (100-200MB RAM)
- ✅ 서비스 상태 체크 중심
- ✅ 알림 기능

#### 리소스 절감
- **절감량**: 약 450-800MB RAM (현재 대비 80% 감소)
- **최종 사용량**: 100-200MB RAM

#### 제한사항
- 상세 메트릭 부족
- 로그 수집 없음

---

## 💡 하이브리드 접근법 (추천)

### Grafana + Netdata 조합

#### 구성
- **Netdata**: 실시간 모니터링 (경량)
- **Grafana**: 필요 시 상세 분석

#### 장점
- ✅ 평상시: Netdata로 경량 모니터링
- ✅ 문제 발생 시: Grafana로 상세 분석
- ✅ 리소스 효율적

#### 리소스 사용량
- **Netdata만**: 200-400MB RAM
- **Grafana 필요 시**: +300-600MB RAM (임시)

---

## 📊 리소스 절감 효과

### 현재 → 경량화 후

| 구성 | RAM 절감 | CPU 절감 | 디스크 절감 | 평가 |
|------|---------|---------|------------|------|
| **Netdata** | 350-600MB (60-70%) | 0.5-0.6 코어 | 8-18GB | ✅ 최고 |
| **Grafana + Prometheus** | 250-400MB (40-45%) | 0.3-0.4 코어 | 5-10GB | ✅ 좋음 |
| **Uptime Kuma** | 450-800MB (80-82%) | 0.7-0.9 코어 | 9.5-19.5GB | ✅ 최소 |

---

## 🎯 최종 추천

### 문제 발생 시 체크용 + 별도 UI 필요

**1순위: Netdata** ⭐⭐⭐⭐⭐
- 매우 경량 (200-400MB RAM)
- 아름다운 실시간 UI
- 자동 설정
- 알림 기능

**2순위: Grafana + Prometheus** ⭐⭐⭐⭐
- 기존 UI 유지
- 메트릭 모니터링 유지
- 중간 수준 경량화

**3순위: Uptime Kuma** ⭐⭐⭐
- 최소 리소스
- 서비스 상태만 체크
- 알림 중심

---

**작성일**: 2026-01-26
**분석 기준**: Oracle Cloud Infrastructure (OCPU 4, RAM 24GB, 디스크 47GB)
