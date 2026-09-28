#!/usr/bin/env python3
"""Enforce the P0-183 runtime GLB byte and triangle budget.

Scans ``assets/**/*.glb``. Named classes cover the Sacred Grove oak and the
shared character LOD set; every other runtime GLB uses the default cap, which
stays below the 10 MiB LFS line. Git LFS pointer files are checked against the
pointer size field so CI can fail an oversized object before it is materialized.

Usage:
    python3 tools/verify_runtime_glb_budget.py
    python3 tools/verify_runtime_glb_budget.py --dump
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
TOOLS = Path(__file__).resolve().parent
MANIFEST_PATH = ROOT / "docs" / "data" / "runtime_glb_budget.json"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from character_fidelity_tiers import inspect_glb  # noqa: E402
from verify_runtime_audio_budget import parse_lfs_pointer  # noqa: E402


def load_manifest(path: Path) -> tuple[dict[str, Any], list[str]]:
    if not path.is_file():
        return {}, [f"missing runtime GLB budget: {path}"]
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return {}, [f"could not read runtime GLB budget: {exc}"]
    if not isinstance(payload, dict):
        return {}, ["runtime GLB budget root must be an object"]
    return payload, []


def iter_glb_files(root: Path, roots: list[str], suffixes: set[str]) -> list[Path]:
    files: list[Path] = []
    for name in roots:
        folder = root / name
        if not folder.is_dir():
            continue
        for path in folder.rglob("*"):
            if path.is_file() and path.suffix.lower() in suffixes:
                files.append(path)
    return sorted(files)


def _glob_matches(rel: str, pattern: str) -> bool:
    normalized = pattern.replace("\\", "/")
    if "**" in normalized:
        prefix, _, suffix = normalized.partition("/**/")
        if not rel.startswith(prefix.rstrip("/") + "/") and rel != prefix.rstrip("/"):
            return False
        return fnmatch.fnmatch(rel, suffix) or fnmatch.fnmatch(Path(rel).name, suffix)
    return fnmatch.fnmatch(rel, normalized)


def match_rule(rel: str, rules: list[dict[str, Any]]) -> dict[str, Any] | None:
    for rule in rules:
        paths = rule.get("paths") or []
        if rel in paths:
            return rule
        glob_pattern = rule.get("glob")
        if isinstance(glob_pattern, str) and _glob_matches(rel, glob_pattern):
            return rule
    return None


def resolve_manifest(root: Path, manifest_path: Path | None) -> Path:
    if manifest_path is None:
        candidate = root / "docs" / "data" / "runtime_glb_budget.json"
        return candidate if candidate.is_file() else MANIFEST_PATH
    if manifest_path.is_absolute():
        return manifest_path
    return root / manifest_path


def file_size_bytes(path: Path) -> int:
    blob = path.read_bytes()[:256]
    pointer = parse_lfs_pointer(blob)
    if pointer is not None:
        return pointer[1]
    return path.stat().st_size


def inspect_runtime_glb(path: Path) -> dict[str, int]:
    blob = path.read_bytes()[:256]
    if parse_lfs_pointer(blob) is not None:
        return {"triangles": -1, "max_texture_px": 0, "lfs_pointer": 1}
    stats = inspect_glb(path)
    stats["lfs_pointer"] = 0
    return stats


def validate(
    *,
    root: Path = ROOT,
    manifest_path: Path | None = None,
) -> list[str]:
    resolved = resolve_manifest(root, manifest_path)
    manifest, errors = load_manifest(resolved)
    if errors:
        return errors

    policy = manifest.get("policy", {})
    roots = policy.get("roots", ["assets"])
    suffixes = {str(item).lower() for item in policy.get("suffixes", [".glb"])}
    rules = manifest.get("rules")
    if not isinstance(roots, list) or not roots:
        return ["runtime GLB budget policy.roots must be a non-empty array"]
    if not isinstance(rules, list) or not rules:
        return ["runtime GLB budget rules must be a non-empty array"]

    exceptions = {
        str(row.get("path", ""))
        for row in manifest.get("exceptions", [])
        if isinstance(row, dict)
    }
    files = iter_glb_files(root, [str(item) for item in roots], suffixes)
    for path in files:
        rel = path.relative_to(root).as_posix()
        if rel in exceptions:
            continue
        rule = match_rule(rel, rules)
        if rule is None:
            errors.append(f"{rel}: no budget rule for this path")
            continue
        if rule.get("skip"):
            continue
        size_bytes = file_size_bytes(path)
        max_file_bytes = int(rule["max_file_bytes"])
        if size_bytes > max_file_bytes:
            errors.append(
                f"{rel}: {size_bytes} bytes exceeds {rule['id']} cap {max_file_bytes}"
            )
        max_triangles = rule.get("max_triangles")
        if max_triangles is None:
            continue
        try:
            stats = inspect_runtime_glb(path)
        except (OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
            errors.append(f"{rel}: could not inspect GLB ({exc})")
            continue
        if stats.get("lfs_pointer"):
            continue
        triangles = int(stats["triangles"])
        if triangles > int(max_triangles):
            errors.append(
                f"{rel}: {triangles} triangles exceeds {rule['id']} cap {max_triangles}"
            )
    return errors


def dump_inventory(
    *,
    root: Path = ROOT,
    manifest_path: Path | None = None,
) -> list[dict[str, Any]]:
    resolved = resolve_manifest(root, manifest_path)
    manifest, errors = load_manifest(resolved)
    if errors:
        raise RuntimeError("; ".join(errors))
    policy = manifest.get("policy", {})
    roots = [str(item) for item in policy.get("roots", ["assets"])]
    suffixes = {str(item).lower() for item in policy.get("suffixes", [".glb"])}
    rules = list(manifest.get("rules") or [])
    rows: list[dict[str, Any]] = []
    for path in iter_glb_files(root, roots, suffixes):
        rel = path.relative_to(root).as_posix()
        rule = match_rule(rel, rules) or {}
        size_bytes = file_size_bytes(path)
        triangles = -1
        try:
            stats = inspect_runtime_glb(path)
            triangles = int(stats.get("triangles", -1))
        except (OSError, ValueError, KeyError, json.JSONDecodeError):
            pass
        rows.append(
            {
                "path": rel,
                "bytes": size_bytes,
                "triangles": triangles,
                "rule": rule.get("id", ""),
                "skip": bool(rule.get("skip")),
            }
        )
    rows.sort(key=lambda item: int(item["bytes"]), reverse=True)
    return rows


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--manifest", type=Path)
    parser.add_argument(
        "--dump",
        action="store_true",
        help="print path, bytes, triangles, and matched rule; do not fail",
    )
    args = parser.parse_args(argv)
    if args.dump:
        for row in dump_inventory(root=args.root, manifest_path=args.manifest):
            print(
                f"{row['bytes']:10d}  tris={row['triangles']:7d}  "
                f"{row['rule'] or '-':22s}  {row['path']}"
            )
        return 0
    errors = validate(root=args.root, manifest_path=args.manifest)
    if errors:
        print("runtime GLB budget verification failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print("runtime GLB budget verification passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
