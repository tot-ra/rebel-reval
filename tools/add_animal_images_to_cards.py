#!/usr/bin/env python3
"""Insert the concept image reference into each animal card.

Adds `![<Title>](images/<slug>.jpg)` right after the blockquote line and adds
an "Archive reference images"-style note only where the card lacks an image row.
Idempotent: skips cards that already reference their image.
"""
import re
import sys
from pathlib import Path

CARDS = Path("/Users/artjomkurapov/git/rebel-reval/docs/ANIMALS-AND-BIRDS")


def main() -> int:
    missing = []
    for md in sorted(CARDS.glob("*.md")):
        if md.name == "README.md":
            continue
        slug = md.stem
        img = CARDS / "images" / f"{slug}.jpg"
        if not img.exists():
            missing.append(slug)
            continue
        text = md.read_text()
        if f"](images/{slug}.jpg)" in text:
            continue
        title = text.splitlines()[0].lstrip("# ").strip()
        block = re.search(r"^> .*$", text, re.M)
        if not block:
            print(f"no blockquote in {md.name}", file=sys.stderr)
            return 1
        insert_at = block.end()
        text = text[:insert_at] + f"\n\n![{title}](images/{slug}.jpg)" + text[insert_at:]
        md.write_text(text)
    if missing:
        print("images not generated yet:", " ".join(missing))
        return 1
    print("all cards updated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
