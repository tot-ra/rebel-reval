"""Slice platform manifest helpers for P3-012."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path

GDSCRIPT_CONST_RE = re.compile(
    r'const\s+(?P<name>[A-Z0-9_]+)\s*:=\s*"(?P<value>[^"]*)"'
)


@dataclass
class SlicePlatformReport:
    supported_platform_count: int = 0
    errors: list[str] = field(default_factory=list)

    @property
    def valid(self) -> bool:
        return not self.errors


def load_manifest(manifest_path: Path) -> dict:
    return json.loads(manifest_path.read_text(encoding="utf-8"))


def parse_godot_constants(model_path: Path) -> dict[str, str]:
    text = model_path.read_text(encoding="utf-8")
    return {
        match.group("name"): match.group("value")
        for match in GDSCRIPT_CONST_RE.finditer(text)
    }


def verify_manifest_matches_model(root: Path, manifest_path: Path) -> SlicePlatformReport:
    manifest = load_manifest(manifest_path)
    report = SlicePlatformReport(
        supported_platform_count=len(manifest.get("supported_platforms", [])),
    )

    model_path = root / str(manifest["godot_model"])
    if not model_path.is_file():
        report.errors.append(f"missing godot model: {model_path}")
        return report

    constants = parse_godot_constants(model_path)
    pairs = {
        "export_preset_name": "EXPORT_PRESET_NAME",
        "export_preset_platform": "EXPORT_PRESET_PLATFORM",
        "export_architecture": "EXPORT_ARCHITECTURE",
        "packaged_smoke_user_argument": "PACKAGED_SMOKE_USER_ARGUMENT",
        "verify_script": "VERIFY_SCRIPT_PATH",
    }
    for manifest_key, constant_name in pairs.items():
        expected = constants.get(constant_name, "")
        actual = str(manifest.get(manifest_key, ""))
        if actual != expected:
            report.errors.append(
                f"{manifest_key} mismatch: manifest {actual!r}, model {expected!r}"
            )

    smoke_script = str(manifest.get("packaged_smoke_script", ""))
    model_smoke = constants.get("PACKAGED_SMOKE_SCRIPT", "").removeprefix("res://")
    if smoke_script != model_smoke:
        report.errors.append(
            f"packaged_smoke_script mismatch: manifest {smoke_script!r}, model {model_smoke!r}"
        )

    expected_count = int(manifest.get("supported_platform_count", 0))
    actual_count = len(manifest.get("supported_platforms", []))
    if expected_count != actual_count:
        report.errors.append(
            f"supported_platform_count mismatch: expected {expected_count}, got {actual_count}"
        )

    maintainer_report = root / str(manifest.get("maintainer_report", ""))
    if not maintainer_report.is_file():
        report.errors.append(f"missing maintainer report: {maintainer_report}")

    verify_script = root / str(manifest.get("verify_script", ""))
    if not verify_script.is_file():
        report.errors.append(f"missing verify script: {verify_script}")

    smoke_script_path = root / smoke_script
    if not smoke_script_path.is_file():
        report.errors.append(f"missing packaged smoke script: {smoke_script_path}")

    export_presets = root / "export_presets.cfg"
    if not export_presets.is_file():
        report.errors.append("missing export_presets.cfg")
    else:
        content = export_presets.read_text(encoding="utf-8")
        preset_name = str(manifest.get("export_preset_name", ""))
        preset_platform = str(manifest.get("export_preset_platform", ""))
        architecture = str(manifest.get("export_architecture", ""))
        if f'name="{preset_name}"' not in content:
            report.errors.append(f'export preset name "{preset_name}" missing from export_presets.cfg')
        if f'platform="{preset_platform}"' not in content:
            report.errors.append(
                f'export preset platform "{preset_platform}" missing from export_presets.cfg'
            )
        if f'binary_format/architecture="{architecture}"' not in content:
            report.errors.append(
                f'universal architecture "{architecture}" missing from export_presets.cfg'
            )

    godot_version = root / ".godot-version"
    if not godot_version.is_file() or not godot_version.read_text(encoding="utf-8").strip():
        report.errors.append("missing or empty .godot-version pin")

    return report


def format_report(report: SlicePlatformReport) -> str:
    lines = [
        "Slice platform report (P3-012)",
        f"  supported platforms: {report.supported_platform_count}",
    ]
    if report.errors:
        lines.append("  errors:")
        for error in report.errors:
            lines.append(f"    - {error}")
    else:
        lines.append("  status: manifest and export contract are valid")
    return "\n".join(lines)
