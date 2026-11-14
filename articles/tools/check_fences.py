"""Confirm every fenced code block in each article is opened and closed."""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
ok = True
for number in (1, 2, 3):
    md = ROOT / f"part{number}" / f"DZONE-ARTICLE-PART{number}.md"
    depth = None
    for line in md.read_text(encoding="utf-8").split("\n"):
        stripped = line.strip()
        match = re.match(r"^(`{3,})", stripped)
        if not match:
            continue
        length = len(match.group(1))
        if depth is None:
            depth = length
        elif set(stripped) == {"`"} and length == depth:
            depth = None
    state = "balanced" if depth is None else "UNBALANCED"
    if depth is not None:
        ok = False
    print(f"part{number}: {state}")
print("OK" if ok else "FENCE ERROR")
