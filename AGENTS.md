# Global & Workspace Behavior Rules

## 🛑 Git & Script Execution Rules
- **`git commit`**: 커밋 생성은 사용자의 사전 승인 없이 자율적으로 진행해도 됩니다.
- **`git push`**: 원격 저장소(GitHub/GitLab 등)로 푸시하는 `git push` 명령을 실행할 때에는 **반드시 사전에 사용자에게 확인할 커밋 목록과 대상 브랜치를 알리고 명시적인 승인/확인을 받은 후**에만 실행해야 합니다.
- **`curl` 원격 스크립트 안내**: Proxmox 호스트 등에서 실행할 `curl` 스크립트 URL은 `main` 브랜치 대신 **방금 커밋된 고유 커밋 해시(Commit Hash, e.g. `https://raw.githubusercontent.com/waceh/nas/<commit-hash>/...`)**를 명시하여 캐시 오염을 원천 방지하고 버전 불변성을 보장해야 합니다.
