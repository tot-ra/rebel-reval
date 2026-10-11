"""Markdown link and anchor validation for the active documentation report."""

from __future__ import annotations

import re
from collections import Counter
from pathlib import Path
from typing import Iterable
from urllib.parse import unquote, urlparse

from active_docs_report_common import (
    HEADING_RE,
    HTML_ANCHOR_RE,
    HTML_LINK_RE,
    MD_LINK_RE,
    Issue,
    LinkRecord,
    read_text,
    rel,
)


def slugify_heading(heading: str) -> str:
    """Approximate GitHub-style Markdown anchor generation."""
    heading = re.sub(r"`([^`]*)`", r"\1", heading)
    heading = re.sub(r"<[^>]+>", "", heading)
    heading = heading.strip().casefold()
    chars: list[str] = []
    for ch in heading:
        if ch.isalnum() or ch in " _-":
            chars.append(ch)
    slug = "".join(chars).strip().replace(" ", "-")
    slug = re.sub(r"-+", "-", slug)
    return slug


def anchors_for(path: Path) -> set[str]:
    text = read_text(path)
    anchors: set[str] = set()
    seen: Counter[str] = Counter()
    for line in text.splitlines():
        heading_match = HEADING_RE.match(line)
        if heading_match:
            base = slugify_heading(heading_match.group(2))
            if base:
                seen[base] += 1
                anchors.add(base if seen[base] == 1 else f"{base}-{seen[base] - 1}")
        for html_anchor in HTML_ANCHOR_RE.finditer(line):
            anchors.add(html_anchor.group(1))
    return anchors


def split_local_destination(destination: str) -> tuple[str, str]:
    parsed = urlparse(destination)
    path = unquote(parsed.path)
    anchor = unquote(parsed.fragment)
    return path, anchor


def is_external_destination(destination: str) -> bool:
    parsed = urlparse(destination)
    return bool(parsed.scheme and parsed.scheme not in {"", "file"}) or destination.startswith(("mailto:", "tel:"))


def resolve_link(source: Path, destination: str, root: Path) -> Path | None:
    path_text, _anchor = split_local_destination(destination)
    if not path_text:
        return source
    candidate = (source.parent / path_text).resolve()
    root_resolved = root.resolve()
    try:
        candidate.relative_to(root_resolved)
    except ValueError:
        return candidate
    return candidate


def iter_link_destinations(line: str) -> Iterable[str]:
    for match in MD_LINK_RE.finditer(line):
        yield match.group(1)
    for match in HTML_LINK_RE.finditer(line):
        yield match.group(1)


def check_links(active_docs: list[Path], active_set: set[Path], root: Path) -> tuple[list[Issue], list[LinkRecord]]:
    issues: list[Issue] = []
    links: list[LinkRecord] = []
    anchor_cache: dict[Path, set[str]] = {}
    for source in active_docs:
        for line_number, line in enumerate(read_text(source).splitlines(), start=1):
            for destination in iter_link_destinations(line):
                if is_external_destination(destination):
                    links.append(LinkRecord(source, line_number, destination, None, None, None))
                    continue
                target = resolve_link(source, destination, root)
                if target is None:
                    continue
                path_text, anchor = split_local_destination(destination)
                target_exists = target.exists() if path_text else source.exists()
                target_active = target in active_set if target_exists and target.suffix.lower() == ".md" else None
                links.append(LinkRecord(source, line_number, destination, target, target_exists, target_active))
                if not target_exists:
                    issues.append(
                        Issue(
                            "BROKEN_LINK",
                            rel(source, root),
                            line_number,
                            f"Local Markdown link target does not exist: `{destination}`",
                        )
                    )
                    continue
                if anchor:
                    if target.suffix.lower() != ".md":
                        continue
                    anchor_cache.setdefault(target, anchors_for(target))
                    if anchor not in anchor_cache[target]:
                        issues.append(
                            Issue(
                                "BROKEN_ANCHOR",
                                rel(source, root),
                                line_number,
                                f"Local Markdown link anchor `#{anchor}` not found in `{rel(target, root)}`",
                            )
                        )
    return issues, links
