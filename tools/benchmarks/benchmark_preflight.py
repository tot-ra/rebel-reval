#!/usr/bin/env python3
"""Fail fast when a benchmark entry point depends on a missing res:// file (R-1536).

A Godot scene whose ext_resource is gone, or a script whose preload() target is
gone, does not exit: the scene loads empty (or the script fails to attach), no
code ever calls quit(), and the headless process idles forever. This walks the
ext_resource paths of .tscn/.tres files and the preload("res://...") targets of
.gd files, transitively, and lists every missing one.

Usage: tools/benchmarks/benchmark_preflight.py res://a.tscn res://b.gd ...
Exit 0 when everything resolves, 1 with one line per missing dependency.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXT_RESOURCE = re.compile(r'\[ext_resource[^\]]*\bpath="(res://[^"]+)"')
PRELOAD = re.compile(r'preload\(\s*"(res://[^"]+)"\s*\)')
FOLLOWED = {".tscn": EXT_RESOURCE, ".tres": EXT_RESOURCE, ".gd": PRELOAD}


def to_path(res_path: str, root: Path = ROOT) -> Path:
    return root / res_path.removeprefix("res://")


def missing_dependencies(entries: list[str], root: Path = ROOT) -> list[str]:
    """Return "<missing> (needed by <parent>)" lines for every unresolved path."""
    missing: list[str] = []
    seen: set[str] = set()
    stack: list[tuple[str, str]] = [(entry, "command line") for entry in entries]
    while stack:
        res_path, parent = stack.pop()
        if res_path in seen:
            continue
        seen.add(res_path)
        path = to_path(res_path, root)
        if not path.is_file():
            missing.append(f"{res_path} (needed by {parent})")
            continue
        pattern = FOLLOWED.get(path.suffix)
        if pattern is None:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for dependency in pattern.findall(text):
            stack.append((dependency, res_path))
    return sorted(missing)


def main(argv: list[str]) -> int:
    if not argv:
        print("Usage: benchmark_preflight.py res://entry.tscn [res://...]", file=sys.stderr)
        return 2
    missing = missing_dependencies(argv)
    for line in missing:
        print(f"benchmark preflight: missing {line}", file=sys.stderr)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
