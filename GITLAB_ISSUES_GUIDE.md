# GitLab Issues를 Jira처럼 사용하기

## 📋 개요

GitLab Issues는 Jira의 많은 기능을 제공하며, 적절한 설정과 워크플로우를 통해 Jira와 유사한 프로젝트 관리가 가능합니다.

> **배포 자동화**: GitLab Issues와 태그를 연동하여 배포를 자동화할 수 있습니다. 자세한 내용은 [DEPLOYMENT_AUTOMATION.md](DEPLOYMENT_AUTOMATION.md)를 참조하세요.

## 🆚 GitLab Issues vs Jira 비교

### 기능 비교표

| 기능 | GitLab Issues | Jira |
|------|---------------|------|
| 이슈 생성/관리 | ✅ | ✅ |
| 라벨 (Labels) | ✅ | ✅ (Priorities) |
| 마일스톤 (Milestones) | ✅ | ✅ (Versions) |
| 담당자 지정 (Assignee) | ✅ | ✅ |
| 우선순위 | ✅ (Labels로 구현) | ✅ (기본 기능) |
| 스프린트 | ⚠️ (Milestones로 구현) | ✅ (기본 기능) |
| 칸반 보드 | ✅ (Board 기능) | ✅ |
| 백로그 | ✅ | ✅ |
| 버전 관리 | ✅ (Milestones) | ✅ |
| 워크플로우 | ✅ (Issue Boards) | ✅ |
| 시간 추적 | ✅ | ✅ |
| 댓글/토론 | ✅ | ✅ |
| 파일 첨부 | ✅ | ✅ |
| 이슈 링크 | ✅ | ✅ |
| 서브태스크 | ✅ | ✅ |
| 에픽 | ✅ (Labels로 구현) | ✅ |
| 버너 다운 차트 | ❌ | ✅ |
| 스프린트 리포트 | ⚠️ (제한적) | ✅ |
| 고급 필터링 | ✅ | ✅ |
| 커스텀 필드 | ⚠️ (제한적) | ✅ |
| 자동화 규칙 | ✅ (CI/CD 통합) | ✅ |

## ✅ GitLab Issues로 Jira처럼 사용하기

### 1. 프로젝트 구조 설정

#### Labels (라벨) 구성
Jira의 Priority, Type, Status 등을 Labels로 구현:

```
Priority:
- 🔴 Critical
- 🟠 High
- 🟡 Medium
- 🟢 Low

Type:
- 🐛 Bug
- ✨ Feature
- 📝 Task
- 🔧 Improvement
- 📚 Documentation

Status:
- 📋 To Do
- 🔄 In Progress
- 👀 In Review
- ✅ Done
- ❌ Blocked

Epic:
- 🎯 Epic: [이름]
```

#### Milestones (마일스톤) 설정
Jira의 Versions/Sprints를 Milestones로 구현:

```
Sprint 1 (2024-01-01 ~ 2024-01-14)
Sprint 2 (2024-01-15 ~ 2024-01-28)
Release v1.0.0
Release v1.1.0
```

### 2. Issue Boards (칸반 보드) 설정

#### 기본 Board 구성
```
To Do | In Progress | In Review | Done
```

#### 고급 Board 구성
```
Backlog | To Do | In Progress | Code Review | Testing | Done
```

#### Board 설정 방법
1. 프로젝트 → **Boards** 메뉴
2. **Create new board** 클릭
3. Labels 기반으로 컬럼 생성
4. 각 컬럼에 해당하는 Label 지정

### 3. 워크플로우 구성

#### 기본 워크플로우
```
1. 이슈 생성 (To Do)
   ↓
2. 작업 시작 (In Progress)
   ↓
3. 코드 리뷰 (In Review)
   ↓
4. 완료 (Done)
```

#### GitLab Flow 워크플로우
```
1. 이슈 생성
   ↓
2. Feature 브랜치 생성 (feature/issue-123)
   ↓
3. 작업 및 커밋
   ↓
4. Merge Request 생성
   ↓
5. 코드 리뷰 및 승인
   ↓
6. Merge 및 이슈 자동 닫기
```

### 4. 이슈 템플릿 사용

#### Bug Report 템플릿
```markdown
## Description
[버그 설명]

## Steps to Reproduce
1. [단계 1]
2. [단계 2]
3. [단계 3]

## Expected Behavior
[예상 동작]

## Actual Behavior
[실제 동작]

## Environment
- OS: [운영체제]
- Browser: [브라우저]
- Version: [버전]

## Screenshots
[스크린샷 첨부]
```

#### Feature Request 템플릿
```markdown
## Summary
[기능 요약]

## Motivation
[동기 및 배경]

## Detailed Description
[상세 설명]

## Proposed Solution
[제안하는 해결책]

## Alternatives Considered
[고려한 대안]

## Additional Context
[추가 정보]
```

### 5. 에픽(Epic) 관리

#### Labels를 사용한 Epic 구성
```
Epic: User Authentication
Epic: Payment System
Epic: Admin Dashboard
```

#### Epic 이슈 생성
1. Epic을 위한 이슈 생성
2. Label: `Epic: [이름]` 추가
3. 관련 이슈들에 같은 Epic Label 추가
4. Epic 이슈에 서브태스크로 연결

### 6. 스프린트 관리

#### Milestones를 Sprint로 사용
```
Sprint 1 (2024-01-01 ~ 2024-01-14)
├── Issue #1: Feature A
├── Issue #2: Bug Fix B
└── Issue #3: Task C
```

#### 스프린트 계획
1. Milestone 생성 (Sprint 기간 설정)
2. 이슈들을 Milestone에 할당
3. Board에서 Milestone별로 필터링
4. 스프린트 종료 시 Milestone 닫기

### 7. 시간 추적

#### 시간 기록
```
/spend 2h 30m
```

#### 시간 보고
- 이슈 상세 페이지에서 시간 추적 확인
- 프로젝트 → **Analytics** → **Time tracking**

### 8. 자동화 규칙

#### Merge Request와 이슈 연결
- Merge Request 제목에 `Closes #123` 포함 시 자동으로 이슈 닫힘
- `Fixes #123`, `Resolves #123`도 동일하게 작동

#### CI/CD 통합
```yaml
# .gitlab-ci.yml
deploy:
  script:
    - echo "Deploying..."
  only:
    - main
  when: manual
```

## 🎯 Jira 스타일 워크플로우 구현

### 1. 프로젝트 설정

#### Labels 구성
```
Priority:
- P0 - Critical
- P1 - High
- P2 - Medium
- P3 - Low

Type:
- Bug
- Story
- Task
- Epic
- Technical Debt

Status:
- Backlog
- To Do
- In Progress
- In Review
- Testing
- Done
```

#### Milestones 구성
```
Sprint 1 (2024-01-01 ~ 2024-01-14)
Sprint 2 (2024-01-15 ~ 2024-01-28)
Release 1.0.0
Release 1.1.0
```

### 2. Issue Board 구성

#### 스프린트 Board
```
Backlog | To Do | In Progress | In Review | Testing | Done
```

#### 릴리스 Board
```
Release 1.0.0 | Release 1.1.0 | Release 1.2.0
```

### 3. 일일 스탠드업

#### 이슈 필터링
```
Assignee: @username
Milestone: Sprint 1
Status: In Progress
```

#### 진행 상황 확인
- Board에서 드래그 앤 드롭으로 상태 변경
- 댓글로 진행 상황 공유

### 4. 스프린트 리뷰

#### Milestone 리포트
1. 프로젝트 → **Milestones** → 해당 Sprint 선택
2. 완료된 이슈 확인
3. 미완료 이슈는 다음 Sprint로 이동

## 📊 GitLab Issues의 장점

### 1. Git 통합
- 코드와 이슈가 같은 플랫폼
- Merge Request와 이슈 자동 연결
- 커밋 메시지로 이슈 참조

### 2. CI/CD 통합
- 이슈 기반 배포
- 자동화된 워크플로우
- 배포 상태 추적

### 3. 비용
- GitLab CE는 무료
- Jira는 유료 (소규모 팀 제외)

### 4. 단일 플랫폼
- 코드, 이슈, Wiki, CI/CD 통합
- 컨텍스트 전환 최소화

## ⚠️ GitLab Issues의 제한사항

### 1. 고급 기능 부족
- 버너 다운 차트 없음
- 스프린트 리포트 제한적
- 커스텀 필드 제한적

### 2. 대규모 팀
- 복잡한 워크플로우에는 Jira가 더 적합
- 엔터프라이즈 기능 부족

### 3. 서드파티 통합
- Jira보다 통합 옵션 적음
- 일부 도구와의 연동 제한적

## 💡 권장 사용 방법

### 소규모/중규모 팀 (1-20명)
✅ **GitLab Issues 추천**
- GitLab Wiki + Issues로 충분
- 비용 효율적
- 통합 관리 용이

### 대규모 팀 (20명 이상)
⚠️ **Jira 고려**
- 복잡한 워크플로우 필요 시
- 고급 리포트 필요 시
- 엔터프라이즈 기능 필요 시

### 하이브리드 접근
- GitLab Issues: 개발 이슈, 버그 추적
- Jira: 프로젝트 관리, 스프린트 계획

## 🚀 빠른 시작 가이드

### 1단계: Labels 설정
```
프로젝트 → Settings → Labels → New label
```

### 2단계: Milestones 생성
```
프로젝트 → Milestones → New milestone
```

### 3단계: Issue Board 생성
```
프로젝트 → Boards → Create new board
```

### 4단계: 이슈 템플릿 설정
```
프로젝트 → Settings → General → Issues → Templates
```

### 5단계: 워크플로우 정의
- 이슈 생성 → 작업 시작 → 리뷰 → 완료
- Merge Request와 이슈 연결

## 📚 참고 자료

- [GitLab Issues 공식 문서](https://docs.gitlab.com/ee/user/project/issues/)
- [GitLab Boards 가이드](https://docs.gitlab.com/ee/user/project/boards/)
- [GitLab Milestones 가이드](https://docs.gitlab.com/ee/user/project/milestones/)

---

**작성일**: 2024년
**대상**: GitLab Issues를 Jira처럼 사용하고자 하는 팀
**권장**: 소규모/중규모 팀은 GitLab Issues로 충분

