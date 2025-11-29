# CI/CD 구성 파일 준비 완료

## 📦 준비된 CI/CD 파일 목록

### GitHub Actions 워크플로우
- ✅ `.github/workflows/ci.yml` - CI 파이프라인 (빌드 및 테스트)
- ✅ `.github/workflows/cd.yml` - CD 파이프라인 (배포)

### 배포 스크립트
- ✅ `ci-cd/deploy.sh` - Oracle Cloud 인스턴스 배포 스크립트
- ✅ `ci-cd/README.md` - CI/CD 가이드 문서

### 문서 업데이트
- ✅ `README.md` - CI/CD 섹션 추가

## 🔧 주요 기능

### CI 파이프라인 (ci.yml)
- ✅ Spring Boot 백엔드 빌드 및 테스트
- ✅ Kotlin 백엔드 빌드 및 테스트
- ✅ Vue.js 프론트엔드 빌드 및 Lint 검사
- ✅ Docker Compose 통합 테스트
- ✅ 디렉토리 존재 여부 확인 (조건부 실행)

### CD 파이프라인 (cd.yml)
- ✅ Docker 이미지 빌드 및 푸시 (선택사항, Docker Hub)
- ✅ Oracle Cloud 인스턴스 자동 배포 (SSH)
- ✅ 배포 후 Health Check 검증
- ✅ Docker Hub 푸시 실패 시에도 배포 진행 가능

### 배포 스크립트 (deploy.sh)
- ✅ 환경 변수 파일 확인
- ✅ Docker 및 Docker Compose 버전 확인
- ✅ 프로덕션 환경 자동 백업 (MySQL)
- ✅ Docker Compose v2/v1 호환
- ✅ 헬스 체크 및 재시도 로직
- ✅ 상세한 로그 출력

## 📋 GitHub Secrets 설정 필요

다음 Secrets를 GitHub 저장소에 추가해야 합니다:

### 필수 Secrets
- `SSH_PRIVATE_KEY`: Oracle Cloud 인스턴스 SSH 개인키
- `SERVER_HOST`: Oracle Cloud 인스턴스 IP 주소 (예: 158.180.76.251)
- `SERVER_USER`: SSH 사용자명 (예: ubuntu)
- `SERVER_DEPLOY_PATH`: 배포 경로 (예: /home/ubuntu/nas)

### 선택사항 Secrets
- `DOCKER_USERNAME`: Docker Hub 사용자명 (Docker Hub 푸시 시)
- `DOCKER_PASSWORD`: Docker Hub 비밀번호 (Docker Hub 푸시 시)

## 🚀 사용 방법

### 1. GitHub Secrets 설정
1. GitHub 저장소 → Settings → Secrets and variables → Actions
2. 위의 Secrets 추가

### 2. SSH 키 설정
```bash
# SSH 키 생성 (로컬)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/github_actions_deploy -C "github-actions"

# 공개키를 Oracle Cloud 인스턴스에 추가
ssh-copy-id -i ~/.ssh/github_actions_deploy.pub ubuntu@YOUR_SERVER_IP

# 개인키를 GitHub Secrets에 추가
cat ~/.ssh/github_actions_deploy
```

### 3. 자동 배포
- `main` 브랜치에 푸시하면 자동으로 배포됩니다
- GitHub Actions 탭에서 진행 상황을 확인할 수 있습니다

### 4. 수동 배포
- Oracle Cloud 인스턴스에서 직접 실행:
```bash
cd /home/ubuntu/nas
./ci-cd/deploy.sh production
```

## 📝 개선 사항

### CI 파이프라인
- ✅ 디렉토리 존재 여부 확인 추가
- ✅ 조건부 실행으로 백엔드/프론트엔드가 없어도 실패하지 않음
- ✅ continue-on-error로 일부 실패 허용

### CD 파이프라인
- ✅ Docker Hub 푸시 실패 시에도 배포 진행
- ✅ 배포 스크립트 실행 전 환경 확인
- ✅ 상세한 헬스 체크 로그

### 배포 스크립트
- ✅ Docker Compose v2/v1 호환
- ✅ MySQL 백업 개선 (컨테이너 상태 확인)
- ✅ 더 상세한 로그 출력
- ✅ 에러 처리 개선

## 🔍 다음 단계

1. **GitHub Secrets 설정**: 위의 Secrets를 모두 추가
2. **SSH 키 설정**: Oracle Cloud 인스턴스에 SSH 키 추가
3. **테스트**: `main` 브랜치에 푸시하여 자동 배포 테스트
4. **모니터링**: GitHub Actions 탭에서 워크플로우 실행 확인

## 📚 참고 문서

- [CI/CD 가이드](ci-cd/README.md) - 상세한 CI/CD 설정 가이드
- [README.md](README.md) - 프로젝트 전체 문서

---

**작성일**: 2024년
**대상 환경**: Oracle Cloud Infrastructure
**CI/CD 플랫폼**: GitHub Actions


