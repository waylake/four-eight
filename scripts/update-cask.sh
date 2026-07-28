#!/usr/bin/env bash
# Homebrew cask를 새 릴리스에 맞춰 갱신한다.
#
# 자체 tap(waylake/homebrew-tap)을 쓴다. 공식 homebrew-cask는 audit에서
# Gatekeeper 통과를 강제하므로 공증되지 않은 앱은 등재할 수 없다.
#
# postflight에서 격리 속성을 제거하는 것이 이 경로의 핵심이다. Homebrew는
# 내려받은 앱에 격리를 붙이고, 격리된 미공증 앱은 macOS 15부터 시스템 설정을
# 거쳐야만 열린다. 속성을 벗기면 Gatekeeper가 아예 평가하지 않는다.
#
# 이는 사용자가 Gatekeeper 대신 이 저장소를 신뢰한다는 뜻이다. 그래서
# sha256을 :no_check로 두지 않는다. 자산이 바뀌면 설치가 실패해야 한다.
#
# 사용: scripts/update-cask.sh <version> <sha256> [tap-checkout-path]

set -euo pipefail

VERSION="${1:?버전이 필요합니다 (예: 0.1.0)}"
SHA256="${2:?sha256이 필요합니다}"
TAP="${3:-../homebrew-tap}"

if [[ ! -d "$TAP" ]]; then
	echo "tap 체크아웃이 없습니다: $TAP"
	echo "  git clone https://github.com/waylake/homebrew-tap.git $TAP"
	exit 1
fi

mkdir -p "$TAP/Casks"
cat >"$TAP/Casks/four-eight.rb" <<RUBY
cask "four-eight" do
  version "${VERSION}"
  sha256 "${SHA256}"

  url "https://github.com/waylake/four-eight/releases/download/v#{version}/FourEight.zip"
  name "FourEight"
  desc "Four Pillars of Destiny reading, computed and interpreted on device"
  homepage "https://github.com/waylake/four-eight"

  # 문자열 비교 형태(">= :sequoia")는 Homebrew 6에서 deprecated다.
  depends_on macos: :sequoia

  # 앱이 Sparkle로 스스로 갱신하므로 brew가 버전을 앞지르려 하지 않게 한다.
  auto_updates true

  app "FourEight.app"

  postflight do
    # Homebrew는 내려받은 앱에 격리 속성을 붙인다. 이 앱은 Apple 공증을
    # 받지 않았으므로 격리된 채로는 macOS 15+에서 시스템 설정을 거쳐야만
    # 열린다. 격리만 정확히 제거한다 -- xattr -cr은 provenance 등 다른
    # 속성까지 지우므로 쓰지 않는다.
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/FourEight.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Application Support/FourEight",
    "~/Library/Caches/com.waylake.FourEight",
    "~/Library/Preferences/com.waylake.FourEight.plist",
    "~/Library/HTTPStorages/com.waylake.FourEight",
    "~/Library/Containers/com.waylake.FourEight",
  ]
end
RUBY

echo "갱신됨: $TAP/Casks/four-eight.rb (버전 $VERSION)"
echo
echo "다음 단계:"
echo "  cd $TAP"
echo "  git add Casks/four-eight.rb"
echo "  git commit -m 'four-eight $VERSION'"
echo "  git push"
