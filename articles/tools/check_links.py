"""Verify that every relative Markdown link and image in the articles resolves to a real file.

External http(s) links and in-page anchors are not checked.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ARTICLES = Path(__file__).resolve().parents[1]
REPO = ARTICLES.parent
LINK = re.compile(r"(?<!!)\[[^\]]*\]\(([^)]+)\)")
IMAGE = re.compile(r"!\[[^\]]*\]\(([^)]+)\)")

def strip_code(text: str) -> str:
    out = []
    fence = None
    for line in text.split("\n"):
        stripped = line.lstrip()
        marker = None
        if stripped.startswith("```"):
            marker = "`" * (len(stripped) - len(stripped.lstrip("`")))
        if fence is None and marker:
            fence = marker
            continue
        if fence is not None and marker and stripped.startswith(fence):
            fence = None
            continue
        if fence is None:
            out.append(re.sub(r"`[^`]*`", "", line))
    return "\n".join(out)


problems: list[str] = []
for markdown in ARTICLES.rglob("*.md"):
    text = strip_code(markdown.read_text(encoding="utf-8"))
    for pattern in (LINK, IMAGE):
        for target in pattern.findall(text):
            target = target.strip()
            if target.startswith(("http://", "https://", "#", "mailto:")):
                continue
            path_part = target.split("#", 1)[0].split("?", 1)[0]
            if not path_part:
                continue
            resolved = (markdown.parent / path_part).resolve()
            if not resolved.exists():
                problems.append(f"{markdown.relative_to(REPO)} -> {target}")

if problems:
    print("BROKEN LINKS")
    print("\n".join(problems))
    sys.exit(1)
print("all relative links and images resolve")
