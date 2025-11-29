# GitLab 내부 설치 및 CI/CD 구성 계획

## 📋 개요

Oracle Cloud 인스턴스에 GitLab을 설치하고 GitLab CI/CD를 사용하는 방안입니다.

## 🤔 GitHub Actions vs 내부 GitLab 비교

### 내부 GitLab의 장점

1. **완전한 제어권**
   - 모든 데이터가 내부에 저장됨
   - 외부 서비스 의존성 없음
   - 커스터마이징 자유도 높음

2. **비용 효율성**
   - GitHub Actions 무료 플랜 제한 없음
   - 대용량 빌드/배포 가능
   - 자체 인프라 활용

3. **보안**
   - 코드가 외부로 나가지 않음
   - 민감한 정보 관리 용이
   - 네트워크 격리 가능

4. **통합 관리**
   - 코드 저장소와 CI/CD가 같은 곳에
   - 단일 관리 포인트
   - 모니터링 및 로그 통합

5. **무제한 실행 시간**
   - GitHub Actions는 무료 플랜에서 제한 있음
   - 긴 빌드/테스트 시간 가능

### 내부 GitLab의 단점

1. **리소스 사용**
   - Oracle Cloud 인스턴스 리소스 소비
   - NAS 서비스와 리소스 공유
   - 메모리 및 CPU 사용량 증가

2. **유지보수 부담**
   - GitLab 업데이트 및 패치 관리
   - 백업 및 복구 책임
   - 보안 업데이트 관리

3. **초기 설정 복잡도**
   - GitLab 설치 및 구성 필요
   - CI/CD 파이프라인 설정
   - Runner 설정 및 관리

4. **고가용성**
   - 단일 인스턴스 의존
   - 인스턴스 장애 시 전체 영향
   - 백업 전략 필요

## 💡 추천 방안

### 시나리오 1: 소규모 프로젝트 (현재 상황)
**추천: GitHub Actions 유지**
- 간단하고 빠른 설정
- 유지보수 부담 없음
- Oracle Cloud 인스턴스 리소스를 NAS 서비스에 집중

### 시나리오 2: 대규모 프로젝트 또는 엔터프라이즈
**추천: 내부 GitLab**
- 완전한 제어 필요
- 보안 요구사항 높음
- 대용량 빌드/배포 필요

### 시나리오 3: 하이브리드 접근
**추천: GitLab + GitHub Actions 병행**
- GitLab: 코드 저장소 및 이슈 관리
- GitHub Actions: CI/CD 파이프라인
- 각각의 장점 활용

## 🏗️ GitLab 설치 구성 방안

### 옵션 1: Docker Compose로 GitLab 추가

```yaml
# docker-compose.gitlab.yml
version: '3.8'

services:
  gitlab:
    image: gitlab/gitlab-ce:latest
    container_name: nas-gitlab
    restart: unless-stopped
    hostname: 'gitlab.YOUR_DOMAIN'
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://YOUR_SERVER_IP'
        gitlab_rails['gitlab_shell_ssh_port'] = 2222
    ports:
      - "80:80"
      - "443:443"
      - "2222:22"
    volumes:
      - gitlab_config:/etc/gitlab
      - gitlab_logs:/var/log/gitlab
      - gitlab_data:/var/opt/gitlab
    networks:
      - nas-network

volumes:
  gitlab_config:
  gitlab_logs:
  gitlab_data:

networks:
  nas-network:
    external: true
```

### 옵션 2: 별도 인스턴스 (권장)
- GitLab 전용 인스턴스 생성
- NAS 서비스와 리소스 분리
- 더 나은 성능 및 안정성

### 옵션 3: GitLab Runner만 설치
- GitLab은 외부 서비스 사용 (GitLab.com)
- Runner만 Oracle Cloud에 설치
- 하이브리드 구성

## 📝 GitLab CI/CD 구성

### .gitlab-ci.yml 예시

```yaml
stages:
  - build
  - test
  - deploy

variables:
  DOCKER_DRIVER: overlay2
  DOCKER_TLS_CERTDIR: "/certs"

# Backend: Spring Boot 빌드
build-springboot:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - cd backend/springboot
    - docker build -f Dockerfile -t nas-backend-springboot:$CI_COMMIT_SHA .
  only:
    - main
    - develop

# Backend: Kotlin 빌드
build-kotlin:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - cd backend/kotlin
    - docker build -f Dockerfile -t nas-backend-kotlin:$CI_COMMIT_SHA .
  only:
    - main
    - develop

# Frontend: Vue.js 빌드
build-vue:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - cd frontend/vue
    - docker build -f Dockerfile -t nas-frontend-vue:$CI_COMMIT_SHA .
  only:
    - main
    - develop

# 통합 테스트
test-integration:
  stage: test
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker-compose up -d
    - sleep 30
    - curl -f http://localhost:3000/api/springboot/health || exit 1
    - curl -f http://localhost:3000/api/kotlin/health || exit 1
    - docker-compose down
  only:
    - main
    - develop

# 배포 (프로덕션)
deploy-production:
  stage: deploy
  image: alpine:latest
  before_script:
    - apk add --no-cache openssh-client
    - eval $(ssh-agent -s)
    - echo "$SSH_PRIVATE_KEY" | tr -d '\r' | ssh-add -
    - mkdir -p ~/.ssh
    - chmod 700 ~/.ssh
    - ssh-keyscan $SERVER_HOST >> ~/.ssh/known_hosts
  script:
    - ssh $SERVER_USER@$SERVER_HOST "cd $SERVER_DEPLOY_PATH && git pull && ./ci-cd/deploy.sh production"
  only:
    - main
  when: manual
  environment:
    name: production
    url: http://$SERVER_HOST:3000
```

## 🔧 GitLab 설치 단계

### 1. Docker Compose에 GitLab 추가

```bash
# docker-compose.yml에 GitLab 서비스 추가
# 또는 별도 docker-compose.gitlab.yml 생성
```

### 2. GitLab Runner 설치

```bash
# GitLab Runner Docker 이미지 사용
docker run -d --name gitlab-runner --restart always \
  -v /srv/gitlab-runner/config:/etc/gitlab-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitlab/gitlab-runner:latest
```

### 3. Runner 등록

```bash
docker exec -it gitlab-runner gitlab-runner register
```

### 4. .gitlab-ci.yml 파일 생성

위의 예시 파일을 프로젝트 루트에 추가

## ⚠️ 주의사항

1. **리소스 관리**
   - GitLab은 최소 4GB RAM 권장
   - NAS 서비스와 리소스 경쟁 가능
   - 모니터링 필요

2. **포트 충돌**
   - GitLab 기본 포트: 80, 443, 22
   - NAS 프론트엔드 포트: 3000
   - 포트 충돌 확인 필요

3. **백업 전략**
   - GitLab 데이터 정기 백업
   - 설정 파일 백업
   - 복구 계획 수립

4. **보안**
   - GitLab 초기 비밀번호 변경
   - SSL/TLS 인증서 설정
   - 방화벽 규칙 설정

## 💰 비용 비교

### GitHub Actions
- 무료: 월 2,000분 (약 33시간)
- Pro: $4/월 (3,000분)
- 추가 시간: $0.008/분

### 내부 GitLab
- 인프라 비용: Oracle Cloud 인스턴스 비용만
- 유지보수 시간: 직접 관리

## 🎯 최종 추천

**현재 상황에서는 GitHub Actions를 유지하는 것을 추천합니다.**

이유:
1. 간단하고 빠른 설정
2. 유지보수 부담 없음
3. Oracle Cloud 인스턴스 리소스를 NAS 서비스에 집중
4. 충분한 무료 플랜 제공

**내부 GitLab을 고려해야 하는 경우:**
1. 프로젝트가 대규모로 확장될 때
2. 보안 요구사항이 매우 높을 때
3. 완전한 제어가 필요할 때
4. 별도의 GitLab 전용 인스턴스를 생성할 수 있을 때

## 📚 참고 자료

- [GitLab 설치 가이드](https://docs.gitlab.com/ee/install/docker.html)
- [GitLab Runner 설치](https://docs.gitlab.com/runner/install/docker.html)
- [GitLab CI/CD 문서](https://docs.gitlab.com/ee/ci/)

---

**작성일**: 2024년
**대상 환경**: Oracle Cloud Infrastructure


