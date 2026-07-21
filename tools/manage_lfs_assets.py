#!/usr/bin/env python3
"""Verify and query the Git LFS asset manifest created by TODO P0-070."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "docs" / "lfs_assets.json"
POINTER_HEADER = b"version https://git-lfs.github.com/spec/v1\n"
REQUIRED_OBJECT_FIELDS = (
    "path",
    "size_bytes",
    "sha256",
    "lfs_oid",
    "owner",
    "license",
    "approval",
    "source_reference",
    "scope",
)
VALID_SCOPES = frozenset({"runtime", "archive", "research", "narrative"})


@dataclass(frozen=True)
class LfsAsset:
    path: str
    size_bytes: int
    sha256: str
    lfs_oid: str
    owner: str
    license: str
    approval: str
    source_reference: str
    scope: str


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def pointer_payload(asset: LfsAsset) -> bytes:
    return (
        POINTER_HEADER
        + f"oid {asset.lfs_oid}\nsize {asset.size_bytes}\n".encode("utf-8")
    )


def is_pointer_file(path: Path) -> bool:
    try:
        with path.open("rb") as handle:
            return handle.read(len(POINTER_HEADER)) == POINTER_HEADER
    except OSError:
        return False


def read_manifest(path: Path) -> tuple[dict[str, Any], list[LfsAsset], list[str]]:
    errors: list[str] = []
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return {}, [], [f"could not read LFS manifest {path}: {error}"]
    if not isinstance(payload, dict):
        return {}, [], ["LFS manifest root must be an object"]
    if payload.get("version") != 1:
        errors.append("LFS manifest version must be 1")
    for field in ("repository", "remote", "storage", "objects"):
        if field not in payload:
            errors.append(f"LFS manifest missing top-level field: {field}")
    rows = payload.get("objects", [])
    if not isinstance(rows, list):
        return payload, [], [*errors, "LFS manifest objects must be an array"]

    assets: list[LfsAsset] = []
    seen: set[str] = set()
    for number, row in enumerate(rows, start=1):
        if not isinstance(row, dict):
            errors.append(f"LFS object {number} must be an object")
            continue
        missing = [field for field in REQUIRED_OBJECT_FIELDS if row.get(field) in (None, "")]
        if missing:
            errors.append(f"LFS object {number} missing: {', '.join(missing)}")
            continue
        relative = Path(str(row["path"]))
        path_value = relative.as_posix()
        if relative.is_absolute() or ".." in relative.parts:
            errors.append(f"LFS object {number} has unsafe path: {path_value}")
            continue
        if path_value in seen:
            errors.append(f"duplicate LFS object path: {path_value}")
            continue
        seen.add(path_value)
        try:
            size_bytes = int(row["size_bytes"])
        except (TypeError, ValueError):
            errors.append(f"LFS object {number} has invalid size: {row['size_bytes']}")
            continue
        sha256 = str(row["sha256"]).lower()
        if len(sha256) != 64 or any(character not in "0123456789abcdef" for character in sha256):
            errors.append(f"LFS object {number} has invalid SHA-256: {row['sha256']}")
            continue
        lfs_oid = str(row["lfs_oid"])
        if lfs_oid != f"sha256:{sha256}":
            errors.append(f"LFS object {path_value} OID does not match SHA-256")
            continue
        scope = str(row["scope"])
        if scope not in VALID_SCOPES:
            errors.append(f"LFS object {path_value} has invalid scope: {scope}")
            continue
        assets.append(
            LfsAsset(
                path=path_value,
                size_bytes=size_bytes,
                sha256=sha256,
                lfs_oid=lfs_oid,
                owner=str(row["owner"]).strip(),
                license=str(row["license"]).strip(),
                approval=str(row["approval"]).strip(),
                source_reference=str(row["source_reference"]).strip(),
                scope=scope,
            )
        )
    return payload, assets, errors


def tracked_paths(root: Path) -> list[str]:
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


def index_blob(root: Path, path: str) -> bytes | None:
    result = subprocess.run(
        ["git", "show", f":{path}"],
        cwd=root,
        check=False,
        capture_output=True,
    )
    return result.stdout if result.returncode == 0 else None


def selected_assets(assets: list[LfsAsset], scope: str) -> list[LfsAsset]:
    if scope == "all":
        return assets
    return [asset for asset in assets if asset.scope == scope]


def validate(
    root: Path = ROOT,
    manifest_path: Path = DEFAULT_MANIFEST,
    scope: str = "all",
    require_materialized: bool = False,
) -> list[str]:
    payload, assets, errors = read_manifest(manifest_path)
    if errors:
        return errors
    if payload.get("storage") != "github-lfs":
        errors.append("LFS manifest storage must be github-lfs")
    if payload.get("remote") != "origin":
        errors.append("LFS manifest remote must be origin")

    try:
        tracked = tracked_paths(root)
    except (subprocess.CalledProcessError, FileNotFoundError) as error:
        return [*errors, f"could not inspect Git index: {error}"]
    tracked_set = set(tracked)
    manifest_paths = {asset.path for asset in assets}
    actual_lfs_paths = {path for path in tracked if is_lfs_tracked(root, path)}
    for path in sorted(actual_lfs_paths - manifest_paths):
        errors.append(f"LFS-tracked path missing from manifest: {path}")
    for path in sorted(manifest_paths - actual_lfs_paths):
        errors.append(f"manifest path is not LFS-tracked: {path}")

    for asset in selected_assets(assets, scope):
        if asset.path not in tracked_set:
            errors.append(f"manifest path is not tracked: {asset.path}")
            continue
        blob = index_blob(root, asset.path)
        if blob is None:
            errors.append(f"could not read indexed LFS pointer: {asset.path}")
        elif blob != pointer_payload(asset):
            errors.append(f"indexed content is not the expected LFS pointer: {asset.path}")

        absolute = root / asset.path
        if not absolute.is_file():
            if require_materialized:
                errors.append(f"required LFS object is missing from the worktree: {asset.path}")
            continue
        if is_pointer_file(absolute):
            if require_materialized:
                errors.append(f"required LFS object is not materialized: {asset.path}")
            continue
        size_bytes = absolute.stat().st_size
        if size_bytes != asset.size_bytes:
            errors.append(
                f"materialized size mismatch for {asset.path}: expected {asset.size_bytes}, found {size_bytes}"
            )
            continue
        actual_sha256 = sha256_file(absolute)
        if actual_sha256 != asset.sha256:
            errors.append(
                f"materialized SHA-256 mismatch for {asset.path}: expected {asset.sha256}, found {actual_sha256}"
            )
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("verify", "paths"), nargs="?", default="verify")
    parser.add_argument("--root", type=Path, default=ROOT, help="repository root to inspect")
    parser.add_argument("--manifest", type=Path, help="LFS manifest path")
    parser.add_argument("--scope", choices=("all", *sorted(VALID_SCOPES)), default="all")
    parser.add_argument("--require-materialized", action="store_true")
    parser.add_argument("--separator", choices=("newline", "comma"), default="newline")
    args = parser.parse_args(argv)

    root = args.root.resolve()
    manifest_path = args.manifest.resolve() if args.manifest else root / "docs/lfs_assets.json"
    _, assets, read_errors = read_manifest(manifest_path)
    if args.command == "paths":
        if read_errors:
            print("\n".join(read_errors), file=sys.stderr)
            return 1
        separator = "\n" if args.separator == "newline" else ","
        print(separator.join(asset.path for asset in selected_assets(assets, args.scope)))
        return 0

    errors = validate(root, manifest_path, args.scope, args.require_materialized)
    if errors:
        print("Git LFS asset verification failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    selected = selected_assets(assets, args.scope)
    total_bytes = sum(asset.size_bytes for asset in selected)
    materialized = " materialized" if args.require_materialized else ""
    print(f"Git LFS asset verification passed ({len(selected)}{materialized} objects, {total_bytes} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
