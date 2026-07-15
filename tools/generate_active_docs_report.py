#!/usr/bin/env python3
"""Generate the active Markdown documentation consistency report.

P0-031 intentionally scans only active documentation. Legacy, archived, and
reference Markdown can contain contradictory old design ideas, so this command
uses a conservative active-doc allowlist plus legacy-status exclusions instead
of walking every .md file in the repository.
"""

from __future__ import annotations

import argparse
import dataclasses
import re
import sys
import tempfile
from collections import Counter, defaultdict
from pathlib import Path
from typing import Iterable
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "docs" / "reports" / "active_markdown_report.md"

ACTIVE_ROOT_DOCS = ("README.md", "AGENTS.md", "TODO.md")
ACTIVE_DOC_DIRS = ("docs",)
EXCLUDED_ACTIVE_SUBDIRS = ("docs/reports",)
LEGACY_STATUSES = {"archive", "reference", "superseded"}
REFERENCE_MARKER_RE = re.compile(
    r"\b(source needed|citation needed|reference needed|missing source|missing reference)\b",
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
    return sorted((path for path in root.rglob("*.md") if ".git" not in path.parts), key=lambda p: rel(p, root).casefold())


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
            candidates.update(base.rglob("*.md"))

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


def normalize_character_name(name: str) -> str:
    cleaned = re.sub(r"\s+", " ", name).strip()
    cleaned = re.sub(r"^(captain|master|brother|sister|viceroy|prince|bishop|king|queen)\s+", "", cleaned, flags=re.IGNORECASE)
    return cleaned.casefold()


def check_duplicate_character_names(active_docs: list[Path], root: Path) -> list[Issue]:
    occurrences: dict[str, list[tuple[Path, int, str]]] = defaultdict(list)
    for path in active_docs:
        in_character_section = False
        section_level = 0
        for line_number, raw_line in enumerate(read_text(path).splitlines(), start=1):
            heading = HEADING_RE.match(raw_line)
            if heading:
                level = len(heading.group(1))
                title = heading.group(2).strip().casefold()
                if title in {"characters", "main cast", "historical figures (mentioned/background)"}:
                    in_character_section = True
                    section_level = level
                elif in_character_section and level <= section_level:
                    in_character_section = False
            if not in_character_section:
                continue
            match = CHARACTER_BULLET_RE.match(raw_line)
            if not match:
                continue
            name = match.group(1).strip()
            key = normalize_character_name(name)
            if key:
                occurrences[key].append((path, line_number, name))

    issues: list[Issue] = []
    for _key, hits in sorted(occurrences.items()):
        unique_locations = {(path, line_number) for path, line_number, _name in hits}
        if len(unique_locations) <= 1:
            continue
        names = ", ".join(f"`{name}` at `{rel(path, root)}:{line_number}`" for path, line_number, name in hits)
        first_path, first_line, first_name = hits[0]
        issues.append(
            Issue(
                "DUPLICATE_CHARACTER_NAME",
                rel(first_path, root),
                first_line,
                f"Character name `{first_name}` appears more than once in active character lists: {names}",
            )
        )
    return issues


def normalize_event_label(label: str) -> str:
    # Parenthetical event names are common in timeline labels, for example
    # `April 23, 1343 (St. George's Night)`. Keep the parenthetical text so
    # the date can change while the event key remains comparable.
    label = re.sub(r"\(([^)]*)\)", r" \1 ", label)
    label = re.sub(r"\b(1[0-9]{3}|20[0-9]{2})\b", "", label)
    label = re.sub(r"\b(January|February|March|April|May|June|July|August|September|October|November|December)\b", "", label, flags=re.IGNORECASE)
    label = re.sub(r"\b[0-9]{1,2}\b", "", label)
    label = re.sub(r"\b(pre|late|early|mid|c\.?|ca\.?|circa)\b", "", label, flags=re.IGNORECASE)
    label = re.sub(r"[^\w\sõäöüÕÄÖÜ-]", " ", label, flags=re.UNICODE)
    return re.sub(r"\s+", " ", label).strip().casefold()


def extract_date_values(text: str) -> set[str]:
    values: set[str] = set()
    for month, day, year in MONTH_DAY_YEAR_RE.findall(text):
        values.add(f"{month.casefold()} {int(day)} {year}")
    for month, year in MONTH_YEAR_RE.findall(text):
        values.add(f"{month.casefold()} {year}")
    without_ranges = YEAR_RANGE_RE.sub("", text)
    for year in YEAR_RE.findall(without_ranges):
        values.add(year)
    for start, end in YEAR_RANGE_RE.findall(text):
        values.add(f"{start}-{end}")
    return values


def check_contradictory_dates(active_docs: list[Path], root: Path) -> list[Issue]:
    events: dict[str, list[tuple[Path, int, str, set[str]]]] = defaultdict(list)
    for path in active_docs:
        for line_number, line in enumerate(read_text(path).splitlines(), start=1):
            match = DATE_LINE_RE.match(line)
            if not match:
                continue
            label = match.group(1)
            event_key = normalize_event_label(label)
            dates = extract_date_values(label)
            if event_key and dates:
                events[event_key].append((path, line_number, label, dates))

    issues: list[Issue] = []
    for _event, hits in sorted(events.items()):
        unique_date_sets = {tuple(sorted(dates)) for _path, _line, _label, dates in hits}
        if len(unique_date_sets) <= 1:
            continue
        details = "; ".join(
            f"`{label}` at `{rel(path, root)}:{line_number}`"
            for path, line_number, label, _dates in hits
        )
        first_path, first_line, first_label, _dates = hits[0]
        issues.append(
            Issue(
                "CONTRADICTORY_DATE",
                rel(first_path, root),
                first_line,
                f"Event/date label `{first_label}` conflicts with another active date label: {details}",
            )
        )
    return issues


def check_missing_references(active_docs: list[Path], root: Path) -> list[Issue]:
    issues: list[Issue] = []
    for path in active_docs:
        for line_number, raw_line in enumerate(read_text(path).splitlines(), start=1):
            line = strip_code_spans(raw_line)
            if REFERENCE_MARKER_RE.search(line):
                issues.append(
                    Issue(
                        "MISSING_REFERENCE",
                        rel(path, root),
                        line_number,
                        "Active doc contains an explicit missing-reference marker.",
                    )
                )
    return issues


def render_report(result: ReportResult) -> str:
    issue_counts = Counter(issue.code for issue in result.issues)
    active_links = [link for link in result.links if link.target_is_active is True]
    legacy_or_reference_links = [link for link in result.links if link.target_is_active is False]
    external_links = [link for link in result.links if link.target_path is None]

    lines: list[str] = []
    lines.append("# Active Markdown Documentation Report")
    lines.append("")
    lines.append("Generated by `python3 tools/generate_active_docs_report.py` for TODO P0-031.")
    lines.append("")
    lines.append("## Scope")
    lines.append("")
    lines.append("Active Markdown scanned:")
    lines.append("")
    lines.append("- Root product/task docs: `README.md`, `AGENTS.md`, `TODO.md`.")
    lines.append("- `docs/**/*.md`, excluding generated `docs/reports/**`.")
    lines.append("- Files with explicit legacy status `archive`, `reference`, or `superseded` are excluded even if they match the path rules.")
    lines.append("")
    lines.append("This deliberately excludes legacy root design docs, `characters/`, `scenes/`, `story/`, `history/`, and asset-reference Markdown unless those docs are reconciled into `docs/` or root active docs.")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    lines.append(f"- Active Markdown files scanned: `{len(result.active_docs)}`")
    lines.append(f"- Markdown files excluded as archive/reference/out of active scope: `{len(result.excluded_docs)}`")
    lines.append(f"- Local/external links inspected: `{len(result.links)}`")
    lines.append(f"- Links to active Markdown docs: `{len(active_links)}`")
    lines.append(f"- Links to existing archive/reference/non-active local docs: `{len(legacy_or_reference_links)}`")
    lines.append(f"- External links skipped for reachability: `{len(external_links)}`")
    lines.append(f"- Issues found: `{len(result.issues)}`")
    lines.append("")
    lines.append("## Issue counts")
    lines.append("")
    lines.append("| Code | Count |")
    lines.append("| --- | ---: |")
    for code in ("BROKEN_LINK", "BROKEN_ANCHOR", "DUPLICATE_CHARACTER_NAME", "CONTRADICTORY_DATE", "MISSING_REFERENCE"):
        lines.append(f"| `{code}` | {issue_counts[code]} |")
    lines.append("")
    lines.append("## Issues")
    lines.append("")
    if result.issues:
        lines.append("| Code | Location | Detail |")
        lines.append("| --- | --- | --- |")
        for issue in result.issues:
            detail = issue.message.replace("|", "\\|")
            lines.append(f"| `{issue.code}` | `{issue.path}:{issue.line}` | {detail} |")
    else:
        lines.append("No active Markdown documentation issues found.")
    lines.append("")
    lines.append("## Active files scanned")
    lines.append("")
    for path in result.active_docs:
        lines.append(f"- `{rel(path, result.root)}`")
    lines.append("")
    lines.append("## Verification")
    lines.append("")
    lines.append("- Clean active docs: `python3 tools/generate_active_docs_report.py --check`")
    lines.append("- Seeded invalid fixture: `python3 tools/generate_active_docs_report.py --fixture invalid`")
    lines.append("- Seeded clean fixture: `python3 tools/generate_active_docs_report.py --fixture clean`")
    lines.append("")
    return "\n".join(lines)


def analyze(root: Path) -> ReportResult:
    active_docs, excluded_docs = collect_active_docs(root)
    active_set = set(active_docs)
    issues: list[Issue] = []
    link_issues, links = check_links(active_docs, active_set, root)
    issues.extend(link_issues)
    issues.extend(check_duplicate_character_names(active_docs, root))
    issues.extend(check_contradictory_dates(active_docs, root))
    issues.extend(check_missing_references(active_docs, root))
    issues.sort(key=lambda issue: (issue.code, issue.path, issue.line, issue.message))
    placeholder = ReportResult(root, active_docs, excluded_docs, links, issues, "")
    rendered = render_report(placeholder)
    return ReportResult(root, active_docs, excluded_docs, links, issues, rendered)


def write_fixture(root: Path, kind: str) -> None:
    (root / "docs" / "CHARACTERS").mkdir(parents=True, exist_ok=True)
    (root / "docs" / "SCENES").mkdir(parents=True, exist_ok=True)
    (root / "story" / "archive").mkdir(parents=True, exist_ok=True)
    (root / "README.md").write_text(
        "# Fixture Product\n\n"
        "See [Canon](./docs/CANON.md) and [Archive](./story/archive/old.md).\n",
        encoding="utf-8",
    )
    (root / "AGENTS.md").write_text("# AGENTS.md\n\nActive fixture guide.\n", encoding="utf-8")
    (root / "TODO.md").write_text("# TODO\n\n- [ ] FIXTURE\n", encoding="utf-8")
    (root / "story" / "archive" / "old.md").write_text(
        "> **Legacy status:** `archive`\n\n# Old archive\n\n[Broken ignored link](./missing.md)\n",
        encoding="utf-8",
    )

    if kind == "clean":
        canon = """# Canon: Fixture

## Timeline

* **April 23, 1343 (St. George's Night)** - **`attested`** (Source: fixture source)
  * Fixture event.

## Names & Pronunciation

### Main Cast

* **Kalev** (The Smith) - **`invented`**
  * *Notes:* Fixture protagonist.
* **Mart** (The Apprentice) - **`invented`**
  * *Notes:* Fixture apprentice.
"""
        scene = """# Fixture Scene

**Timeline:** April 23, 1343

## Characters

* **Aita:** Mentioned in prose, not a canonical duplicate list entry.
"""
    elif kind == "invalid":
        canon = """# Canon: Fixture

## Timeline

* **April 23, 1343 (St. George's Night)** - **`attested`** (Source needed)
  * Fixture event.
* **May 14, 1343 (St. George's Night)** - **`attested`** (Source: contradictory fixture source)
  * Contradictory fixture event.

## Names & Pronunciation

### Main Cast

* **Kalev** (The Smith) - **`invented`**
  * *Notes:* Fixture protagonist.
* **Kalev** (The Other Smith) - **`invented`**
  * *Notes:* Duplicate fixture protagonist.

[Broken link](./MISSING.md)
"""
        scene = """# Fixture Scene

See [missing anchor](../CANON.md#not-a-real-anchor).
"""
    else:
        raise ValueError(f"unknown fixture kind: {kind}")

    (root / "docs" / "CANON.md").write_text(canon, encoding="utf-8")
    (root / "docs" / "SCENES" / "fixture-scene.md").write_text(scene, encoding="utf-8")


def run_fixture(kind: str) -> int:
    with tempfile.TemporaryDirectory(prefix="active-docs-fixture-") as tmp:
        fixture_root = Path(tmp)
        write_fixture(fixture_root, kind)
        result = analyze(fixture_root)
        print(result.rendered)
        if result.issues:
            print(f"fixture `{kind}` failed with {len(result.issues)} issue(s)", file=sys.stderr)
            return 1
        print(f"fixture `{kind}` passed with zero issues")
        return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate active Markdown documentation report for P0-031")
    parser.add_argument("--check", action="store_true", help="fail when active docs contain issues or the report is stale")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT), help="report output path; defaults to docs/reports/active_markdown_report.md")
    parser.add_argument("--fixture", choices=("clean", "invalid"), help="run against a seeded in-memory fixture instead of the repository")
    args = parser.parse_args()

    if args.fixture:
        return run_fixture(args.fixture)

    result = analyze(ROOT)
    output = Path(args.output)
    if not output.is_absolute():
        output = ROOT / output

    if args.check:
        current = output.read_text(encoding="utf-8") if output.exists() else ""
        stale = current != result.rendered
        if stale:
            print(f"{rel(output, ROOT)} is not up to date", file=sys.stderr)
        if result.issues:
            print(f"active Markdown docs contain {len(result.issues)} issue(s)", file=sys.stderr)
        if stale or result.issues:
            return 1
        print(f"{rel(output, ROOT)} is up to date and active Markdown docs have zero issues")
        return 0

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(result.rendered, encoding="utf-8")
    print(f"wrote {rel(output, ROOT)} with {len(result.issues)} issue(s)")
    return 1 if result.issues else 0


if __name__ == "__main__":
    raise SystemExit(main())
