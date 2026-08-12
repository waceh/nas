# 📋 GitHub Public 전환 전 보안 & 프로젝트 점검 체크리스트

본 문서는 현재 Private 상태인 **NAS 프로젝트 저장소**를 GitHub Public(공개) 저장소로 전환할 때 필수적으로 점검 및 수정해야 하는 사항들과 **Git 히스토리 진단 결과**를 정리한 가이드입니다.

---

## 1. 🔍 과거 Git 커밋 히스토리(Git Log Audit) 전수 조사 결과

> 💡 **주요 진단 결과 요약**
> 1. **비밀 키 및 계정 파일 (`private/`)**: `private/` 디렉터리 및 SSH 개인 키(`*.key`), `server info.txt` 파일은 **과거 Git 히스토리에 단 한 번도 올려진 적이 없습니다.** (`.gitignore`에 의해 완벽 차단됨 확인)
> 2. **⚠️ 커밋 메시지 내 실서버 IP 노출 건 (발견!)**: Commit [`89996bd`](https://github.com/waceh/nas/commit/89996bd)의 메시지에 실제 서버 IP (`158.180.x.x`)가 명시되어 있습니다. Public 전환 시 누구나 past commit history 조회를 통해 해당 IP를 볼 수 있습니다.

---

## 2. 🛡️ 보안 및 기밀 정보 (Secrets & Sensitive Data) 점검

### 2-1. `.gitignore` 기밀 파일 제외 상태 재확인
- [x] **`/private/` 디렉터리 제외 확인**
  - SSH 개인 키(`private/ssh-key-*.key`) 및 실제 서버 계정/IP 정보(`private/server info.txt`)가 Git 추적 대상에서 제외되었는지 확인 ([`.gitignore`](../.gitignore)에 `/private/` 등록됨).
- [x] **환경변수 파일 제외**
  - `.env`, `.env.local`, `.env.production` 등 실서버 비밀번호/토큰이 담긴 파일이 제외되어 있는지 확인 ([`.gitignore`](../.gitignore) 등록 완료).
- [x] **IDE 및 빌드 부산물 제외**
  - `.idea/`, `.vscode/`, `node_modules/`, `build/`, `dist/`, `*.log` 등 개발 환경 관련 파일 제외 확인 ([`.gitignore`](../.gitignore) 등록 완료).

### 2-2. 문서 및 소스코드 내 하드코딩된 민감 정보 점검
- [x] **실제 서버 IP 주소 치환**
  - 문서 내 실제 IP가 `YOUR_SERVER_IP` 또는 `127.0.0.1`로 교체되었는지 점검 (최근 커밋 `89996bd`로 1차 교체 완료).
- [x] **내부 파일명/키파일명 일반화 (Generalization)**
  - [`cloud-nas/ROLLING_DEPLOYMENT_GUIDE.md`](../cloud-nas/ROLLING_DEPLOYMENT_GUIDE.md), [`cloud-nas/IDE_MYSQL_CONNECTION.md`](../cloud-nas/IDE_MYSQL_CONNECTION.md) 등 가이드 문서에 기재된 `ssh-key-2024-05-24.key` 파일명을 `your-ssh-key.key` 일반 예시 파일명으로 변경 완료.
- [x] **Netdata / 외부 서비스 Claim Token 검증**
  - `docker-compose.yml` 상에 실제 Netdata Claim Token이나 API Key가 하드코딩되어 있지 않고 `${NETDATA_CLAIM_TOKEN}` 과 같이 환경변수화되어 있는지 재확인.

---

## 3. 🚨 커밋 메시지 실서버 IP 소거 방법 (선택 가이드)

Commit `89996bd` 메시지에 남아있는 `158.180.x.x` IP를 완전히 삭제하기 위한 2가지 조치 방법입니다.

### 방법 A: Git Orphan Branch로 깨끗한 Initial Commit으로 재구성 (권장)
과거 커밋 히스토리를 1개의 깨끗한 'Initial Commit'으로 재구성하여 Public으로 공개하는 가장 깔끔한 방법입니다.

```bash
# 1. 새 임시 브랜치 생성
git checkout --orphan clean-main

# 2. 현재 소스 전체 스테이징
git add .

# 3. 깨끗한 첫 커밋 생성
git commit -m "Initial commit for public release"

# 4. 기존 main 브랜치 삭제 및 이름 변경
git branch -D main
git branch -m main

# 5. 원격 저장소에 강제 푸시 (Public 전환 전 수행)
git push -f origin main
```

### 방법 B: OCI (Oracle Cloud) 방화벽 / IP 재발급
- 커밋 히스토리를 유지하고 싶다면, Oracle Cloud Console에서 인스턴스의 Public IP를 변경(Ephemeral IP 재할당)하거나, OCI Security List(방화벽)에서 SSH(22포트) 및 외부 접근 포트를 특정 본인 IP만 접근하도록 제한합니다.

---

## 4. 📝 오픈소스 readiness & 문서화 (Documentation)

### 4-1. 오픈소스 라이선스 (`LICENSE`) 파일 추가
- [x] **라이선스 명시** (MIT License 추가 완료)
  - Public 저장소는 타인의 코드 이용/복제/수정 권한을 명확히 하기 위해 라이선스 배치가 필요합니다. (예: MIT License, Apache 2.0).

### 4-2. `env.example` 템플릿 최신화
- [x] **필수 환경변수 누락 여부 점검**
  - 외부 사용자가 참고할 수 있도록 [`cloud-nas/env.example`](../cloud-nas/env.example) 파일 구성 최신화 완료.

---

## 5. 🚀 Public 전환 작업 순서 (Action Plan)

1. **커밋 메시지 내 IP 소거 작업 (방법 A 권장)**
2. **`LICENSE` 파일 추가 및 변경사항 Commit & Push**
3. **GitHub 저장소 페이지 진입**:
   - `Settings` → 맨 아래 `Danger Zone` → `Change repository visibility`
4. **`Change to public` 클릭 후 저장소 이름 입력하여 승인**
