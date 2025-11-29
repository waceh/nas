# 저장소 목적 및 사용 가이드

## 📋 저장소 목적

이 GitHub 저장소(`waceh/nas`)는 **아키텍처 설계 문서 전용** 저장소입니다.

### 포함 내용
- ✅ 아키텍처 설계 문서
- ✅ Docker Compose 구성 예시
- ✅ CI/CD 파이프라인 설계
- ✅ 설치 및 설정 가이드
- ✅ 배포 아키텍처 문서

### 포함하지 않는 내용
- ❌ 실제 구현 코드 (FE, BE 소스 코드)
- ❌ 실제 운영 환경 설정 파일
- ❌ 실제 배포 스크립트
- ❌ 실제 데이터베이스 스키마

## 🎯 사용 목적

### 1. 아키텍처 설계 참고
- Oracle Cloud Infrastructure 환경 설계
- Docker Compose 구성 계획
- CI/CD 파이프라인 설계
- 서비스 간 통신 구조 설계

### 2. 구현 가이드
- 실제 구현 시 참고할 수 있는 가이드
- Docker Compose 설정 예시
- GitLab CI/CD 설정 예시

### 3. 문서화
- 시스템 아키텍처 문서화
- 배포 프로세스 문서화
- 운영 가이드 문서화

## 📁 문서 구조

```
nas-oracle-cloud/
├── README.md                    # 메인 문서
├── ARCHITECTURE_GITLAB.md       # GitLab 기반 아키텍처
├── ARCHITECTURE_DOCKER.md       # Docker Compose 아키텍처
├── DEPLOYMENT_ARCHITECTURE.md   # 배포 아키텍처 상세
├── GITLAB_SETUP_GUIDE.md        # GitLab 설치 가이드
├── DOCKER_MANAGEMENT_TOOLS.md   # Docker 관리 도구 가이드
├── docker-compose.yml           # Docker Compose 예시
├── .gitlab-ci.yml               # GitLab CI/CD 예시
└── ci-cd/                       # CI/CD 가이드
```

## 🔄 실제 구현과의 관계

### 실제 구현 저장소
실제 구현 코드는 별도 저장소에서 관리됩니다:
- Frontend 소스 코드
- Backend 소스 코드 (Spring Boot, Kotlin)
- 실제 운영 설정 파일
- 실제 배포 스크립트

### 이 저장소의 역할
- 아키텍처 설계 참고 자료
- 구현 시 참고할 수 있는 가이드
- 시스템 구조 문서화

## 📝 문서 사용 방법

### 1. 아키텍처 이해
- `ARCHITECTURE_GITLAB.md`: 전체 시스템 아키텍처
- `DEPLOYMENT_ARCHITECTURE.md`: 배포 구조 상세

### 2. 구현 가이드 참고
- `docker-compose.yml`: Docker Compose 구성 예시
- `.gitlab-ci.yml`: CI/CD 파이프라인 예시
- `GITLAB_SETUP_GUIDE.md`: GitLab 설치 가이드

### 3. 운영 가이드
- `ci-cd/README.md`: CI/CD 가이드
- `DOCKER_MANAGEMENT_TOOLS.md`: 관리 도구 가이드

## ⚠️ 주의사항

1. **예시 파일**: `docker-compose.yml`, `.gitlab-ci.yml` 등은 예시이며, 실제 구현 시 환경에 맞게 수정 필요
2. **환경 변수**: `env.example`은 참고용이며, 실제 환경 변수는 별도 관리
3. **보안**: 실제 운영 환경에서는 보안 설정을 추가로 적용해야 함

## 🔗 관련 문서

- [메인 README](README.md)
- [GitLab 아키텍처](ARCHITECTURE_GITLAB.md)
- [배포 아키텍처](DEPLOYMENT_ARCHITECTURE.md)
- [GitLab 설치 가이드](GITLAB_SETUP_GUIDE.md)

---

**작성일**: 2024년
**목적**: 아키텍처 설계 문서 저장소
**실제 구현**: 별도 저장소에서 관리


