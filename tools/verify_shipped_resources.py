#!/usr/bin/env python3
"""Verify rr/act1 export filters and optional actual PCK membership.

Always checks export_presets.cfg against docs/data/shipped_resource_manifest.json.
When --pck / --app / --dmg is given, also inventories that artifact and rejects
missing required paths or forbidden developer trees.

Usage:
    python3 tools/verify_shipped_resources.py
    python3 tools/verify_shipped_resources.py --pck build/inventory/rr.pck --preset rr
    python3 tools/verify_shipped_resources.py --check
    python3 tools/verify_shipped_resources.py --json build/inventory/shipped_check.json --pck game.pck

Exit codes: 0 = pass, 1 = contract or PCK failure.
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

import pck_inventory  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "docs" / "data" / "shipped_resource_manifest.json"
EXPORT_PRESETS_PATH = ROOT / "export_presets.cfg"


@dataclass
class ShippedCheckReport:
    valid: bool
    preset: str | None
    pck_path: str | None
    file_count: int | None
    total_bytes: int | None
    errors: list[str] = field(default_factory=list)
    details: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, object]:
        return {
            "valid": self.valid,
            "preset": self.preset,
            "pck_path": self.pck_path,
            "file_count": self.file_count,
            "total_bytes": self.total_bytes,
            "errors": self.errors,
            "details": self.details,
        }


def load_manifest(root: Path = ROOT) -> dict[str, object]:
    return json.loads((root / "docs/data/shipped_resource_manifest.json").read_text(encoding="utf-8"))


def split_filter(value: str) -> list[str]:
    return [part.strip() for part in value.split(",") if part.strip()]


def parse_export_presets(path: Path) -> dict[str, dict[str, str]]:
    presets: dict[str, dict[str, str]] = {}
    current_name = ""
    in_options = False
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if line.startswith("[preset.") and line.endswith("]"):
            in_options = ".options" in line
            if not in_options:
                current_name = ""
            continue
        if in_options or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip().strip('"')
        if key == "name":
            current_name = value
            presets[current_name] = {"name": value}
            continue
        if current_name:
            presets[current_name][key] = value
    return presets


def filter_excludes_path(pattern: str, keep: str) -> bool:
    """Return True when a Godot exclude glob would drop the runtime keep prefix."""
    keep_n = keep.replace("\\", "/").rstrip("/")
    pat = pattern.replace("\\", "/").strip()
    if not pat or not keep_n:
        return False
    if pat.endswith("/*"):
        prefix = pat[:-2].rstrip("/")
        return keep_n == prefix or keep_n.startswith(prefix + "/")
    if pat.endswith("*"):
        prefix = pat[:-1]
        return keep_n.startswith(prefix.rstrip("/")) or (prefix.rstrip("/") + "/").startswith(keep_n + "/")
    return keep_n == pat.rstrip("/") or keep_n.startswith(pat.rstrip("/") + "/")


def _path_has_prefix(path: str, prefix: str) -> bool:
    return path == prefix.rstrip("/") or path.startswith(
        prefix if prefix.endswith("/") else prefix + "/"
    )


def packed_resource_present(packed: set[str], required: str) -> bool:
    """Godot 4.7 stores compiled scenes/audio under .godot/imported and .remap sidecars."""
    required_path = pck_inventory.normalize_res_path(required)
    relative = required_path.removeprefix("res://")
    stem = Path(relative).name
    stem_no_ext = Path(relative).stem
    candidates = {
        required_path,
        required_path + ".import",
        required_path + ".remap",
        required_path + ".gdc",
    }
    if relative.endswith(".gd"):
        candidates.add("res://" + relative[:-3] + ".gdc")
        candidates.add(required_path + ".remap")
    if required_path in packed or any(candidate in packed for candidate in candidates):
        return True
    for path in packed:
        if path.endswith("/" + relative) or path.endswith("/" + relative + ".import"):
            return True
        if path.endswith("/" + relative + ".remap") or path.endswith("/" + relative + ".gdc"):
            return True
        if "/.godot/imported/" in path or path.startswith("res://.godot/imported/"):
            imported_name = Path(path).name
            if imported_name.startswith(stem + "-") or imported_name.startswith(stem_no_ext + "-"):
                return True
        if "/.godot/exported/" in path or path.startswith("res://.godot/exported/"):
            if f"-{stem}" in path or path.endswith("-" + stem):
                return True
    return False


def collect_preset_errors(
    presets: dict[str, dict[str, str]],
    manifest: dict[str, object],
) -> list[str]:
    errors: list[str] = []
    include_filter = str(manifest["include_filter"])
    export_filter = str(manifest["export_filter"])
    release_exclude = str(manifest["release_exclude_filter"])
    diagnostic_exclude = str(manifest["diagnostic_exclude_filter"])
    release_names = list(manifest["release_presets"])
    diagnostic_name = str(manifest["diagnostic_preset"])
    must_not_exclude = list(manifest["must_not_exclude"])

    for name in release_names:
        preset = presets.get(name)
        if preset is None:
            errors.append(f"missing export preset {name}")
            continue
        if preset.get("export_filter") != export_filter:
            errors.append(
                f"{name} export_filter is {preset.get('export_filter')!r}, expected {export_filter!r}"
            )
        if split_filter(preset.get("include_filter", "")) != split_filter(include_filter):
            errors.append(f"{name} include_filter does not match shipped_resource_manifest.json")
        if split_filter(preset.get("exclude_filter", "")) != split_filter(release_exclude):
            errors.append(f"{name} exclude_filter does not match the release exclude contract")
        excluded = split_filter(preset.get("exclude_filter", ""))
        for keep in must_not_exclude:
            for pattern in excluded:
                if filter_excludes_path(pattern, keep):
                    errors.append(f"{name} exclude_filter must not drop runtime path {keep}")

    diagnostic = presets.get(diagnostic_name)
    if diagnostic is None:
        errors.append(f"missing diagnostic export preset {diagnostic_name}")
    else:
        if diagnostic.get("export_filter") != export_filter:
            errors.append(
                f"{diagnostic_name} export_filter is {diagnostic.get('export_filter')!r}, expected {export_filter!r}"
            )
        if split_filter(diagnostic.get("include_filter", "")) != split_filter(include_filter):
            errors.append(
                f"{diagnostic_name} include_filter does not match shipped_resource_manifest.json"
            )
        if split_filter(diagnostic.get("exclude_filter", "")) != split_filter(diagnostic_exclude):
            errors.append(
                f"{diagnostic_name} exclude_filter does not match the diagnostic exclude contract"
            )
        excluded = split_filter(diagnostic.get("exclude_filter", ""))
        if "tests/*" in excluded:
            errors.append(f"{diagnostic_name} must keep tests/ for packaged diagnostic runs")
        if "tools/*" in excluded:
            errors.append(f"{diagnostic_name} must keep tools/ for packaged diagnostic runs")
    return errors


def collect_pck_errors(
    index: pck_inventory.PackIndex,
    manifest: dict[str, object],
    preset: str,
) -> list[str]:
    errors: list[str] = []
    packed = {item.path for item in index.files}
    required_paths = [pck_inventory.normalize_res_path(path) for path in manifest["required_paths"]]
    required_prefixes = list(manifest["required_prefixes"])
    forbidden = list(manifest["forbidden_prefixes"])
    forbidden_imported = list(manifest.get("forbidden_imported_substrings", []))
    diagnostic_allowed = set(manifest["diagnostic_allowed_prefixes"])
    if preset == str(manifest["diagnostic_preset"]):
        forbidden = [prefix for prefix in forbidden if prefix not in diagnostic_allowed]

    for path in required_paths:
        if not packed_resource_present(packed, path):
            errors.append(f"required path missing from PCK: {path}")
    for prefix in required_prefixes:
        if not any(_path_has_prefix(path, prefix) for path in packed):
            errors.append(f"required prefix missing from PCK: {prefix}")
    for prefix in forbidden:
        hits = sorted(path for path in packed if _path_has_prefix(path, prefix))
        if hits:
            errors.append(
                f"forbidden prefix {prefix} present in PCK ({len(hits)} files), e.g. {hits[0]}"
            )
    for needle in forbidden_imported:
        hits = sorted(
            path
            for path in packed
            if path.startswith("res://.godot/") and needle in path
        )
        if hits:
            errors.append(
                f"forbidden imported blob {needle} present in PCK ({len(hits)} files), e.g. {hits[0]}"
            )
    return errors


def build_report(
    root: Path = ROOT,
    pck_path: Path | None = None,
    app_path: Path | None = None,
    dmg_path: Path | None = None,
    preset: str | None = None,
) -> ShippedCheckReport:
    manifest = load_manifest(root)
    presets = parse_export_presets(root / "export_presets.cfg")
    errors = collect_preset_errors(presets, manifest)
    details = [
        f"checked export_presets.cfg against {MANIFEST_PATH.relative_to(ROOT).as_posix()}",
        f"presets: {', '.join(sorted(presets))}",
    ]
    report = ShippedCheckReport(
        valid=not errors,
        preset=preset,
        pck_path=None,
        file_count=None,
        total_bytes=None,
        errors=errors,
        details=details,
    )
    selected = [item for item in (pck_path, app_path, dmg_path) if item is not None]
    if not selected:
        report.valid = not report.errors
        return report
    if preset is None:
        report.errors.append("PCK inventory requires --preset rr, act1, or rr-diagnostic")
        report.valid = False
        return report

    mount_dir = None
    try:
        if pck_path is not None:
            resolved = pck_path
        elif app_path is not None:
            resolved = pck_inventory.find_pck_in_app(app_path)
        else:
            resolved, mount_dir = pck_inventory.find_pck_in_dmg(dmg_path)
        index = pck_inventory.parse_pck(resolved)
        report.pck_path = resolved.as_posix()
        report.file_count = index.file_count
        report.total_bytes = index.total_bytes
        report.details.append(
            f"PCK {resolved} files={index.file_count} packed_bytes={index.total_bytes}"
        )
        report.errors.extend(collect_pck_errors(index, manifest, preset))
    except (FileNotFoundError, ValueError, RuntimeError) as exc:
        report.errors.append(str(exc))
    finally:
        if mount_dir is not None:
            pck_inventory.detach_dmg(mount_dir)
    report.valid = not report.errors
    return report


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pck", type=Path, help="Inventory this .pck")
    parser.add_argument("--app", type=Path, help="Inventory the .pck inside a .app")
    parser.add_argument("--dmg", type=Path, help="Inventory the .pck inside a .dmg")
    parser.add_argument(
        "--preset",
        choices=("rr", "act1", "rr-diagnostic"),
        help="Preset whose forbidden/required contract to apply to the PCK",
    )
    parser.add_argument("--json", type=Path, help="Write the check report JSON")
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit 1 when the contract fails (default behavior)",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        report = build_report(
            ROOT,
            pck_path=args.pck,
            app_path=args.app,
            dmg_path=args.dmg,
            preset=args.preset,
        )
    except (OSError, json.JSONDecodeError, KeyError) as exc:
        print(str(exc), file=sys.stderr)
        return 1

    if args.json is not None:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(report.to_dict(), indent=2) + "\n", encoding="utf-8")
        print(f"JSON report written: {args.json.name}")

    if report.valid:
        print("shipped resource contract OK")
        for detail in report.details:
            print(f"  {detail}")
        return 0

    print("shipped resource contract failed:", file=sys.stderr)
    for error in report.errors:
        print(f"  - {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
