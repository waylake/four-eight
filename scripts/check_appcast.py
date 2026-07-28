#!/usr/bin/env python3
"""appcast 무결성 검사.

appcast는 append-only다. 구버전 사용자가 이미 그 항목을 근거로 판단하기
때문에, 한 번 나간 항목을 지우면 되돌릴 방법이 없다. 이 규칙이 지금까지
AGENTS.md의 문장으로만 있었다. 문장은 지워지고 검사는 남는다.

검사 항목
  1. XML이 올바른가
  2. 항목마다 버전·빌드·자산·서명이 있는가
  3. 빌드 번호가 유일한가 (Sparkle은 중복을 예측 불가능하게 다룬다)
  4. **살아 있는 피드의 항목이 저장소 파일에도 전부 있는가** — append-only

3번까지는 네트워크 없이 검사한다. 4번은 피드를 받아야 하므로, 받지 못하면
경고만 남기고 통과시킨다. CI가 일시적 네트워크 문제로 깨지면 안 된다.

사용: python3 scripts/check_appcast.py [파일]
"""

import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
LIVE_URL = "https://waylake.github.io/four-eight/appcast.xml"


def entries(root: ET.Element) -> dict[str, dict[str, str]]:
    """빌드 번호 → 항목 요약."""
    found: dict[str, dict[str, str]] = {}
    for item in root.iter("item"):
        build = item.findtext(f"{{{SPARKLE}}}version")
        if build is None:
            raise ValueError("sparkle:version이 없는 항목이 있습니다")
        enclosure = item.find("enclosure")
        found[build.strip()] = {
            "version": (item.findtext(f"{{{SPARKLE}}}shortVersionString") or "").strip(),
            "url": (enclosure.get("url") if enclosure is not None else "") or "",
            "signature": (enclosure.get(f"{{{SPARKLE}}}edSignature") if enclosure is not None else "") or "",
            "length": (enclosure.get("length") if enclosure is not None else "") or "",
        }
    return found


def main() -> int:
    path = Path(sys.argv[1] if len(sys.argv) > 1 else "appcast.xml")
    if not path.exists():
        print(f"{path}가 없습니다.", file=sys.stderr)
        return 1

    text = path.read_text(encoding="utf-8")
    try:
        root = ET.fromstring(text)
    except ET.ParseError as error:
        print(f"XML이 올바르지 않습니다: {error}", file=sys.stderr)
        return 1

    try:
        local = entries(root)
    except ValueError as error:
        print(str(error), file=sys.stderr)
        return 1

    if not local:
        print("항목이 하나도 없습니다.", file=sys.stderr)
        return 1

    status = 0

    # 중복 빌드 번호는 문자열 파싱으로 잡는다. dict는 이미 합쳐 버리므로
    # 개수를 세서 비교한다.
    if text.count("<sparkle:version>") != len(local):
        print("빌드 번호가 중복된 항목이 있습니다.", file=sys.stderr)
        status = 1

    for build, item in sorted(local.items(), key=lambda kv: int(kv[0])):
        missing = [key for key, value in item.items() if not value]
        if missing:
            print(f"빌드 {build}에 빠진 값: {', '.join(missing)}", file=sys.stderr)
            status = 1

    # append-only 검사.
    try:
        with urllib.request.urlopen(LIVE_URL, timeout=15) as response:
            live = entries(ET.fromstring(response.read().decode("utf-8")))
    except (urllib.error.URLError, ET.ParseError, ValueError, TimeoutError) as error:
        print(f"살아 있는 피드를 받지 못해 append-only 검사를 건너뜁니다: {error}")
        live = {}

    for build, item in live.items():
        if build not in local:
            print(
                f"append-only 위반: 발행된 빌드 {build}"
                f"(v{item['version']})가 저장소 파일에 없습니다.",
                file=sys.stderr,
            )
            print(
                "  구버전 사용자가 이미 이 항목을 근거로 판단했습니다. "
                "지우지 말고 더 높은 빌드로 덮으십시오.",
                file=sys.stderr,
            )
            status = 1
            continue
        if local[build]["signature"] != item["signature"]:
            print(
                f"발행된 빌드 {build}의 서명이 저장소 파일과 다릅니다. "
                "이미 나간 항목의 서명을 바꾸면 그 버전을 받으려는 앱이 "
                "업데이트를 조용히 거부합니다.",
                file=sys.stderr,
            )
            status = 1

    if status == 0:
        versions = ", ".join(
            f"v{item['version']}({build})"
            for build, item in sorted(local.items(), key=lambda kv: int(kv[0]))
        )
        print(f"appcast 검사 통과 — {versions}")
    return status


if __name__ == "__main__":
    sys.exit(main())
