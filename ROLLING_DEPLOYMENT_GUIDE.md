# 롤링 배포 가이드

## 📋 개요

GitHub Actions를 사용하여 Spring Boot와 Kotlin Backend를 무중단 롤링 배포하는 방법입니다.

## 🎯 현재 상태

- **Spring Boot**: 1개 인스턴스 실행 중
- **Kotlin**: 1개 인스턴스 실행 중
- **목표**: 각각 2개 인스턴스로 스케일링하여 롤링 배포 구현

## 🔄 롤링 배포 방식

### 1. 수동 스케일링 (테스트용)

```bash
# Spring Boot 2개로 스케일링
docker compose -f docker-compose.yml -f docker-compose.scale.yml up -d --scale backend-springboot=2

# Kotlin 2개로 스케일링
docker compose -f docker-compose.yml -f docker-compose.scale.yml up -d --scale backend-kotlin=2

# 상태 확인
docker compose ps | grep backend
```

### 2. GitHub Actions를 통한 자동 롤링 배포

#### 배포 프로세스

1. **태그 생성**
   ```bash
   git tag -a v1.0.0 -m "Release v1.0.0"
   git push origin v1.0.0
   ```

2. **GitHub Actions 파이프라인 실행**
   - GitHub → Actions에서 태그 생성 시 자동 실행
   - 또는 수동으로 `deploy` 작업 실행

3. **롤링 배포 단계**
   ```
   Spring Boot:
   1. 새 이미지 빌드
   2. 새 인스턴스 1개 추가 (총 2개)
   3. 헬스 체크
   4. 기존 인스턴스 교체
   
   Kotlin:
   1. 새 이미지 빌드
   2. 새 인스턴스 1개 추가 (총 2개)
   3. 헬스 체크
   4. 기존 인스턴스 교체
   ```

## 📝 설정 파일

### docker-compose.scale.yml

```yaml
services:
  backend-springboot:
    deploy:
      replicas: 2  # Docker Swarm 모드용 (현재는 사용 안 함)
    
  backend-kotlin:
    deploy:
      replicas: 2  # Docker Swarm 모드용 (현재는 사용 안 함)
```

**참고**: `deploy.replicas`는 Docker Swarm 모드에서만 작동합니다. 일반 Docker Compose에서는 `--scale` 옵션을 사용합니다.

### GitHub Actions 워크플로우

롤링 배포 스크립트가 `.github/workflows/ci-cd.yml`에 포함되어 있습니다:
- 새 인스턴스 추가
- 헬스 체크
- 기존 인스턴스 교체

## 🚀 사용 방법

### 방법 1: GitHub Actions 자동 배포 (권장)

1. **코드 커밋 및 푸시**
   ```bash
   git add .
   git commit -m "feat: 새로운 기능 추가"
   git push origin main
   ```

2. **태그 생성 및 푸시**
   ```bash
   git tag -a v1.0.1 -m "Release v1.0.1"
   git push origin v1.0.1
   ```

3. **GitHub Actions에서 파이프라인 확인**
   - GitHub → Actions
   - `deploy` 작업 상태 확인

### 방법 2: 수동 스케일링

```bash
# 서버에 SSH 접속
ssh -i ssh-key-2024-05-24.key ubuntu@158.180.76.251

# 프로젝트 디렉토리로 이동
cd ~/nas-oracle-cloud

# Spring Boot 2개로 스케일링
docker compose -f docker-compose.yml -f docker-compose.scale.yml up -d --scale backend-springboot=2

# Kotlin 2개로 스케일링
docker compose -f docker-compose.yml -f docker-compose.scale.yml up -d --scale backend-kotlin=2

# 상태 확인
docker compose ps | grep backend
```

## 🔍 확인 방법

### 컨테이너 수 확인

```bash
# 실행 중인 Backend 컨테이너 확인
docker compose ps | grep -E 'backend-springboot|backend-kotlin'

# 또는 Portainer에서 확인
# http://158.180.76.251:9000 → Containers
```

### 로드 밸런싱 확인

```bash
# 여러 번 요청하여 다른 인스턴스로 분산되는지 확인
for i in {1..10}; do
  curl http://localhost:3000/api/health
  echo ""
done
```

## ⚠️ 주의사항

1. **리소스 사용량**
   - 2개 인스턴스는 메모리와 CPU를 2배 사용합니다
   - 서버 리소스를 확인하세요

2. **세션 관리**
   - Stateless 아키이션 권장
   - 세션 공유가 필요한 경우 Redis 사용

3. **데이터베이스 연결**
   - 각 인스턴스가 MySQL에 연결
   - Connection Pool 설정 확인

## 🛠️ 문제 해결

### 인스턴스가 1개만 실행되는 경우

```bash
# 강제로 2개 실행
docker compose -f docker-compose.yml -f docker-compose.scale.yml up -d --scale backend-springboot=2 --force-recreate backend-springboot
```

### 롤링 배포 실패 시

```bash
# 로그 확인
docker compose logs backend-springboot --tail=50
docker compose logs backend-kotlin --tail=50

# 수동으로 롤백
docker compose -f docker-compose.yml -f docker-compose.scale.yml up -d --scale backend-springboot=1
```

## 📊 롤링 배포 흐름도

```
[현재 상태]
Spring Boot: 1개
Kotlin: 1개

[배포 시작]
↓
[Spring Boot 롤링 배포]
1. 새 이미지 빌드
2. 새 인스턴스 추가 → Spring Boot: 2개
3. 헬스 체크
4. 기존 인스턴스 교체 → Spring Boot: 2개 (새 버전)
↓
[Kotlin 롤링 배포]
1. 새 이미지 빌드
2. 새 인스턴스 추가 → Kotlin: 2개
3. 헬스 체크
4. 기존 인스턴스 교체 → Kotlin: 2개 (새 버전)
↓
[배포 완료]
Spring Boot: 2개 (새 버전)
Kotlin: 2개 (새 버전)
```

## ✅ 체크리스트

- [ ] docker-compose.scale.yml 파일 확인
- [ ] .github/workflows/ci-cd.yml 롤링 배포 스크립트 확인
- [ ] GitHub Actions Secrets 설정 (SERVER_HOST, SERVER_USER, SSH_PRIVATE_KEY)
- [ ] 서버 리소스 확인 (메모리, CPU)
- [ ] 헬스 체크 엔드포인트 확인 (`/api/health`, `/api/kotlin/health`)
- [ ] Nginx 로드 밸런싱 설정 확인

