# Git Push Confirmation Rule

## 📌 Rules for Git Push Operations
1. **`git commit` 자율 수행**: 에이전트는 사용자의 별도 확인 없이 `git commit` 명령을 자율적으로 수행할 수 있습니다.
2. **`git push` 전 사용자 승인 필수**:
   - `git push` (원격 저장소로 코드를 전송하는 모든 명령)를 실행하기 전에는 **반드시 사용자에게 변경 내용과 커밋 목록을 설명하고, push 실행 여부를 물어본 뒤 승인을 얻어야 합니다.**
   - 승인 없이 무단으로 `git push` 명령을 실행해서는 안 됩니다.
3. **승인 요청 시 포함할 정보**:
   - 대상 리모트 및 브랜치 (예: `origin/main`)
   - 푸시할 커밋의 요약 내용 (커밋 해시, 커밋 메시지)
