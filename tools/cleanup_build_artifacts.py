#!/usr/bin/env python3
"""Safe local build-artifact retention and cleanup.

Never runs `rm -rf build`. Default mode is dry-run. Deletion requires --apply
and only touches allowlisted regenerable outputs under build/. Tracked
fingerprints, the frozen Act 1 package, music/docs, .git/, .godot/, and
unclassified paths are retained.

Usage:
    python3 tools/cleanup_build_artifacts.py
    python3 tools/cleanup_build_artifacts.py --dry-run
    python3 tools/cleanup_build_artifacts.py --apply
    python3 tools/cleanup_build_artifacts.py --json /tmp/cleanup-plan.json
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from fnmatch import fnmatch
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "docs" / "data" / "build_artifact_retention.json"
ACT1_MANIFEST_PATH = ROOT / "docs" / "data" / "act1_release_manifest.json"
FORBIDDEN_DELETE_RELATIVE = frozenset({"", ".", "build", "build/"})


@dataclass
class PathAction:
    path: str
    bytes: int
    reason: str
    kind: str


@dataclass
class CleanupPlan:
    mode: str
    root: str
    build_bytes_before: int
    local_bytes_planned: int
    clone_bytes_planned: int
    removable: list[PathAction] = field(default_factory=list)
    retained: list[PathAction] = field(default_factory=list)
    unclassified: list[PathAction] = field(default_factory=list)
    skipped_active_jobs: list[PathAction] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)
    retained_release_valid: bool = False
    retained_release_details: list[str] = field(default_factory=list)
    rebuild: dict[str, object] = field(default_factory=dict)
    local_bytes_removed: int = 0
    clone_bytes_removed: int = 0
    build_bytes_after: int | None = None
    json_report: str | None = None

    def to_dict(self) -> dict[str, object]:
        return {
            "mode": self.mode,
            "root": self.root,
            "build_bytes_before": self.build_bytes_before,
            "build_bytes_after": self.build_bytes_after,
            "local_bytes_planned": self.local_bytes_planned,
            "local_bytes_removed": self.local_bytes_removed,
            "clone_bytes_planned": self.clone_bytes_planned,
            "clone_bytes_removed": self.clone_bytes_removed,
            "retained_release_valid": self.retained_release_valid,
            "retained_release_details": self.retained_release_details,
            "rebuild": self.rebuild,
            "json_report": self.json_report,
            "removable": [action.__dict__ for action in self.removable],
            "retained": [action.__dict__ for action in self.retained],
            "unclassified": [action.__dict__ for action in self.unclassified],
            "skipped_active_jobs": [action.__dict__ for action in self.skipped_active_jobs],
            "errors": self.errors,
        }


def load_manifest(path: Path) -> dict[str, object]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("retention manifest root must be an object")
    return payload


def validate_manifest(manifest: dict[str, object]) -> list[str]:
    errors: list[str] = []
    policy = manifest.get("policy", {})
    if not isinstance(policy, dict) or policy.get("never_rm_rf_build") is not True:
        errors.append("retention policy must set never_rm_rf_build to true")
    if str(policy.get("scope", "")) != "build/":
        errors.append("retention policy scope must be build/")

    for field_name in ("tracked_release_fingerprints", "retained_paths", "retained_prefixes"):
        rows = manifest.get(field_name, [])
        if not isinstance(rows, list) or not rows:
            errors.append(f"retention manifest missing non-empty {field_name}")

    allowlisted = manifest.get("allowlisted_removable", [])
    if not isinstance(allowlisted, list) or not allowlisted:
        errors.append("retention manifest missing non-empty allowlisted_removable")
        return errors

    for index, row in enumerate(allowlisted, start=1):
        if not isinstance(row, dict):
            errors.append(f"allowlisted_removable entry {index} must be an object")
            continue
        selector = str(row.get("path") or row.get("glob") or "")
        relative = selector.replace("\\", "/").rstrip("/")
        if not relative.startswith("build/"):
            errors.append(f"allowlisted_removable entry {index} must stay under build/: {selector}")
        if relative in FORBIDDEN_DELETE_RELATIVE or relative == "build":
            errors.append(f"allowlisted_removable entry {index} refuses whole build/: {selector}")
        if ".." in Path(relative).parts:
            errors.append(f"allowlisted_removable entry {index} has unsafe path: {selector}")
    return errors


def tracked_paths(root: Path) -> set[str]:
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    return {os.fsdecode(item) for item in result.stdout.split(b"\0") if item}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def path_size(path: Path) -> int:
    if path.is_symlink() or path.is_file():
        try:
            return path.lstat().st_size
        except OSError:
            return 0
    if not path.is_dir():
        return 0
    total = 0
    for current, _dirs, files in os.walk(path, followlinks=False):
        for name in files:
            candidate = Path(current) / name
            try:
                total += candidate.lstat().st_size
            except OSError:
                continue
    return total


def posix_relative(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def is_under_prefix(relative: str, prefix: str) -> bool:
    normalized = prefix.rstrip("/") + "/"
    return relative == prefix.rstrip("/") or relative.startswith(normalized)


def resolve_inside_root(root: Path, relative: str) -> Path | None:
    candidate = (root / relative).resolve(strict=False)
    try:
        candidate.relative_to(root.resolve())
    except ValueError:
        return None
    return candidate


def path_is_busy(path: Path) -> bool:
    """Return True when lsof reports an open handle. Missing lsof is not busy."""
    try:
        result = subprocess.run(
            ["lsof", "-t", "--", str(path)],
            capture_output=True,
            text=True,
            timeout=8,
            check=False,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        return False
    return bool(result.stdout.strip())


def allowlist_matches(relative: str, row: dict[str, object]) -> bool:
    path_value = str(row.get("path") or "").replace("\\", "/").rstrip("/")
    glob_value = str(row.get("glob") or "")
    if path_value:
        return relative == path_value or is_under_prefix(relative, path_value)
    if glob_value:
        return fnmatch(relative, glob_value)
    return False


def matching_allowlist_reason(relative: str, manifest: dict[str, object]) -> str | None:
    for row in manifest.get("allowlisted_removable", []):
        if isinstance(row, dict) and allowlist_matches(relative, row):
            return str(row.get("reason") or "allowlisted regenerable output")
    return None


def is_retained(relative: str, manifest: dict[str, object], tracked: set[str]) -> bool:
    if relative in tracked:
        return True
    retained_paths = {str(item) for item in manifest.get("retained_paths", [])}
    if relative in retained_paths:
        return True
    for prefix in manifest.get("retained_prefixes", []):
        if is_under_prefix(relative, str(prefix)):
            return True
    return False


def is_protected_relative(relative: str, manifest: dict[str, object]) -> bool:
    for prefix in manifest.get("protected_prefixes", []):
        if is_under_prefix(relative, str(prefix)):
            return True
    return False


def classify_entry(
    relative: str,
    size_bytes: int,
    manifest: dict[str, object],
    tracked: set[str],
) -> tuple[str, str]:
    if is_protected_relative(relative, manifest):
        return "error", "protected prefix is outside the build cleanup scope"
    if is_retained(relative, manifest, tracked):
        return "retained", "retained release, fingerprint, or tracked path"
    reason = matching_allowlist_reason(relative, manifest)
    if reason is not None:
        return "removable", reason
    return "unclassified", "not on the removable allowlist"


def iter_build_entries(root: Path) -> list[Path]:
    build_dir = root / "build"
    if not build_dir.is_dir():
        return []
    return sorted(build_dir.iterdir(), key=lambda item: item.name.lower())


def verify_retained_release(
    root: Path,
    manifest: dict[str, object],
    *,
    require_package: bool = False,
) -> tuple[bool, list[str], list[str]]:
    details: list[str] = []
    errors: list[str] = []
    act1_path = root / "docs/data/act1_release_manifest.json"
    if not act1_path.is_file():
        return False, details, ["missing docs/data/act1_release_manifest.json"]
    act1 = json.loads(act1_path.read_text(encoding="utf-8"))
    expected_sha = str(act1["package_sha256"]).strip().lower()
    expected_bytes = int(act1["package_bytes"])
    fingerprint_rel = str(act1["package_fingerprint_path"])
    sidecar_rel = str(act1["package_sha256_sidecar"])
    package_rel = str(act1["package_path"])

    fingerprint_path = root / fingerprint_rel
    sidecar_path = root / sidecar_rel
    if not fingerprint_path.is_file():
        errors.append(f"missing fingerprint: {fingerprint_rel}")
    else:
        fingerprint = json.loads(fingerprint_path.read_text(encoding="utf-8"))
        if str(fingerprint.get("package_sha256", "")).strip().lower() != expected_sha:
            errors.append("package_fingerprint.json SHA does not match the Act 1 manifest")
        elif int(fingerprint.get("package_bytes", -1)) != expected_bytes:
            errors.append("package_fingerprint.json bytes do not match the Act 1 manifest")
        else:
            details.append(f"fingerprint bind OK {fingerprint_rel}")

    if not sidecar_path.is_file():
        errors.append(f"missing SHA sidecar: {sidecar_rel}")
    else:
        sidecar_sha = sidecar_path.read_text(encoding="utf-8").strip().split()[0].lower()
        if sidecar_sha != expected_sha:
            errors.append("PACKAGE_SHA256.txt does not match the Act 1 manifest")
        else:
            details.append(f"SHA sidecar bind OK {sidecar_rel}")

    missing_scripts = [
        str(script)
        for script in manifest.get("packaging_scripts", [])
        if not (root / str(script)).exists()
    ]
    if missing_scripts:
        errors.extend(f"missing packaging script: {script}" for script in missing_scripts)
    else:
        details.append("packaging scripts present")

    package_path = root / package_rel
    if package_path.is_file():
        actual_sha = sha256_file(package_path)
        actual_bytes = package_path.stat().st_size
        if actual_sha != expected_sha:
            errors.append(f"live {package_rel} SHA {actual_sha} != {expected_sha}")
        elif actual_bytes != expected_bytes:
            errors.append(f"live {package_rel} bytes {actual_bytes} != {expected_bytes}")
        else:
            details.append(f"live package bind OK {package_rel}")
    elif require_package:
        errors.append(f"missing accepted Act 1 package: {package_rel}")
    else:
        details.append(
            f"accepted package absent locally (clone/CI without the gitignored DMG): {package_rel}"
        )

    rebuild = manifest.get("rebuild", {})
    if not isinstance(rebuild, dict) or "rr" not in rebuild:
        errors.append("retention manifest missing rebuild.rr command")
    else:
        details.append("rebuild recipe recorded for the regenerable rr export")

    return not errors, details, errors


def build_plan(
    root: Path,
    manifest: dict[str, object],
    *,
    mode: str,
    require_package: bool = False,
) -> CleanupPlan:
    errors = validate_manifest(manifest)
    try:
        tracked = tracked_paths(root)
    except (subprocess.CalledProcessError, FileNotFoundError) as error:
        tracked = set()
        errors.append(f"could not inspect Git index: {error}")

    plan = CleanupPlan(
        mode=mode,
        root=str(root),
        build_bytes_before=path_size(root / "build"),
        local_bytes_planned=0,
        clone_bytes_planned=0,
        rebuild=dict(manifest.get("rebuild") or {}),
        errors=errors,
    )
    valid, details, release_errors = verify_retained_release(
        root, manifest, require_package=require_package
    )
    plan.retained_release_valid = valid
    plan.retained_release_details = details
    plan.errors.extend(release_errors)

    for entry in iter_build_entries(root):
        relative = posix_relative(entry, root)
        if relative.startswith("build/") is False:
            plan.errors.append(f"refusing path outside build/: {relative}")
            continue
        resolved = resolve_inside_root(root, relative)
        if resolved is None:
            plan.errors.append(f"path resolves outside repository root: {relative}")
            continue
        size_bytes = path_size(entry)
        kind, reason = classify_entry(relative, size_bytes, manifest, tracked)
        action = PathAction(path=relative, bytes=size_bytes, reason=reason, kind=kind)
        if kind == "error":
            plan.errors.append(f"{relative}: {reason}")
        elif kind == "retained":
            plan.retained.append(action)
        elif kind == "removable":
            if relative in tracked or any(is_under_prefix(item, relative) for item in tracked):
                plan.errors.append(f"refusing to delete tracked path: {relative}")
                plan.retained.append(PathAction(path=relative, bytes=size_bytes, reason="tracked", kind="retained"))
                continue
            if path_is_busy(entry):
                plan.skipped_active_jobs.append(action)
                continue
            plan.removable.append(action)
            plan.local_bytes_planned += size_bytes
        else:
            plan.unclassified.append(action)
    return plan


def delete_path(root: Path, relative: str) -> None:
    if relative in FORBIDDEN_DELETE_RELATIVE or relative.rstrip("/") == "build":
        raise RuntimeError(f"refusing to delete the whole build tree: {relative}")
    if not relative.startswith("build/"):
        raise RuntimeError(f"refusing to delete outside build/: {relative}")
    target = resolve_inside_root(root, relative)
    if target is None:
        raise RuntimeError(f"path resolves outside repository root: {relative}")
    if target.is_symlink() or target.is_file():
        target.unlink()
        return
    if target.is_dir():
        shutil.rmtree(target)
        return
    raise RuntimeError(f"cannot delete missing path: {relative}")


def apply_plan(root: Path, plan: CleanupPlan) -> CleanupPlan:
    if plan.errors:
        return plan
    removed = 0
    remaining: list[PathAction] = []
    for action in plan.removable:
        delete_path(root, action.path)
        removed += action.bytes
        remaining.append(action)
    plan.local_bytes_removed = removed
    plan.clone_bytes_removed = 0
    plan.build_bytes_after = path_size(root / "build")
    return plan


def format_bytes(size_bytes: int) -> str:
    units = [("GiB", 1024 ** 3), ("MiB", 1024 ** 2), ("KiB", 1024)]
    for name, unit in units:
        if size_bytes >= unit:
            return f"{size_bytes / unit:.1f} {name} ({size_bytes} bytes)"
    return f"{size_bytes} bytes"


def print_plan(plan: CleanupPlan) -> None:
    print(f"build artifact cleanup ({plan.mode})")
    print(f"local planned savings: {format_bytes(plan.local_bytes_planned)}")
    print(f"clone planned savings: {format_bytes(plan.clone_bytes_planned)}")
    print(f"local removed: {format_bytes(plan.local_bytes_removed)}")
    print(f"clone removed: {format_bytes(plan.clone_bytes_removed)}")
    print(f"retained release valid: {plan.retained_release_valid}")
    for detail in plan.retained_release_details:
        print(f"  retain: {detail}")
    if plan.retained:
        print("retained:")
        for action in plan.retained:
            print(f"  keep {action.path} ({format_bytes(action.bytes)})")
    if plan.removable:
        label = "would remove" if plan.mode == "dry-run" else "removed"
        print(f"{label}:")
        for action in plan.removable:
            print(f"  {action.path} ({format_bytes(action.bytes)}) - {action.reason}")
    if plan.unclassified:
        print("unclassified (kept):")
        for action in plan.unclassified:
            print(f"  {action.path} ({format_bytes(action.bytes)})")
    if plan.skipped_active_jobs:
        print("skipped active jobs:")
        for action in plan.skipped_active_jobs:
            print(f"  {action.path}")
    if plan.json_report:
        print(f"JSON report written: {Path(plan.json_report).name}")
    if plan.errors:
        print("errors:")
        for error in plan.errors:
            print(f"  - {error}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT, help="repository root")
    parser.add_argument("--manifest", type=Path, help="retention manifest path")
    parser.add_argument("--json", dest="json_path", type=Path, help="write a JSON report to this path")
    parser.add_argument("--apply", action="store_true", help="delete allowlisted outputs (default is dry-run)")
    parser.add_argument("--dry-run", action="store_true", help="plan only; leave the tree unchanged")
    parser.add_argument(
        "--require-package",
        action="store_true",
        help="fail when the frozen Act 1 DMG is not present locally",
    )
    args = parser.parse_args(argv)

    if args.apply and args.dry_run:
        print("choose either --apply or --dry-run, not both", file=sys.stderr)
        return 2

    root = args.root.resolve()
    manifest_path = args.manifest.resolve() if args.manifest else root / MANIFEST_PATH.relative_to(ROOT)
    try:
        manifest = load_manifest(manifest_path)
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"could not read retention manifest: {error}", file=sys.stderr)
        return 1

    mode = "apply" if args.apply else "dry-run"
    plan = build_plan(root, manifest, mode=mode, require_package=args.require_package)
    if args.json_path is not None:
        json_path = args.json_path
        if not json_path.is_absolute():
            json_path = Path.cwd() / json_path
        try:
            json_relative = json_path.resolve().relative_to(root)
            if str(json_relative).startswith("build/") or str(json_relative) == "build":
                print("refusing to write a JSON report under build/", file=sys.stderr)
                return 2
        except ValueError:
            pass
        plan.json_report = str(json_path)

    if mode == "apply":
        if plan.errors:
            print_plan(plan)
            return 1
        apply_plan(root, plan)
        valid, details, release_errors = verify_retained_release(
            root, manifest, require_package=args.require_package
        )
        plan.retained_release_valid = valid
        plan.retained_release_details = details
        plan.errors.extend(release_errors)
        if not valid:
            plan.errors.append("retained release verification failed after apply")

    if plan.json_report:
        report_path = Path(plan.json_report)
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(plan.to_dict(), indent=2) + "\n", encoding="utf-8")

    print_plan(plan)
    if plan.errors or not plan.retained_release_valid:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
