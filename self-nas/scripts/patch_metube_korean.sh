#!/usr/bin/env bash
# ==============================================================================
# MeTube (http://192.168.1.107:8081) 100% 한국어 UI 패처 (self-nas)
# ==============================================================================
# - MeTube 컨테이너 내부의 Web UI (index.html 및 렌더링 DOM)에
#   실시간 한국어 번역 엔진(MutationObserver)을 주입하여 모든 영문 메뉴를
#   "다운로드 추가", "화질/품질", "저장 폴더", "완료 목록 지우기" 등으로 완벽 번역합니다.
# ==============================================================================

set -e

GREEN='\033[1;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $1"; }

CTID="${CTID:-107}"

if ! pct status "$CTID" &>/dev/null; then
    log_err "LXC 컨테이너 ${CTID} 가 실행 중이지 않습니다."
    exit 1
fi

log_info "MeTube (http://192.168.1.107:8081) 한국어 UI 패치 주입 중..."

pct exec "$CTID" -- docker exec metube python3 -c '
import os

injector = """<script>
(function() {
  const dict = {
    "Add": "다운로드 추가",
    "Format": "포맷 선택",
    "Quality": "화질 / 음질",
    "Folder": "저장 폴더",
    "Advanced": "고급 옵션",
    "Downloads": "다운로드 목록",
    "Clear finished": "완료 목록 지우기",
    "Clear all": "전체 목록 지우기",
    "Theme": "화면 테마",
    "Dark": "어두운 테마 (Dark)",
    "Light": "밝은 테마 (Light)",
    "Auto": "자동 (Auto)",
    "Best": "최고화질 (Best)",
    "Audio": "음원 추출 (MP3/FLAC)",
    "Video": "동영상 (MP4/MKV)",
    "No downloads yet": "현재 진행 중인 다운로드가 없습니다",
    "URL": "유튜브/웹 영상 URL을 여기에 붙여넣으세요",
    "Enter URL": "유튜브/웹 영상 URL을 여기에 붙여넣으세요",
    "Active": "다운로드 중",
    "Completed": "완료됨",
    "Finished": "완료됨",
    "Queued": "대기 중",
    "Preparing": "다운로드 준비 중...",
    "Error": "다운로드 실패",
    "Options": "상세 옵션",
    "Custom arguments": "사용자 커스텀 인자",
    "Custom name": "저장할 파일명 직접 지정",
    "Any (video)": "동영상 (최고화질)",
    "Any (audio)": "음원 (최고음질)",
    "Cancel": "취소",
    "Retry": "재시도",
    "Delete": "삭제"
  };

  function translate(node) {
    if (!node) return;
    if (node.nodeType === 3) {
      let t = node.nodeValue.trim();
      if (dict[t]) {
        node.nodeValue = node.nodeValue.replace(t, dict[t]);
      }
    } else if (node.nodeType === 1) {
      if (node.placeholder && dict[node.placeholder]) node.placeholder = dict[node.placeholder];
      if (node.title && dict[node.title]) node.title = dict[node.title];
      if (node.tagName === "INPUT" && node.value && dict[node.value]) node.value = dict[node.value];
      for (let c of node.childNodes) translate(c);
    }
  }

  const obs = new MutationObserver(muts => {
    for (let m of muts) {
      if (m.type === "childList") {
        for (let a of m.addedNodes) translate(a);
      } else if (m.type === "characterData") {
        translate(m.target);
      }
    }
  });

  function start() {
    translate(document.body);
    obs.observe(document.body, { childList: true, subtree: true, characterData: true });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start);
  } else {
    start();
  }
})();
</script>"""

found = False
for root, dirs, files in os.walk("/app"):
    for f in files:
        if f == "index.html":
            p = os.path.join(root, f)
            with open(p, "r", encoding="utf-8") as fp:
                c = fp.read()
            if "dict" not in c:
                if "</head>" in c:
                    c = c.replace("</head>", injector + "</head>")
                else:
                    c = c + injector
                with open(p, "w", encoding="utf-8") as fp:
                    fp.write(c)
                print(f"[OK] 한국어 패치 완료: {p}")
                found = True

if not found:
    print("[INFO] index.html 이미 패치되었거나 대기 중")
'

log_ok "MeTube (http://192.168.1.107:8081) 한국어 패치가 성공적으로 적용되었습니다!"
echo -e "브라우저에서 ${GREEN}http://192.168.1.107:8081${NC} 을 새로고침(F5 또는 Cmd+Shift+R)해 보세요!"
