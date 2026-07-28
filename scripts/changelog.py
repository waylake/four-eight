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


def inline(text: str) -> str:
    """줄 안의 표기를 옮긴다. **이스케이프된 문자열에 적용한다.**

    예전에는 이 변환이 `<li>` 안에서만 일어났고 굵게는 아예 다루지 않았다.
    그래서 v0.3.0 초안의 appcast 설명에 리터럴 `**`가 26개 남았다 —
    사용자가 업데이트 대화상자에서 별표를 그대로 읽게 되는 상태였다.
    발행 전에 잡았으므로 되돌릴 수 있었지만, appcast는 append-only이므로
    한 번 나가면 그 항목은 영구히 그 모양으로 남는다.

    링크는 글자만 남기고 주소를 버린다. CHANGELOG의 링크는
    `docs/adr/...` 같은 상대 경로이고, Sparkle의 릴리스 노트는 appcast
    주소를 기준으로 해석하므로 그 주소에는 문서가 없다. 눌리지 않는 링크를
    보여주는 것보다 글자만 남기는 것이 정직하다.
    """
    # 링크를 먼저 없앤다. 링크 글자 안의 굵게·코드가 뒤 규칙에 잡히도록.
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    # `코드` → <code>. 굵게보다 먼저 — 코드 안의 별표를 굵게로 읽지 않는다.
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    # **굵게** → <strong>
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    return text


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
            out.append(f"<h3>{inline(html.escape(line[4:]))}</h3>")
        elif line.lstrip().startswith(("- ", "* ")):
            if not in_list:
                out.append("<ul>")
                in_list = True
            out.append(f"<li>{inline(html.escape(line.lstrip()[2:]))}</li>")
        else:
            if in_list:
                out.append("</ul>")
                in_list = False
            out.append(f"<p>{inline(html.escape(line))}</p>")
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
