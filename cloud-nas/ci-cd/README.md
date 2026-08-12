# CI/CD 가이드

이 디렉토리에는 CI/CD 파이프라인 설정과 배포 스크립트가 포함되어 있습니다.

## 📋 목차

- [CI/CD 옵션](#cicd-옵션)
- [GitHub Actions](#github-actions)
- [배포 스크립트](#배포-스크립트)
- [설정 방법](#설정-방법)
- [배포 프로세스](#배포-프로세스)

## CI/CD 옵션

이 프로젝트는 GitHub Actions를 사용한 CI/CD를 지원합니다:

### 1. GitHub Actions (권장)
- **위치**: `.github/workflows/`
- **용도**: 코드 푸시 시 자동 빌드, 테스트 및 배포
- **장점**: 완전한 제어, 외부 저장소, 무료 사용량 제공

### 2. 로컬 배포 스크립트
- **위치**: `ci-cd/deploy.sh`
- **용도**: Oracle Cloud 인스턴스에서 직접 배포
- **장점**: 외부 서비스 불필요, 완전한 제어

## GitHub Actions

### CI 파이프라인 (`.github/workflows/`)

코드 푸시 시 자동으로 실행됩니다:

1. **Build Stage**
   - Spring Boot 백엔드 Docker 이미지 빌드
   - Kotlin 백엔드 Docker 이미지 빌드
   - Vue.js 프론트엔드 Docker 이미지 빌드

2. **Test Stage**
   - Backend 단위 테스트
   - Docker Compose를 사용한 통합 테스트
   - Health check 검증

3. **Deploy Stage** (수동 실행)
   - Docker Compose를 통한 프로덕션 배포
   - 헬스 체크 검증

### GitHub 설정

1. **GitHub 저장소 생성**
   - 저장소: https://github.com/waceh
   - 각 프로젝트는 별도 저장소로 관리:
     - Frontend (Vue): `waceh/nas-frontend`
     - Backend 1 (Kotlin-SpringBoot): `waceh/nas-backend-kotlin`
     - Backend 2 (Java-SpringBoot): `waceh/nas-backend-java`

2. **GitHub Actions Secrets 설정**
   - 각 저장소의 Settings → Secrets and variables → Actions에서 다음 Secrets 추가:
     - `SERVER_HOST`: Oracle Cloud 인스턴스 IP 주소
     - `SERVER_USER`: SSH 사용자 이름 (예: ubuntu)
     - `SSH_PRIVATE_KEY`: SSH 개인 키
     - `DOCKER_HOST`: Docker 호스트 (선택사항)

3. **파이프라인 확인**
   - GitHub → Actions 탭에서 실행 상태 확인

## 배포 스크립트

### 배포 스크립트 (`deploy.sh`)

Oracle Cloud 인스턴스에서 직접 배포할 수 있는 스크립트입니다.

#### 사용법

```bash
# 실행 권한 부여
chmod +x ci-cd/deploy.sh

# 프로덕션 환경 배포
./ci-cd/deploy.sh production

# 개발 환경 배포
./ci-cd/deploy.sh development
```

#### 배포 프로세스

1. 환경 변수 파일 확인 (`.env`)
2. Docker 및 Docker Compose 확인
3. 프로덕션 환경인 경우 백업 생성
4. Docker 이미지 빌드
5. 서비스 시작
6. 헬스 체크

## 설정 방법

### 1. Oracle Cloud 인스턴스 준비

```bash
# 저장소 클론
git clone https://github.com/waceh/nas.git
cd nas

# 환경 변수 파일 생성
cp env.example .env
nano .env  # 필요한 값 설정
```

### 2. GitHub Actions 워크플로우 설정

각 프로젝트 저장소에 `.github/workflows/` 디렉토리를 생성하고 워크플로우 파일을 추가합니다.

자세한 내용은 `.github/workflows/` 디렉토리의 예시 파일을 참조하세요.

## 배포 프로세스

### 자동 배포 (GitHub Actions)

1. `main` 브랜치에 코드 푸시
2. GitHub Actions가 자동으로 실행
3. Build Stage: Docker 이미지 빌드
4. Test Stage: 테스트 실행
5. Deploy Stage: Docker Compose로 배포 (수동 실행)
6. Health check 검증

### 수동 배포

```bash
# Oracle Cloud 인스턴스에서 직접 실행
cd /home/ubuntu/nas
./ci-cd/deploy.sh production
```

## 모니터링

### 로그 확인

```bash
# 모든 서비스 로그
docker-compose logs -f

# 특정 서비스 로그
docker-compose logs -f backend-springboot
docker-compose logs -f backend-kotlin
docker-compose logs -f frontend-vue
docker-compose logs -f mysql
```

### 헬스 체크

```bash
# Spring Boot API
curl http://YOUR_SERVER_IP:3000/api/springboot/health

# Kotlin API
curl http://YOUR_SERVER_IP:3000/api/kotlin/health

# 프론트엔드
curl http://YOUR_SERVER_IP:3000
```

## 문제 해결

### 배포 실패 시

1. 로그 확인: `docker-compose logs`
2. 서비스 상태 확인: `docker-compose ps`
3. GitHub Actions 로그 확인: GitHub → Actions → 해당 워크플로우

### GitHub Actions 실행 실패

- Secrets 설정 확인
- SSH 키 권한 확인
- 서버 접근 가능 여부 확인

### Docker 이미지 빌드 실패

```bash
# 캐시 없이 재빌드
docker-compose build --no-cache

# 특정 서비스만 재빌드
docker-compose build --no-cache backend-springboot
```

## 보안 고려사항

1. **환경 변수 보호**: `.env` 파일을 Git에 커밋하지 마세요
2. **Secrets 관리**: GitHub Secrets에 민감한 정보 저장
3. **프로덕션 배포**: 수동 실행으로 제어
4. **백업**: 정기적으로 데이터베이스 백업 수행

## 브랜치 전략

- **main**: 프로덕션 환경, 수동 배포
- **develop**: 개발 환경, 테스트용
- **feature/***: 기능 개발, CI만 실행
- **release/***: 릴리스 준비, 테스트 및 검증
- **hotfix/***: 긴급 수정, 빠른 배포

---

**참고**: GitHub Actions 워크플로우 예시는 `.github/workflows/` 디렉토리를 참조하세요.
