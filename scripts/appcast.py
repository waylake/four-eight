#!/usr/bin/env python3
"""appcast.xml에 릴리스 항목을 더한다.

Sparkle의 `generate_appcast`는 과거 아카이브 전부를 로컬에 두고 매번
전체를 다시 만든다. CI에서는 그 상태를 유지하기 번거로우므로, 기존
appcast를 읽어 항목 하나만 더하는 방식을 쓴다.

appcast는 append-only로 다룬다. 한 번 나간 항목은 지우지 않는다.
구버전 사용자가 그 항목을 근거로 업데이트를 판단하기 때문이다.

사용:
  appcast.py --appcast appcast.xml --version 0.2.0 --build 42 \\
             --url https://.../FourEight.zip --length 20740469 \\
             --signature 'GTPl...' --min-system 15.0 \\
             --notes-file notes.html [--calculation-changed]
"""

import argparse
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE_NS)


def skeleton() -> ET.Element:
    rss = ET.Element("rss", {"version": "2.0"})
    channel = ET.SubElement(rss, "channel")
    ET.SubElement(channel, "title").text = "FourEight"
    ET.SubElement(channel, "link").text = "https://waylake.github.io/four-eight/appcast.xml"
    ET.SubElement(channel, "description").text = "FourEight 업데이트 피드"
    ET.SubElement(channel, "language").text = "ko"
    return rss


def load(path: Path) -> ET.ElementTree:
    if path.exists() and path.stat().st_size > 0:
        return ET.parse(path)
    return ET.ElementTree(skeleton())


def build_number(item: ET.Element) -> int:
    node = item.find(f"{{{SPARKLE_NS}}}version")
    if node is None or not (node.text or "").strip():
        # 오래된 형식은 enclosure 속성에 들어 있다.
        enc = item.find("enclosure")
        if enc is not None:
            raw = enc.get(f"{{{SPARKLE_NS}}}version", "0")
            return int(raw) if raw.isdigit() else 0
        return 0
    text = node.text.strip()
    return int(text) if text.isdigit() else 0


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--appcast", required=True, type=Path)
    p.add_argument("--version", required=True, help="0.2.0")
    p.add_argument("--build", required=True, type=int)
    p.add_argument("--url", required=True)
    p.add_argument("--length", required=True, type=int)
    p.add_argument("--signature", required=True)
    p.add_argument("--min-system", default="15.0")
    p.add_argument("--notes-file", type=Path)
    p.add_argument(
        "--calculation-changed",
        action="store_true",
        help="만세력 계산 결과가 달라지는 릴리스임을 표시한다. 사용자가 이미 본 명식이 바뀔 수 있으므로 앱이 따로 알린다.",
    )
    args = p.parse_args()

    tree = load(args.appcast)
    channel = tree.getroot().find("channel")
    if channel is None:
        print("appcast에 channel 요소가 없습니다", file=sys.stderr)
        return 1

    existing = channel.findall("item")

    # 같은 빌드 번호가 이미 있으면 덮어쓴다. 재실행이 안전해야 한다.
    for item in existing:
        if build_number(item) == args.build:
            channel.remove(item)

    # 빌드 번호는 단조 증가해야 한다. 낮은 값을 올리면 Sparkle이
    # 다운그레이드로 보고 무시하며, 그 사실이 조용히 묻힌다.
    highest = max((build_number(i) for i in channel.findall("item")), default=0)
    if args.build <= highest:
        print(
            f"빌드 번호 {args.build}가 기존 최고값 {highest} 이하입니다. "
            "커밋 수가 줄어드는 히스토리 변경이 있었는지 확인하세요.",
            file=sys.stderr,
        )
        return 1

    item = ET.Element("item")
    ET.SubElement(item, "title").text = f"버전 {args.version}"
    ET.SubElement(item, f"{{{SPARKLE_NS}}}version").text = str(args.build)
    ET.SubElement(item, f"{{{SPARKLE_NS}}}shortVersionString").text = args.version
    ET.SubElement(item, f"{{{SPARKLE_NS}}}minimumSystemVersion").text = args.min_system
    ET.SubElement(item, "pubDate").text = datetime.now(timezone.utc).strftime(
        "%a, %d %b %Y %H:%M:%S +0000"
    )

    if args.notes_file and args.notes_file.exists():
        notes = args.notes_file.read_text(encoding="utf-8").strip()
        if notes:
            # 릴리스 노트를 피드에 실어 업데이트 창 안에서 읽히게 한다.
            # "새 버전이 있습니다"만 띄우고 브라우저로 내보내지 않는다.
            desc = ET.SubElement(item, "description")
            desc.text = notes

    if args.calculation_changed:
        ET.SubElement(item, "fourEightCalculationChanged").text = "true"

    ET.SubElement(
        item,
        "enclosure",
        {
            "url": args.url,
            "length": str(args.length),
            "type": "application/octet-stream",
            f"{{{SPARKLE_NS}}}edSignature": args.signature,
        },
    )

    # 최신이 위로 오게 둔다.
    channel.insert(len(list(channel)) - len(existing), item)

    ET.indent(tree, space="  ")
    tree.write(args.appcast, encoding="utf-8", xml_declaration=True)
    print(f"appcast 갱신: {args.version} (build {args.build})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
