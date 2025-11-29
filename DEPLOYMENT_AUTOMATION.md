# GitLab Issues 기반 배포 자동화

## 📋 개요

GitLab Issues에 태그를 입력하면 자동으로 배포가 트리거되는 시스템을 구성합니다.

## 🎯 배포 시나리오

### 시나리오 1: 태그 기반 배포 (권장) ⭐⭐⭐⭐⭐

```
1. BE 프로젝트 소스 커밋
   ↓
2. Git 태그 생성 (예: v1.0.0)
   ↓
3. GitLab CI/CD 자동 트리거
   ↓
4. 새 인스턴스 배포
   ↓
5. 헬스 체크 확인
   ↓
6. 기존 인스턴스 종료
```

### 시나리오 2: Issue 댓글 기반 배포

```
1. BE 프로젝트 소스 커밋 및 태그 생성
   ↓
2. GitLab Issue에 태그 정보 댓글 작성
   ↓
3. GitLab CI/CD 수동 트리거 또는 API 호출
   ↓
4. 새 인스턴스 배포
   ↓
5. 기존 인스턴스 종료
```

## 🔧 구현 방법

### 방법 1: Git 태그 기반 자동 배포 (가장 권장)

#### .gitlab-ci.yml 설정

```yaml
stages:
  - build
  - test
  - deploy

variables:
  DOCKER_DRIVER: overlay2
  DOCKER_TLS_CERTDIR: "/certs"

# Backend 빌드
build-backend:
  stage: build
  image: docker:latest
  before_script:
    - docker info
  script:
    - |
      # Spring Boot 빌드
      if [ -d "backend/springboot" ]; then
        cd backend/springboot
        docker build -f Dockerfile -t nas-backend-springboot:$CI_COMMIT_TAG .
        docker tag nas-backend-springboot:$CI_COMMIT_TAG nas-backend-springboot:latest
      fi
      
      # Kotlin 빌드
      if [ -d "backend/kotlin" ]; then
        cd backend/kotlin
        docker build -f Dockerfile -t nas-backend-kotlin:$CI_COMMIT_TAG .
        docker tag nas-backend-kotlin:$CI_COMMIT_TAG nas-backend-kotlin:latest
      fi
  only:
    - tags  # 태그가 생성될 때만 실행

# 배포 (태그 기반)
deploy-production:
  stage: deploy
  image: docker:latest
  before_script:
    - apk add --no-cache docker-compose curl
    - docker info
  variables:
    DOCKER_HOST: "unix:///var/run/docker.sock"
  script:
    - |
      echo "=========================================="
      echo "배포 시작: $(date)"
      echo "태그: $CI_COMMIT_TAG"
      echo "=========================================="
      
      # 환경 변수 파일 확인
      if [ ! -f .env ]; then
        echo "경고: .env 파일이 없습니다."
        if [ -f env.example ]; then
          cp env.example .env
        else
          echo "오류: env.example 파일도 없습니다."
          exit 1
        fi
      fi
      
      # 기존 컨테이너 백업 및 중지
      echo "기존 서비스 백업 및 중지 중..."
      docker-compose ps
      
      # 새 인스턴스 배포 (태그 버전)
      echo "새 인스턴스 배포 중 (태그: $CI_COMMIT_TAG)..."
      docker-compose -f docker-compose.yml -f docker-compose.prod.yml build --no-cache
      docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
      
      # 헬스 체크
      echo "헬스 체크 대기 중..."
      sleep 20
      
      MAX_RETRIES=10
      RETRY_COUNT=0
      
      while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if curl -f http://localhost:3000/api/springboot/health && \
           curl -f http://localhost:3000/api/kotlin/health; then
          echo "=========================================="
          echo "배포 완료: $(date)"
          echo "태그: $CI_COMMIT_TAG"
          echo "모든 서비스가 정상적으로 시작되었습니다!"
          echo "=========================================="
          
          # 기존 인스턴스 정리 (옵션)
          # docker-compose down --remove-orphans
          
          exit 0
        fi
        
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "재시도 중... ($RETRY_COUNT/$MAX_RETRIES)"
        sleep 5
      done
      
      echo "경고: 배포 실패"
      docker-compose ps
      docker-compose logs --tail=50
      exit 1
  only:
    - tags  # 태그가 생성될 때만 실행
  when: manual  # 수동 실행 또는 자동 실행 선택 가능
  environment:
    name: production
    url: http://localhost:3000
```

#### 사용 방법

```bash
# 1. 코드 커밋
git add .
git commit -m "feat: 새로운 기능 추가"

# 2. 태그 생성 및 푸시
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# 3. GitLab CI/CD가 자동으로 트리거됨
# 4. Pipelines에서 deploy-production 작업 실행
```

---

### 방법 2: Issue 댓글 기반 배포 (고급)

#### GitLab API를 사용한 배포 트리거

```yaml
# .gitlab-ci.yml에 추가
deploy-from-issue:
  stage: deploy
  image: curlimages/curl:latest
  script:
    - |
      # Issue에서 태그 정보 추출 (예: /deploy v1.0.0)
      # GitLab API를 통해 Issue 댓글 확인
      # 태그가 있으면 배포 실행
      echo "Issue 기반 배포는 별도 스크립트 필요"
  only:
    - main
  when: manual
```

#### 배포 스크립트 (deploy-from-issue.sh)

```bash
#!/bin/bash

# GitLab Issue에서 배포 태그 추출 및 배포 실행
# 사용법: ./deploy-from-issue.sh <ISSUE_ID>

ISSUE_ID=$1
GITLAB_URL="http://YOUR_SERVER_IP:8080"
GITLAB_TOKEN="YOUR_GITLAB_TOKEN"

# Issue 댓글에서 태그 추출
TAG=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_URL/api/v4/projects/1/issues/$ISSUE_ID/notes" | \
  jq -r '.[] | select(.body | contains("/deploy")) | .body' | \
  grep -oP 'v\d+\.\d+\.\d+')

if [ -z "$TAG" ]; then
  echo "배포 태그를 찾을 수 없습니다."
  exit 1
fi

echo "배포 태그: $TAG"

# GitLab CI/CD 파이프라인 트리거
curl -X POST \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_URL/api/v4/projects/1/trigger/pipeline" \
  -d "ref=main" \
  -d "variables[DEPLOY_TAG]=$TAG"
```

---

### 방법 3: Blue-Green 배포 (무중단 배포)

#### 개선된 배포 스크립트

```yaml
deploy-blue-green:
  stage: deploy
  image: docker:latest
  before_script:
    - apk add --no-cache docker-compose curl
    - docker info
  variables:
    DOCKER_HOST: "unix:///var/run/docker.sock"
  script:
    - |
      TAG=$CI_COMMIT_TAG
      BLUE_PORT=3000
      GREEN_PORT=3001
      
      # 현재 실행 중인 인스턴스 확인
      CURRENT_PORT=$(docker-compose ps | grep frontend | grep -oP '0.0.0.0:\K\d+' || echo "$BLUE_PORT")
      
      if [ "$CURRENT_PORT" = "$BLUE_PORT" ]; then
        NEW_PORT=$GREEN_PORT
        OLD_PORT=$BLUE_PORT
      else
        NEW_PORT=$BLUE_PORT
        OLD_PORT=$GREEN_PORT
      fi
      
      echo "현재 인스턴스: $OLD_PORT"
      echo "새 인스턴스: $NEW_PORT"
      
      # 새 인스턴스 배포
      echo "새 인스턴스 배포 중 (포트: $NEW_PORT)..."
      docker-compose -f docker-compose.yml \
        -f docker-compose.prod.yml \
        up -d \
        --scale frontend-vue=1 \
        -e VUE_PORT=$NEW_PORT
      
      # 헬스 체크
      sleep 20
      if curl -f http://localhost:$NEW_PORT/api/springboot/health; then
        echo "새 인스턴스 정상 작동 확인"
        
        # 기존 인스턴스 종료
        echo "기존 인스턴스 종료 중..."
        docker-compose stop frontend-vue
        docker-compose rm -f frontend-vue
        
        # 새 인스턴스를 기본 포트로 변경
        docker-compose -f docker-compose.yml \
          -f docker-compose.prod.yml \
          up -d \
          -e VUE_PORT=$BLUE_PORT
      else
        echo "새 인스턴스 배포 실패 - 롤백"
        exit 1
      fi
  only:
    - tags
  when: manual
```

---

## 📝 Issue와 배포 연동

### Issue 템플릿 예시

```markdown
## 배포 정보
- **태그**: v1.0.0
- **배포 일시**: 2024-01-15
- **배포자**: @username

## 배포 체크리스트
- [ ] 코드 리뷰 완료
- [ ] 테스트 통과
- [ ] 태그 생성 완료
- [ ] 배포 파이프라인 실행
- [ ] 헬스 체크 확인
```

### Issue 댓글으로 배포 트리거

Issue에 다음과 같이 댓글 작성:
```
/deploy v1.0.0
```

또는:
```
배포 태그: v1.0.0
```

---

## 🔄 전체 워크플로우

### 1. 개발 → 배포 프로세스

```
1. 개발자 코드 작성
   ↓
2. GitLab에 커밋 및 푸시
   ↓
3. Merge Request 생성
   ↓
4. 코드 리뷰 및 승인
   ↓
5. Merge to main
   ↓
6. Git 태그 생성 (v1.0.0)
   ↓
7. GitLab CI/CD 자동 트리거
   ↓
8. 새 인스턴스 배포
   ↓
9. 헬스 체크 확인
   ↓
10. 기존 인스턴스 종료
    ↓
11. Issue에 배포 완료 댓글
```

### 2. Issue 기반 배포 프로세스

```
1. Issue 생성 (배포 요청)
   ↓
2. 개발자 코드 커밋 및 태그 생성
   ↓
3. Issue에 태그 정보 댓글 작성
   ↓
4. 배포 파이프라인 수동 실행
   ↓
5. 새 인스턴스 배포
   ↓
6. 기존 인스턴스 종료
   ↓
7. Issue에 배포 완료 댓글
```

---

## 🎯 권장 구성

### 단일 서버 환경 (현재 구조)

**방법 1: 태그 기반 자동 배포** (강력 추천)
- Git 태그 생성 시 자동 배포
- 간단하고 명확함
- Issue에 태그 정보만 기록

**사용 예시**:
```bash
# 1. 코드 커밋
git commit -m "feat: 새로운 기능"

# 2. 태그 생성
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# 3. GitLab에서 파이프라인 확인 및 배포 실행
```

### Issue 연동

Issue에는 배포 정보만 기록:
```
배포 태그: v1.0.0
배포 일시: 2024-01-15
배포 상태: ✅ 완료
```

---

## 📊 배포 상태 추적

### Issue에 배포 상태 업데이트

배포 스크립트에서 GitLab API를 사용하여 Issue 업데이트:

```bash
# 배포 완료 시 Issue 댓글 추가
curl -X POST \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_URL/api/v4/projects/1/issues/$ISSUE_ID/notes" \
  -d "body=✅ 배포 완료: 태그 $TAG가 성공적으로 배포되었습니다."
```

---

## ⚠️ 주의사항

### 1. 롤백 전략
- 배포 실패 시 자동 롤백
- 이전 버전 태그로 재배포 가능

### 2. 데이터베이스 마이그레이션
- 배포 전 데이터베이스 백업
- 마이그레이션 스크립트 실행

### 3. 무중단 배포
- Blue-Green 배포 방식 고려
- 헬스 체크 후 트래픽 전환

---

## 🚀 빠른 시작

### 1단계: .gitlab-ci.yml 수정
위의 태그 기반 배포 설정 추가

### 2단계: 태그 생성 및 배포
```bash
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

### 3단계: GitLab에서 배포 실행
- Pipelines → 해당 파이프라인 선택
- deploy-production 작업 실행

### 4단계: Issue에 배포 정보 기록
```
배포 태그: v1.0.0
배포 상태: ✅ 완료
```

---

**작성일**: 2024년
**대상 환경**: Oracle Cloud Infrastructure 단일 인스턴스
**권장 방법**: 태그 기반 자동 배포


