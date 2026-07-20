"""Shared data types, configuration, and document discovery for active-doc checks."""

from __future__ import annotations

import dataclasses
import os
import re
from pathlib import Path

ACTIVE_ROOT_DOCS = ("README.md", "AGENTS.md", "TODO.md")
ACTIVE_DOC_DIRS = ("docs",)
EXCLUDED_ACTIVE_SUBDIRS = ("docs/reports",)
TOOL_CACHE_DIRS = frozenset({"__pycache__"})
LEGACY_STATUSES = {"archive", "reference", "superseded"}
REFERENCE_MARKER_RE = re.compile(
    # Match explicit authoring placeholders, not descriptive prose such as
    # "the missing source could not be fetched" in an operational policy.
    r"\b(source needed|citation needed|reference needed)\b",
    re.IGNORECASE,
)

# Markdown links/images with a non-empty destination. This intentionally avoids
# full Markdown parsing because the repository uses simple inline links.
MD_LINK_RE = re.compile(r"!?\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
HTML_LINK_RE = re.compile(r"<(?:a|img)\b[^>]*(?:href|src)=[\"']([^\"']+)[\"']", re.IGNORECASE)
HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*#*\s*$")
HTML_ANCHOR_RE = re.compile(r"<(?:a|[^>]+\s)\b[^>]*(?:id|name)=[\"']([^\"']+)[\"']", re.IGNORECASE)
CHARACTER_BULLET_RE = re.compile(r"^\s*[*-]\s+\*\*([^*]+?)\*\*(?:\s*\(([^)]*)\))?\s*[-–—]")
DATE_LINE_RE = re.compile(r"^\s*[*-]\s+\*\*([^*]*\b\d{3,4}\b[^*]*)\*\*\s*[-–—]")
YEAR_RANGE_RE = re.compile(r"\b(1[0-9]{3}|20[0-9]{2})\s*[-–—]\s*(1[0-9]{3}|20[0-9]{2})\b")
YEAR_RE = re.compile(r"\b(1[0-9]{3}|20[0-9]{2})\b")
MONTH_DAY_YEAR_RE = re.compile(
    r"\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+([0-9]{1,2}),\s*(1[0-9]{3}|20[0-9]{2})\b",
    re.IGNORECASE,
)
MONTH_YEAR_RE = re.compile(
    r"\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+(1[0-9]{3}|20[0-9]{2})\b",
    re.IGNORECASE,
)


@dataclasses.dataclass(frozen=True)
class Issue:
    code: str
    path: str
    line: int
    message: str


@dataclasses.dataclass(frozen=True)
class LinkRecord:
    source: Path
    line: int
    destination: str
    target_path: Path | None
    target_exists: bool | None
    target_is_active: bool | None


@dataclasses.dataclass(frozen=True)
class ReportResult:
    root: Path
    active_docs: list[Path]
    excluded_docs: list[Path]
    links: list[LinkRecord]
    issues: list[Issue]
    rendered: str


def rel(path: Path, root: Path) -> str:
    resolved_path = path.resolve()
    resolved_root = root.resolve()
    try:
        return resolved_path.relative_to(resolved_root).as_posix()
    except ValueError:
        return path.as_posix()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def strip_code_spans(line: str) -> str:
    return re.sub(r"`[^`]*`", "", line)


def legacy_status(text: str) -> str | None:
    """Return an explicit legacy status if the document declares one."""
    for line in text.splitlines()[:12]:
        match = re.search(r"legacy status:\*\*\s*`?([a-z -]+)`?", line, re.IGNORECASE)
        if not match:
            match = re.search(r"^legacy-status:\s*`?([a-z -]+)`?", line, re.IGNORECASE)
        if match:
            return match.group(1).strip().casefold()
    return None


def is_under(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def iter_markdown_files(root: Path) -> list[Path]:
    discovered: list[Path] = []
    for current_dir, dirnames, filenames in os.walk(root):
        dirnames[:] = [
            dirname
            for dirname in dirnames
            if not dirname.startswith(".") and dirname not in TOOL_CACHE_DIRS
        ]
        directory = Path(current_dir)
        discovered.extend(directory / filename for filename in filenames if filename.endswith(".md"))
    return sorted(discovered, key=lambda path: rel(path, root).casefold())


def collect_active_docs(root: Path) -> tuple[list[Path], list[Path]]:
    """Collect active Markdown docs and excluded Markdown docs.

    Active docs are the current product/task root docs plus docs/**/*.md. The
    generated reports directory is excluded to keep the command idempotent, and
    any file declaring legacy status archive/reference/superseded is excluded.
    """
    candidates: set[Path] = set()
    for doc in ACTIVE_ROOT_DOCS:
        path = root / doc
        if path.exists():
            candidates.add(path)
    for dirname in ACTIVE_DOC_DIRS:
        base = root / dirname
        if base.exists():
            candidates.update(iter_markdown_files(base))

    active: list[Path] = []
    excluded: set[Path] = set(iter_markdown_files(root))
    for path in sorted(candidates, key=lambda p: rel(p, root).casefold()):
        if any(is_under(path, root / excluded_dir) for excluded_dir in EXCLUDED_ACTIVE_SUBDIRS):
            continue
        status = legacy_status(read_text(path))
        if status in LEGACY_STATUSES:
            continue
        active.append(path)
        excluded.discard(path)
    return active, sorted(excluded, key=lambda p: rel(p, root).casefold())
