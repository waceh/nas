# GitLab + GitLab Runner 설치 및 설정 가이드

## 📋 개요

Oracle Cloud 인스턴스에 GitLab과 GitLab Runner를 설치하고, Docker Compose를 통한 자동 배포를 구성합니다.

## 🚀 설치 단계

### 1단계: GitLab 및 Runner 시작

```bash
# GitLab 및 Runner 시작
docker-compose up -d gitlab gitlab-runner

# GitLab 초기화 대기 (약 5-10분 소요)
docker-compose logs -f gitlab
# "gitlab Reconfigured!" 메시지가 나올 때까지 대기
```

### 2단계: GitLab 초기 설정

1. **GitLab 접속**
   - URL: `http://YOUR_SERVER_IP:8080`
   - 초기 비밀번호 확인:
   ```bash
   docker exec -it nas-gitlab grep 'Password:' /etc/gitlab/initial_root_password
   ```

2. **관리자 로그인**
   - 사용자명: `root`
   - 비밀번호: 위에서 확인한 값

3. **비밀번호 변경** (필수)
   - Settings → Password

### 3단계: GitLab Runner 등록

1. **등록 토큰 확인**
   ```bash
   docker exec -it nas-gitlab gitlab-rails runner "puts Gitlab::CurrentSettings.current_application_settings.runners_registration_token"
   ```

2. **Runner 등록** (호스트 Docker Engine 직접 접근)
   ```bash
   docker exec -it nas-gitlab-runner gitlab-runner register \
     --url http://gitlab:80 \
     --registration-token YOUR_TOKEN \
     --executor docker \
     --docker-image docker:latest \
     --docker-privileged=true \
     --docker-volumes /var/run/docker.sock:/var/run/docker.sock \
     --docker-network-mode host \
     --description "Docker Runner for NAS" \
     --tag-list "docker,production" \
     --run-untagged=true \
     --locked=false
   ```
   
   **설명**:
   - `--docker-privileged=true`: 호스트 Docker 소켓 접근을 위한 권한
   - `--docker-network-mode host`: 호스트 네트워크 사용 (포트 접근)
   - `--docker-volumes /var/run/docker.sock:/var/run/docker.sock`: 호스트 Docker 소켓 마운트

3. **Runner 상태 확인**
   ```bash
   docker exec -it nas-gitlab-runner gitlab-runner list
   ```

### 4단계: 프로젝트 생성 및 소스 코드 푸시

1. **프로젝트 생성**
   - GitLab에서 새 프로젝트 생성
   - 프로젝트 이름: `nas`
   - Visibility: Private (또는 Internal)

2. **로컬 저장소 설정**
   ```bash
   # 기존 저장소에 GitLab 원격 추가
   git remote add gitlab http://YOUR_SERVER_IP:8080/root/nas.git
   
   # 또는 새로 클론
   git clone http://YOUR_SERVER_IP:8080/root/nas.git
   ```

3. **소스 코드 푸시**
   ```bash
   git add .
   git commit -m "feat: GitLab CI/CD 구성"
   git push -u gitlab main
   ```

4. **.gitlab-ci.yml 확인**
   - 프로젝트 루트에 `.gitlab-ci.yml` 파일이 있는지 확인
   - GitLab → CI/CD → Pipelines에서 자동으로 인식됨

### 5단계: CI/CD 변수 설정 (선택사항)

GitLab 프로젝트 → Settings → CI/CD → Variables에서 환경 변수 추가:

- `MYSQL_ROOT_PASSWORD`: MySQL root 비밀번호 (보안상 권장하지 않음)
- `MYSQL_DATABASE`: 데이터베이스 이름
- `MYSQL_USER`: 데이터베이스 사용자
- `MYSQL_PASSWORD`: 데이터베이스 비밀번호

**참고**: `.env` 파일을 사용하는 것이 더 안전합니다.

### 6단계: 배포 테스트

1. **코드 푸시**
   ```bash
   git add .
   git commit -m "test: 배포 테스트"
   git push gitlab main
   ```

2. **파이프라인 확인**
   - GitLab → CI/CD → Pipelines
   - 빌드 및 테스트 단계 자동 실행

3. **수동 배포**
   - Pipelines에서 `deploy-production` 작업 클릭
   - "Play" 버튼 클릭하여 배포 실행

## 🔧 문제 해결

### GitLab 접속 불가
- 포트 8080이 Security Group에서 열려있는지 확인
- GitLab 컨테이너 로그 확인: `docker-compose logs gitlab`
- GitLab 초기화 완료 대기 (5-10분)

### Runner 등록 실패
- GitLab과 Runner가 같은 네트워크에 있는지 확인
- Runner 로그 확인: `docker-compose logs gitlab-runner`
- GitLab URL이 올바른지 확인 (`http://gitlab:80`)

### 배포 실패
- Runner 로그 확인: `docker-compose logs gitlab-runner`
- Docker Compose 로그 확인: `docker-compose logs`
- `.env` 파일이 올바르게 설정되었는지 확인
- 포트 충돌 확인: `docker-compose ps`

### 이미지 빌드 실패
- Dockerfile이 올바른지 확인
- 빌드 컨텍스트 확인
- Runner의 Docker 소켓 마운트 확인

## 📊 전체 아키텍처

```
GitLab (8080) → GitLab Runner → Docker Compose → NAS Services
     ↓
  소스 코드 저장
     ↓
  CI/CD 파이프라인 실행
     ↓
  Docker 이미지 빌드
     ↓
  Docker Compose 배포
```

## 🔐 보안 고려사항

1. **GitLab 초기 비밀번호 변경** (필수)
2. **HTTPS 설정** (선택사항, Let's Encrypt)
3. **방화벽 규칙**: 특정 IP만 접근 허용
4. **Runner 토큰 보호**: 등록 후 토큰 삭제 권장
5. **.env 파일 보호**: Git에 커밋하지 않음

## 💰 리소스 사용량

### GitLab
- **RAM**: 약 4GB (최소 2GB)
- **CPU**: 2 코어
- **디스크**: 약 10GB (데이터 포함)

### GitLab Runner
- **RAM**: 약 500MB
- **CPU**: 1 코어
- **디스크**: 최소

### 전체 시스템
- **최소**: 6GB RAM, 4 CPU 코어
- **권장**: 8GB RAM, 4 CPU 코어

## 📚 참고 자료

- [GitLab 공식 문서](https://docs.gitlab.com/)
- [GitLab Runner 문서](https://docs.gitlab.com/runner/)
- [GitLab CI/CD 문서](https://docs.gitlab.com/ee/ci/)
- [Docker Compose 문서](https://docs.docker.com/compose/)

---

**작성일**: 2024년
**대상 환경**: Oracle Cloud Infrastructure
**GitLab 버전**: GitLab CE Latest
**Runner 버전**: GitLab Runner Latest

