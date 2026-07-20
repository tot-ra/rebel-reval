#!/usr/bin/env python3
"""Enforce the repository storage policy recorded by TODO P0-064."""

from __future__ import annotations

import argparse
import json
import hashlib
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXCEPTIONS = ROOT / "docs" / "storage_binary_exceptions.json"
LARGE_FILE_BYTES = 10 * 1024 * 1024
REQUIRED_FIELDS = ("path", "size_bytes", "sha256", "owner", "rationale", "follow_up")
FORBIDDEN_EXACT_PATHS = frozenset({"bin/rr.zip"})
FORBIDDEN_PARTS = frozenset({"__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache"})
FORBIDDEN_SUFFIXES = frozenset({".pyc", ".pyo"})


@dataclass(frozen=True)
class BinaryException:
    path: str
    size_bytes: int
    sha256: str
    owner: str
    rationale: str
    follow_up: str


def tracked_paths(root: Path) -> list[str]:
    """Read the Git index so ignored files in a developer tree do not affect CI."""
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    return sorted(os.fsdecode(item) for item in result.stdout.split(b"\0") if item)


def is_lfs_tracked(root: Path, path: str) -> bool:
    result = subprocess.run(
        ["git", "check-attr", "-z", "filter", "--", path],
        cwd=root,
        check=False,
        capture_output=True,
    )
    fields = result.stdout.split(b"\0")
    return result.returncode == 0 and len(fields) >= 3 and fields[2] == b"lfs"


def read_exceptions(path: Path) -> tuple[dict[str, BinaryException], list[str]]:
    errors: list[str] = []
    if not path.is_file():
        return {}, [f"missing exception manifest: {path}"]

    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return {}, [f"could not read exception manifest: {error}"]
    if not isinstance(payload, list):
        return {}, ["exception manifest root must be a JSON array"]

    exceptions: dict[str, BinaryException] = {}
    for entry_number, row in enumerate(payload, start=1):
        if not isinstance(row, dict):
            errors.append(f"exception entry {entry_number} must be an object")
            continue
        values = {field: row.get(field) for field in REQUIRED_FIELDS}
        missing = [field for field, value in values.items() if value is None or value == ""]
        if missing:
            errors.append(f"exception entry {entry_number} missing: {', '.join(missing)}")
            continue

        path_value = str(values["path"]).strip()
        relative = Path(path_value)
        if relative.is_absolute() or ".." in relative.parts:
            errors.append(f"exception entry {entry_number} has unsafe path: {path_value}")
            continue
        if path_value in exceptions:
            errors.append(f"duplicate binary exception: {path_value}")
            continue

        try:
            size_bytes = int(values["size_bytes"])
        except (TypeError, ValueError):
            errors.append(f"exception entry {entry_number} has invalid size: {values['size_bytes']}")
            continue
        sha256 = str(values["sha256"]).strip().lower()
        if len(sha256) != 64 or any(character not in "0123456789abcdef" for character in sha256):
            errors.append(f"exception entry {entry_number} has invalid SHA-256: {values['sha256']}")
            continue

        exceptions[path_value] = BinaryException(
            path=path_value,
            size_bytes=size_bytes,
            sha256=sha256,
            owner=str(values["owner"]).strip(),
            rationale=str(values["rationale"]).strip(),
            follow_up=str(values["follow_up"]).strip(),
        )
    return exceptions, errors


def is_forbidden_tracked_path(path: str) -> bool:
    relative = Path(path)
    if path in FORBIDDEN_EXACT_PATHS or relative.parts[:1] in {("bin",), ("build",)}:
        return True
    return bool(FORBIDDEN_PARTS.intersection(relative.parts)) or relative.suffix.lower() in FORBIDDEN_SUFFIXES


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def validate(root: Path = ROOT, exceptions_path: Path | None = None) -> list[str]:
    manifest_path = exceptions_path or root / EXCEPTIONS.relative_to(ROOT)
    exceptions, errors = read_exceptions(manifest_path)

    try:
        tracked = tracked_paths(root)
    except (subprocess.CalledProcessError, FileNotFoundError) as error:
        return [*errors, f"could not inspect Git index: {error}"]

    tracked_set = set(tracked)
    for path in tracked:
        if is_forbidden_tracked_path(path):
            errors.append(f"generated or release path is tracked: {path}")

    observed_large: set[str] = set()
    for path in tracked:
        absolute = root / path
        # The index is authoritative. An unrelated unstaged deletion in a developer
        # tree must not make this policy check fail; clean CI still has every blob.
        if not absolute.is_file():
            continue
        size_bytes = absolute.stat().st_size
        if size_bytes < LARGE_FILE_BYTES or is_lfs_tracked(root, path):
            continue

        observed_large.add(path)
        exception = exceptions.get(path)
        if exception is None:
            errors.append(f"standard-Git file is at least 10 MiB without an exception: {path} ({size_bytes} bytes)")
            continue
        if exception.size_bytes != size_bytes:
            errors.append(
                f"binary exception size mismatch for {path}: expected {exception.size_bytes}, found {size_bytes}"
            )
            continue
        actual_sha256 = sha256_file(absolute)
        if exception.sha256 != actual_sha256:
            errors.append(
                f"binary exception SHA-256 mismatch for {path}: expected {exception.sha256}, found {actual_sha256}"
            )

    for path in sorted(set(exceptions) - observed_large):
        if path not in tracked_set:
            errors.append(f"stale binary exception is not tracked: {path}")
        else:
            errors.append(f"stale binary exception is below 10 MiB: {path}")

    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT, help="repository root to inspect")
    parser.add_argument("--exceptions", type=Path, help="exception manifest path")
    args = parser.parse_args(argv)

    root = args.root.resolve()
    exceptions_path = args.exceptions.resolve() if args.exceptions else root / "docs/storage_binary_exceptions.json"
    errors = validate(root, exceptions_path)
    if errors:
        print("storage hygiene verification failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    exception_count = len(read_exceptions(exceptions_path)[0])
    print(f"storage hygiene verification passed ({exception_count} temporary large-binary exceptions)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
