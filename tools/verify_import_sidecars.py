#!/usr/bin/env python3
"""R-1453: validate Godot import sidecar pairs in the Git index, not local caches."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path, PurePosixPath
from typing import Iterable

ROOT = Path(__file__).resolve().parents[1]
# Explicit Godot source-import formats. CSV manifests and native resources
# (.tscn/.tres/.gd/.gdshader) do not require .import metadata in this repository.
IMPORTABLE_SUFFIXES = frozenset({
    ".png", ".jpg", ".jpeg", ".webp", ".svg", ".bmp", ".tga", ".hdr", ".exr",
    ".ttf", ".otf", ".woff", ".woff2", ".pfb", ".pfm",
    ".mp3", ".ogg", ".wav", ".glb", ".gltf", ".obj", ".blend", ".fbx", ".dae",
})


def tracked_paths(root: Path) -> set[str]:
    """Include staged additions; exclude staged deletions and untracked files."""
    result = subprocess.run(
        ["git", "ls-files", "--cached", "-z"], cwd=root,
        check=True, capture_output=True,
    )
    return {os.fsdecode(item) for item in result.stdout.split(b"\0") if item}


def validate_paths(paths: Iterable[str]) -> list[str]:
    """Validate an index inventory without reading source media or sidecars."""
    inventory = set(paths)
    ignored_dirs = {
        PurePosixPath(path).parent
        for path in inventory if PurePosixPath(path).name == ".gdignore"
    }
    errors: list[str] = []
    for path in sorted(inventory):
        source = PurePosixPath(path)
        # An ignored directory does not make dangling tracked metadata valid.
        if path.endswith(".import"):
            if path[:-7] not in inventory:
                errors.append(f"orphan import sidecar: {path} (source not in Git index)")
        elif source.suffix.lower() in IMPORTABLE_SUFFIXES:
            if any(parent in ignored_dirs for parent in source.parents):
                continue
            if path + ".import" not in inventory:
                errors.append(f"missing import sidecar: {path}.import")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT, help="Git checkout to validate")
    args = parser.parse_args(argv)
    try:
        paths = tracked_paths(args.root)
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"Import sidecar check could not read Git index: {error}", file=sys.stderr)
        return 2
    errors = validate_paths(paths)
    if errors:
        print(f"Import sidecar check failed ({len(errors)} issue(s)):", file=sys.stderr)
        for error in errors:
            print(f"  {error}", file=sys.stderr)
        print(
            "Stage source and .import together. For intentionally non-runtime media, "
            "stage an ancestor .gdignore. Remove orphan metadata with its source.",
            file=sys.stderr,
        )
        return 1
    print(f"Import sidecar check passed ({len(paths)} indexed files).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
