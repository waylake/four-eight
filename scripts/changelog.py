#!/usr/bin/env python3
"""CHANGELOG.md에서 한 버전의 섹션을 뽑는다.

릴리스 노트의 정본은 CHANGELOG.md다. 릴리스 본문과 appcast 설명은
여기서 파생된다. 두 곳에 따로 쓰면 반드시 어긋난다.

출력은 두 가지다.
  --format markdown : GitHub 릴리스 본문용
  --format html     : appcast <description>용 (업데이트 창 안에서 렌더링)

사용: changelog.py --version 0.2.0 [--format html]
"""

import argparse
import html
import re
import sys
from pathlib import Path


def extract(text: str, version: str) -> str | None:
    """## [0.2.0] 또는 ## 0.2.0 헤딩부터 다음 ## 전까지."""
    pattern = re.compile(
        rf"^##\s*\[?{re.escape(version)}\]?.*?$(.*?)(?=^##\s|\Z)",
        re.MULTILINE | re.DOTALL,
    )
    match = pattern.search(text)
    return match.group(1).strip() if match else None


def to_html(markdown: str) -> str:
    """의존성 없이 최소한만 변환한다. CHANGELOG는 헤딩과 불릿뿐이다."""
    out: list[str] = []
    in_list = False
    for raw in markdown.splitlines():
        line = raw.rstrip()
        if not line:
            continue
        if line.startswith("### "):
            if in_list:
                out.append("</ul>")
                in_list = False
            out.append(f"<h3>{html.escape(line[4:])}</h3>")
        elif line.lstrip().startswith(("- ", "* ")):
            if not in_list:
                out.append("<ul>")
                in_list = True
            item = line.lstrip()[2:]
            item = html.escape(item)
            # `코드` → <code>
            item = re.sub(r"`([^`]+)`", r"<code>\1</code>", item)
            out.append(f"<li>{item}</li>")
        else:
            if in_list:
                out.append("</ul>")
                in_list = False
            out.append(f"<p>{html.escape(line)}</p>")
    if in_list:
        out.append("</ul>")
    return "\n".join(out)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--version", required=True)
    p.add_argument("--changelog", type=Path, default=Path("CHANGELOG.md"))
    p.add_argument("--format", choices=["markdown", "html"], default="markdown")
    args = p.parse_args()

    if not args.changelog.exists():
        print(f"{args.changelog}가 없습니다", file=sys.stderr)
        return 1

    section = extract(args.changelog.read_text(encoding="utf-8"), args.version)
    if section is None:
        print(
            f"CHANGELOG.md에 {args.version} 섹션이 없습니다. "
            "릴리스 전에 '## [{v}] - YYYY-MM-DD' 형태로 추가하세요.".format(v=args.version),
            file=sys.stderr,
        )
        return 1

    print(to_html(section) if args.format == "html" else section)
    return 0


if __name__ == "__main__":
    sys.exit(main())
