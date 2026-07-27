#!/usr/bin/env bash
# README용 스크린샷 생성.
#
# 화면 캡처가 아니라 SwiftUI ImageRenderer로 실제 뷰 트리를 렌더링한다.
# 화면 기록 권한이 필요 없고, 같은 입력에 같은 이미지가 나온다.
# 창 테두리(타이틀바·신호등)만 macOS 표준 형태로 합성한다.
#
# 앱은 샌드박스에서 돌기 때문에 저장소 경로에 직접 쓸 수 없다. 컨테이너
# 안에 쓴 뒤 여기서 꺼내 온다.
#
# 사용: bash scripts/shots.sh [출력 디렉터리]

set -euo pipefail

OUT="${1:-docs/assets}"
BUNDLE_ID="com.waylake.FourEight"
CONTAINER="$HOME/Library/Containers/$BUNDLE_ID/Data/Library/Application Support/FourEight/screenshots"

if [[ ! -d FourEight.xcodeproj ]]; then
	echo "프로젝트가 없습니다. 먼저 실행하세요: xcodegen generate"
	exit 1
fi

APP_DIR=$(xcodebuild -project FourEight.xcodeproj -scheme FourEight \
	-configuration Debug -showBuildSettings 2>/dev/null |
	awk -F' = ' '/ BUILT_PRODUCTS_DIR/{print $2; exit}')
APP="$APP_DIR/FourEight.app"

if [[ ! -d "$APP" ]]; then
	echo "빌드된 앱이 없습니다. 먼저 실행하세요:"
	echo "  xcodebuild -project FourEight.xcodeproj -scheme FourEight \\"
	echo "             -configuration Debug -skipMacroValidation -skipPackagePluginValidation build"
	exit 1
fi

mkdir -p "$OUT"
rm -f "$CONTAINER"/screenshot-*.png 2>/dev/null || true

echo "렌더링 중…"
FOUREIGHT_CAPTURE=1 "$APP/Contents/MacOS/FourEight" 2>&1 | grep '스크린샷' || true

shopt -s nullglob
FILES=("$CONTAINER"/screenshot-*.png)
if [[ ${#FILES[@]} -eq 0 ]]; then
	echo "이미지가 생성되지 않았습니다. 컨테이너를 확인하세요:"
	echo "  $CONTAINER"
	exit 1
fi

for f in "${FILES[@]}"; do
	cp "$f" "$OUT/"
	echo "  $(basename "$f")"
done
echo "완료: $OUT"
