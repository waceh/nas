# 배포 아키텍처 상세 설명

## 📊 단일 서버 배포 구조

### 전체 흐름

```
개발자 코드 푸시
    ↓
GitHub 저장소 (github.com/waceh)
    ↓
GitHub Actions 파이프라인 트리거
    ↓
GitHub Actions Runner (Ubuntu)
    ↓
SSH를 통한 서버 접근
    ↓
호스트 Docker Engine
    ↓
Docker Compose로 FE, BE 배포
    ↓
NAS 애플리케이션 서비스 실행
```

## 🔧 기술적 세부사항

### 1. GitHub Actions 설정

#### SSH를 통한 서버 접근
- **이유**: 원격 서버에서 직접 배포 실행
- **방법**: SSH 키 기반 인증

#### GitHub Secrets 설정
```yaml
secrets:
  SERVER_HOST: 서버 IP 주소
  SERVER_USER: SSH 사용자 이름
  SSH_PRIVATE_KEY: SSH 개인 키
```
- **목적**: 안전한 서버 접근
- **효과**: 민감한 정보를 안전하게 관리

#### SSH Action 사용
```yaml
- uses: appleboy/ssh-action@master
  with:
    host: ${{ secrets.SERVER_HOST }}
    username: ${{ secrets.SERVER_USER }}
    key: ${{ secrets.SSH_PRIVATE_KEY }}
```
- **목적**: 원격 서버에서 명령 실행
- **효과**: 배포 스크립트 실행 가능

### 2. CI/CD 파이프라인

#### Build Stage
- Docker 이미지 빌드 (Spring Boot, Kotlin, Vue.js)
- 이미지는 GitHub Actions Runner에서 빌드

#### Test Stage
- 단위 테스트 실행
- 통합 테스트 (Docker Compose 사용)

#### Deploy Stage
- **SSH를 통한 원격 서버 접근**
- 기존 컨테이너 중지 및 제거
- 새 이미지로 컨테이너 재시작
- 헬스 체크 검증

### 3. 배포 프로세스

```bash
# 1. 기존 서비스 중지
docker-compose down

# 2. 새 이미지 빌드
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build --no-cache

# 3. 서비스 시작
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# 4. 헬스 체크
curl http://localhost:3000/api/springboot/health
curl http://localhost:3000/api/kotlin/health
```

## ✅ 장점

### 1. 단순성
- 복잡한 네트워크 설정 불필요
- 별도 배포 서버 불필요
- 설정이 간단하고 이해하기 쉬움

### 2. 성능
- 네트워크 오버헤드 없음
- 빠른 배포 속도
- 리소스 효율적

### 3. 비용
- 추가 서버 불필요
- 단일 인스턴스로 모든 기능 제공
- Oracle Cloud 비용 최소화

### 4. 개발 효율성
- 빠른 배포 사이클
- 즉시 테스트 가능
- 개발 환경에 최적

## ⚠️ 주의사항

### 1. 보안
- **Privileged 모드**: Runner가 호스트 시스템에 접근 가능
- **권장**: 신뢰할 수 있는 코드만 실행
- **대안**: 프로덕션에서는 별도 배포 서버 고려

### 2. 격리
- Runner와 애플리케이션이 같은 호스트
- Runner 장애가 애플리케이션에 영향 가능
- **완화**: Runner는 별도 컨테이너로 격리

### 3. 확장성
- 단일 서버 제한
- 수평 확장 어려움
- **대안**: 필요 시 Kubernetes로 전환

## 🔄 다른 패턴과 비교

### 패턴 1: 현재 구조 (GitHub Actions + SSH)
```
GitHub Actions → SSH → 원격 서버 배포
```
- **적합**: 소규모, 개발 환경
- **장점**: 간단, 빠름, 비용 효율, 외부 서비스 활용
- **단점**: SSH 키 관리 필요

### 패턴 2: 별도 배포 서버
```
GitHub Actions → Docker Registry → SSH/API → 배포 서버
```
- **적합**: 프로덕션, 멀티 서버
- **장점**: 격리, 확장성, 보안
- **단점**: 복잡, 비용 증가

### 패턴 3: Kubernetes
```
GitHub Actions → Docker Registry → Kubernetes API → Pod 배포
```
- **적합**: 대규모, 엔터프라이즈
- **장점**: 확장성, 고가용성
- **단점**: 복잡도 높음, 리소스 요구

## 📈 확장 계획

### 단기 (현재)
- 단일 서버 배포 구조 유지
- GitHub Actions + SSH를 통한 배포

### 중기 (필요 시)
- 별도 배포 서버 추가
- Docker Registry 도입
- 멀티 서버 환경 구성

### 장기 (대규모 확장)
- Kubernetes 클러스터
- GitHub Actions를 Kubernetes 배포로 전환
- 완전한 CI/CD 파이프라인

## 🎯 결론

현재 구조는 **단일 서버 환경에서 최적의 선택**입니다:

1. ✅ 간단하고 빠른 배포
2. ✅ 비용 효율적
3. ✅ 개발 효율성 극대화
4. ✅ Oracle Cloud 단일 인스턴스에 적합

프로덕션 환경에서도 단일 서버로 운영 가능하며, 향후 확장이 필요할 때는 별도 배포 서버나 Kubernetes로 전환할 수 있습니다.

---

**작성일**: 2024년
**대상 환경**: Oracle Cloud Infrastructure 단일 인스턴스
**배포 방식**: GitHub Actions → SSH → 원격 서버 Docker Compose 실행


