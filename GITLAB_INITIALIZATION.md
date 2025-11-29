# GitLab 초기화 상태 확인 가이드

## 🔍 초기화 상태 확인 방법

GitLab은 처음 시작할 때 데이터베이스 마이그레이션 및 초기 설정이 필요하여 **5-10분** 정도 소요됩니다.

### 1. 서버에서 직접 확인

```bash
# GitLab 컨테이너 접속
docker exec -it nas-gitlab bash

# GitLab 서비스 상태 확인
gitlab-ctl status

# Puma (웹 서버) 로그 확인
gitlab-ctl tail puma

# 초기화 완료 여부 확인
gitlab-ctl reconfigure
```

### 2. HTTP 응답 확인

```bash
# 로컬에서 확인
curl -I http://localhost:8080

# 외부에서 확인
curl -I http://158.180.76.251:8080
```

### 3. 초기 비밀번호 확인

GitLab 초기화가 완료되면 초기 root 비밀번호를 확인할 수 있습니다:

```bash
docker exec -it nas-gitlab grep 'Password:' /etc/gitlab/initial_root_password
```

**주의**: 이 파일은 24시간 후 자동으로 삭제됩니다.

## ⏱️ 예상 소요 시간

- **최소**: 3-5분
- **일반**: 5-10분
- **최대**: 15분 (리소스가 부족한 경우)

## 🚨 문제 해결

### 초기화가 너무 오래 걸리는 경우

1. **리소스 확인**
   ```bash
   docker stats nas-gitlab
   ```

2. **로그 확인**
   ```bash
   docker logs nas-gitlab --tail 100
   ```

3. **재시작**
   ```bash
   docker compose restart gitlab
   ```

### 502 Bad Gateway 에러

- GitLab이 아직 초기화 중입니다
- 몇 분 더 기다려주세요
- Puma가 완전히 시작될 때까지 대기 필요

### 접속이 안 되는 경우

1. **포트 확인**
   ```bash
   sudo netstat -tlnp | grep 8080
   ```

2. **방화벽 확인**
   ```bash
   sudo ufw status | grep 8080
   ```

3. **OCI Security List 확인**
   - OCI 콘솔에서 8080 포트가 열려있는지 확인

## ✅ 초기화 완료 확인

다음 명령으로 초기화 완료를 확인할 수 있습니다:

```bash
# HTTP 200 응답 확인
curl -I http://158.180.76.251:8080 | grep "HTTP/1.1 200"

# 또는 브라우저에서 접속
# http://158.180.76.251:8080
```

초기화가 완료되면 GitLab 로그인 페이지가 표시됩니다.

