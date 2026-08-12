# GitHub 기반 배포 자동화

## 📋 개요

GitHub에서 태그를 생성하거나 Pull Request를 머지하면 자동으로 배포가 트리거되는 시스템을 구성합니다.

## 🎯 배포 시나리오

### 시나리오 1: 태그 기반 배포 (권장) ⭐⭐⭐⭐⭐

```
1. BE 프로젝트 소스 커밋
   ↓
2. Git 태그 생성 (예: v1.0.0)
   ↓
3. GitHub Actions 자동 트리거
   ↓
4. 새 인스턴스 배포
   ↓
5. 헬스 체크 확인
   ↓
6. 기존 인스턴스 종료
```

### 시나리오 2: Pull Request 머지 기반 배포

```
1. BE 프로젝트 소스 커밋 및 Pull Request 생성
   ↓
2. 코드 리뷰 및 승인
   ↓
3. Pull Request 머지
   ↓
4. GitHub Actions 자동 트리거
   ↓
5. 새 인스턴스 배포
   ↓
6. 기존 인스턴스 종료
```

## 🔧 구현 방법

### 방법 1: Git 태그 기반 자동 배포 (가장 권장)

#### GitHub Actions 워크플로우 설정

```yaml
name: Build and Deploy

on:
  push:
    tags:
      - 'v*'  # v로 시작하는 태그

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2
      
      - name: Build Spring Boot image
        if: contains(github.ref, 'v')
        run: |
          if [ -d "backend/springboot" ]; then
            cd backend/springboot
            docker build -f Dockerfile -t nas-backend-springboot:${{ github.ref_name }} .
          fi
      
      - name: Build Kotlin image
        if: contains(github.ref, 'v')
        run: |
          if [ -d "backend/kotlin" ]; then
            cd backend/kotlin
            docker build -f Dockerfile -t nas-backend-kotlin:${{ github.ref_name }} .
          fi

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: startsWith(github.ref, 'refs/tags/v')
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy to server
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /path/to/nas
            git pull origin main
            docker-compose -f docker-compose.yml -f docker-compose.prod.yml build --no-cache
            docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

#### 사용 방법

```bash
# 1. 코드 커밋
git add .
git commit -m "feat: 새로운 기능 추가"
git push origin main

# 2. 태그 생성 및 푸시
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# 3. GitHub Actions가 자동으로 트리거됨
# 4. GitHub → Actions에서 배포 상태 확인
```

---

### 방법 2: Pull Request 머지 기반 배포

#### GitHub Actions 워크플로우 설정

```yaml
name: Deploy on Merge

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy to server
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /path/to/nas
            git pull origin main
            docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
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

## 📝 GitHub Issues와 배포 연동

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
- [ ] GitHub Actions 파이프라인 실행
- [ ] 헬스 체크 확인
```

### Pull Request 머지로 배포 트리거

Pull Request를 머지하면 자동으로 배포가 트리거됩니다.

---

## 🔄 전체 워크플로우

### 1. 개발 → 배포 프로세스

```
1. 개발자 코드 작성
   ↓
2. GitHub에 커밋 및 푸시
   ↓
3. Pull Request 생성
   ↓
4. 코드 리뷰 및 승인
   ↓
5. Merge to main
   ↓
6. Git 태그 생성 (v1.0.0)
   ↓
7. GitHub Actions 자동 트리거
   ↓
8. 새 인스턴스 배포
   ↓
9. 헬스 체크 확인
   ↓
10. 기존 인스턴스 종료
    ↓
11. Issue에 배포 완료 댓글
```

### 2. 태그 기반 배포 프로세스

```
1. 코드 커밋 및 푸시
   ↓
2. Git 태그 생성 (v1.0.0)
   ↓
3. 태그 푸시
   ↓
4. GitHub Actions 자동 트리거
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
git push origin main

# 2. 태그 생성
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# 3. GitHub Actions에서 파이프라인 확인 및 배포 실행
```

### GitHub Issues 연동

Issue에는 배포 정보만 기록:
```
배포 태그: v1.0.0
배포 일시: 2024-01-15
배포 상태: ✅ 완료
```

---

## 📊 배포 상태 추적

### Issue에 배포 상태 업데이트

GitHub Actions에서 GitHub API를 사용하여 Issue 업데이트:

```yaml
- name: Update Issue
  uses: actions/github-script@v6
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    script: |
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: '✅ 배포 완료: 태그 ${{ github.ref_name }}가 성공적으로 배포되었습니다.'
      })
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

### 1단계: GitHub Actions 워크플로우 생성
`.github/workflows/deploy.yml` 파일에 위의 태그 기반 배포 설정 추가

### 2단계: GitHub Secrets 설정
- `SERVER_HOST`: 서버 IP 주소
- `SERVER_USER`: SSH 사용자 이름
- `SSH_PRIVATE_KEY`: SSH 개인 키

### 3단계: 태그 생성 및 배포
```bash
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

### 4단계: GitHub Actions에서 배포 확인
- GitHub → Actions → 해당 워크플로우 확인
- 배포 상태 모니터링

### 5단계: Issue에 배포 정보 기록
```
배포 태그: v1.0.0
배포 상태: ✅ 완료
```

---

**작성일**: 2024년
**대상 환경**: Oracle Cloud Infrastructure 단일 인스턴스
**권장 방법**: 태그 기반 자동 배포


