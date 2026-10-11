#!/usr/bin/env python3
"""Enforce the evidence-image retention contract from P0-186.

Checks the manifest, Godot exclusion, byte budgets, and optionally runs the
active acceptance verifiers that read report images.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "docs" / "data" / "evidence_image_retention.json"
RASTER_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp"}


def _load_manifest(path: Path) -> tuple[dict, list[str]]:
    errors: list[str] = []
    if not path.is_file():
        return {}, [f"missing retention manifest: {path.relative_to(ROOT)}"]
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return {}, [f"could not read retention manifest: {exc}"]
    if not isinstance(payload, dict):
        return {}, ["retention manifest root must be an object"]
    return payload, errors


def directory_raster_bytes(directory: Path) -> int:
    total = 0
    if not directory.is_dir():
        return 0
    for path in directory.rglob("*"):
        if path.is_file() and path.suffix.lower() in RASTER_SUFFIXES:
            total += path.stat().st_size
    return total


def validate(
    *,
    root: Path = ROOT,
    manifest_path: Path | None = None,
    run_acceptance: bool = False,
) -> list[str]:
    resolved_manifest = manifest_path or MANIFEST_PATH
    if not resolved_manifest.is_absolute():
        resolved_manifest = root / resolved_manifest
    manifest, errors = _load_manifest(resolved_manifest)
    if errors:
        return errors

    policy = manifest.get("policy", {})
    gdignore = policy.get("gdignore_path", "docs/reports/images/.gdignore")
    gdignore_path = root / gdignore
    if not gdignore_path.is_file():
        errors.append(f"missing Godot exclusion marker: {gdignore}")

    images_root = root / "docs" / "reports" / "images"
    if images_root.is_dir():
        import_sidecars = sorted(images_root.rglob("*.import"))
        if import_sidecars:
            sample = ", ".join(
                path.relative_to(root).as_posix() for path in import_sidecars[:3]
            )
            suffix = "..." if len(import_sidecars) > 3 else ""
            errors.append(
                f"docs/reports/images must not contain Godot import sidecars "
                f"({len(import_sidecars)} found: {sample}{suffix})"
            )

    for key in ("active_directories", "archived_directories"):
        rows = manifest.get(key, [])
        if not isinstance(rows, list) or not rows:
            errors.append(f"retention manifest missing non-empty {key}")
            continue
        for row_number, row in enumerate(rows, start=1):
            if not isinstance(row, dict):
                errors.append(f"{key}[{row_number}] must be an object")
                continue
            rel_path = row.get("path")
            if not isinstance(rel_path, str) or not rel_path:
                errors.append(f"{key}[{row_number}] missing path")
                continue
            if not (root / rel_path).is_dir():
                errors.append(f"missing evidence directory: {rel_path}")

    current_total = directory_raster_bytes(images_root)
    baseline = manifest.get("baseline", {})
    start_bytes = int(baseline.get("p0_186_start_docs_reports_images_bytes", 0))
    target_total = int(manifest.get("budget", {}).get("target_docs_reports_images_bytes", 0))
    if start_bytes and current_total >= start_bytes:
        errors.append(
            "docs/reports/images byte total did not drop from the P0-186 start baseline "
            f"({current_total} >= {start_bytes})"
        )
    if target_total and current_total > target_total:
        errors.append(
            f"docs/reports/images byte total {current_total} exceeds target budget {target_total}"
        )

    verifiers = manifest.get("active_acceptance_verifiers", [])
    if run_acceptance:
        if not isinstance(verifiers, list) or not verifiers:
            errors.append(
                "active_acceptance_verifiers must be a non-empty list when --run-acceptance is set"
            )
        else:
            for row_number, row in enumerate(verifiers, start=1):
                if not isinstance(row, dict):
                    errors.append(f"active_acceptance_verifiers[{row_number}] must be an object")
                    continue
                command = row.get("command")
                verifier_id = row.get("id", f"verifier_{row_number}")
                if not isinstance(command, list) or not command:
                    errors.append(f"{verifier_id}: missing command")
                    continue
                result = subprocess.run(command, cwd=root, check=False, capture_output=True, text=True)
                if result.returncode != 0:
                    detail = (result.stderr or result.stdout or "").strip().splitlines()
                    tail = detail[-1] if detail else f"exit {result.returncode}"
                    errors.append(f"{verifier_id}: acceptance verifier failed ({tail})")

    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--run-acceptance",
        action="store_true",
        help="also execute the active acceptance verifiers listed in the manifest",
    )
    parser.add_argument("--json", action="store_true", help="print manifest byte totals as JSON")
    args = parser.parse_args(argv)

    manifest, load_errors = _load_manifest(MANIFEST_PATH)
    images_root = ROOT / "docs" / "reports" / "images"
    current_total = directory_raster_bytes(images_root)
    if args.json:
        payload = {
            "docs_reports_images_bytes": current_total,
            "baseline": manifest.get("baseline", {}),
            "budget": manifest.get("budget", {}),
        }
        print(json.dumps(payload, indent=2, sort_keys=True))

    errors = load_errors + validate(root=ROOT, run_acceptance=args.run_acceptance)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(
        "EVIDENCE_IMAGE_RETENTION_PASS "
        f"(docs/reports/images={current_total} bytes)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
