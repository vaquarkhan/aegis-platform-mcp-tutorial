"""Mirror every fenced code block in each article into its snippets/ folder.

Run from anywhere:
    python articles/tools/extract_snippets.py

The article is the source of truth. A numbered snippet file is generated for every
fenced block. Blocks tagged text are captured output, not commands to run.
"""
from __future__ import annotations

import re
from pathlib import Path

ARTICLES = Path(__file__).resolve().parents[1]
EXTENSIONS = {
    "": "txt",
    "bash": "sh",
    "hcl": "tf",
    "java": "java",
    "json": "json",
    "powershell": "ps1",
    "text": "txt",
    "yaml": "yaml",
}
OPEN_FENCE = re.compile(r"^(`{3,})([\w+-]*)\s*$")


def slug(value: str) -> str:
    value = re.sub(r"[`*_]", "", value).lower()
    return re.sub(r"[^a-z0-9]+", "-", value).strip("-")[:48]


def blocks(markdown: Path):
    section = "introduction"
    fence = None
    body: list[str] = []
    for line in markdown.read_text(encoding="utf-8").split("\n"):
        if fence is None:
            match = OPEN_FENCE.match(line.rstrip())
            if match:
                fence = (len(match.group(1)), match.group(2))
                body = []
                continue
            heading = re.match(r"^#{2,3}\s+(.+)$", line)
            if heading:
                section = heading.group(1)
            continue
        stripped = line.rstrip()
        if stripped and set(stripped) == {"`"} and len(stripped) == fence[0]:
            yield section, fence[1], "\n".join(body)
            fence = None
        else:
            body.append(line)
    if fence is not None:
        raise ValueError(f"unclosed fence in {markdown}")


def main() -> None:
    total = 0
    for number in (1, 2, 3):
        folder = ARTICLES / f"part{number}"
        article = folder / f"DZONE-ARTICLE-PART{number}.md"
        output = folder / "snippets"
        output.mkdir(exist_ok=True)
        for old in output.iterdir():
            if old.is_file():
                old.unlink()
        rows = []
        for index, (section, language, body) in enumerate(blocks(article), 1):
            extension = EXTENSIONS.get(language, language or "txt")
            name = f"{index:02d}-{slug(section)}.{extension}"
            (output / name).write_text(body.rstrip("\n") + "\n", encoding="utf-8")
            first = body.strip().splitlines()[0] if body.strip() else ""
            first = first[:60].replace("|", "/").replace("`", "'")
            rows.append(f"| `{name}` | {section} | `{language or 'text'}` | `{first}` |")
            total += 1
        index_text = [
            f"# Part {number} code blocks, in article order",
            "",
            f"Every fenced block in `{article.name}`, one file each, numbered as it appears. "
            "Files ending in `.txt` are captured output, not commands to run.",
            "",
            "| File | Section | Language | First line |",
            "| --- | --- | --- | --- |",
            *rows,
            "",
        ]
        (output / "INDEX.md").write_text("\n".join(index_text), encoding="utf-8")
        print(f"part{number}: {len(rows)} blocks")
    print(f"total: {total}")


if __name__ == "__main__":
    main()
