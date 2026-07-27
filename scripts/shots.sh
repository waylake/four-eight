#!/usr/bin/env bash
# README용 스크린샷 촬영.
#
# 화면 기록 권한이 필요합니다. 터미널에서 처음 실행하면 시스템 설정으로
# 안내되며, 승인 후 터미널을 재시작하고 다시 실행하세요.
#
# 사용: bash scripts/shots.sh [출력 디렉터리]

set -euo pipefail

OUT="${1:-docs/assets}"
mkdir -p "$OUT"

APP_DIR=$(xcodebuild -project FourEight.xcodeproj -scheme FourEight \
	-configuration Debug -showBuildSettings 2>/dev/null |
	awk -F' = ' '/ BUILT_PRODUCTS_DIR/{print $2; exit}')
APP="$APP_DIR/FourEight.app"

if [[ ! -d "$APP" ]]; then
	echo "빌드된 앱이 없습니다. 먼저 실행하세요:"
	echo "  xcodegen generate && xcodebuild -project FourEight.xcodeproj -scheme FourEight -configuration Debug -skipMacroValidation build"
	exit 1
fi

open -a "$APP"
sleep 3

WINDOW_ID=$(
	osascript -e '
  tell application "System Events"
    tell process "FourEight"
      set frontmost to true
    end tell
  end tell' >/dev/null 2>&1
	/usr/bin/python3 -c "
import Quartz, sys
for w in Quartz.CGWindowListCopyWindowInfo(
        Quartz.kCGWindowListOptionOnScreenOnly, Quartz.kCGNullWindowID):
    if w.get('kCGWindowOwnerName') == 'FourEight' and w.get('kCGWindowLayer') == 0:
        b = w['kCGWindowBounds']
        if b['Width'] > 600:
            print(w['kCGWindowNumber'])
            sys.exit()
"
)

if [[ -z "$WINDOW_ID" ]]; then
	echo "FourEight 창을 찾지 못했습니다. 앱이 떠 있는지 확인하세요."
	exit 1
fi

screencapture -o -l "$WINDOW_ID" "$OUT/screenshot-light.png"
echo "저장: $OUT/screenshot-light.png"

echo
echo "다크 모드 캡처는 시스템 설정에서 외관을 바꾼 뒤 다시 실행하세요:"
echo "  bash scripts/shots.sh"
echo "그리고 결과를 screenshot-dark.png로 이름을 바꾸세요."
