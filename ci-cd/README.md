# CI/CD 가이드

이 디렉토리에는 CI/CD 파이프라인 설정과 배포 스크립트가 포함되어 있습니다.

## 📋 목차

- [CI/CD 옵션](#cicd-옵션)
- [GitLab CI/CD](#gitlab-cicd)
- [배포 스크립트](#배포-스크립트)
- [설정 방법](#설정-방법)
- [배포 프로세스](#배포-프로세스)

## CI/CD 옵션

이 프로젝트는 GitLab과 GitLab Runner를 사용한 CI/CD를 지원합니다:

### 1. GitLab CI/CD (권장)
- **위치**: `.gitlab-ci.yml`
- **용도**: 코드 푸시 시 자동 빌드, 테스트 및 배포
- **장점**: 완전한 제어, 내부 저장소, 무제한 실행 시간

### 2. 로컬 배포 스크립트
- **위치**: `ci-cd/deploy.sh`
- **용도**: Oracle Cloud 인스턴스에서 직접 배포
- **장점**: 외부 서비스 불필요, 완전한 제어

## GitLab CI/CD

### CI 파이프라인 (`.gitlab-ci.yml`)

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

### GitLab 설정

1. **GitLab 설치 및 설정**
   - 자세한 가이드: [GITLAB_SETUP_GUIDE.md](../GITLAB_SETUP_GUIDE.md)
   - GitLab 접속: `http://YOUR_SERVER_IP:8080`

2. **GitLab Runner 등록**
   ```bash
   # 등록 토큰 확인
   docker exec -it nas-gitlab gitlab-rails runner "puts Gitlab::CurrentSettings.current_application_settings.runners_registration_token"
   
   # Runner 등록
   docker exec -it nas-gitlab-runner gitlab-runner register \
     --url http://gitlab:80 \
     --registration-token YOUR_TOKEN \
     --executor docker \
     --docker-image docker:latest \
     --docker-volumes /var/run/docker.sock:/var/run/docker.sock \
     --docker-network-mode nas-network \
     --description "Docker Runner for NAS" \
     --tag-list "docker,production" \
     --run-untagged=true \
     --locked=false
   ```

3. **파이프라인 확인**
   - GitLab → CI/CD → Pipelines에서 실행 상태 확인

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
git clone http://YOUR_SERVER_IP:8080/root/nas.git
cd nas

# 환경 변수 파일 생성
cp env.example .env
nano .env  # 필요한 값 설정
```

### 2. GitLab 및 Runner 시작

```bash
# GitLab 및 Runner 시작
docker-compose up -d gitlab gitlab-runner

# GitLab 초기화 대기 (약 5-10분)
docker-compose logs -f gitlab
```

### 3. GitLab 초기 설정

1. GitLab 접속: `http://YOUR_SERVER_IP:8080`
2. 초기 비밀번호 확인:
   ```bash
   docker exec -it nas-gitlab grep 'Password:' /etc/gitlab/initial_root_password
   ```
3. 관리자 로그인 (root / 위 비밀번호)
4. 비밀번호 변경 (필수)

### 4. GitLab Runner 등록

위의 "GitLab Runner 등록" 섹션 참조

## 배포 프로세스

### 자동 배포 (GitLab CI/CD)

1. `main` 브랜치에 코드 푸시
2. GitLab CI/CD가 자동으로 실행
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
docker-compose logs -f gitlab
docker-compose logs -f gitlab-runner
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
3. GitLab Runner 로그 확인: `docker-compose logs gitlab-runner`

### GitLab 접속 불가

- 포트 8080이 Security Group에서 열려있는지 확인
- GitLab 컨테이너 로그 확인: `docker-compose logs gitlab`
- GitLab 초기화 완료 대기 (5-10분)

### Runner 등록 실패

- GitLab과 Runner가 같은 네트워크에 있는지 확인
- Runner 로그 확인: `docker-compose logs gitlab-runner`
- GitLab URL이 올바른지 확인 (`http://gitlab:80`)

### Docker 이미지 빌드 실패

```bash
# 캐시 없이 재빌드
docker-compose build --no-cache

# 특정 서비스만 재빌드
docker-compose build --no-cache backend-springboot
```

## 보안 고려사항

1. **환경 변수 보호**: `.env` 파일을 Git에 커밋하지 마세요
2. **GitLab 초기 비밀번호 변경**: 필수
3. **프로덕션 배포**: 수동 실행으로 제어
4. **백업**: 정기적으로 데이터베이스 백업 수행

## 브랜치 전략

- **main**: 프로덕션 환경, 수동 배포
- **develop**: 개발 환경, 테스트용
- **feature/***: 기능 개발, CI만 실행
- **release/***: 릴리스 준비, 테스트 및 검증
- **hotfix/***: 긴급 수정, 빠른 배포

---

**참고**: 자세한 GitLab 설치 가이드는 [GITLAB_SETUP_GUIDE.md](../GITLAB_SETUP_GUIDE.md)를 참조하세요.
