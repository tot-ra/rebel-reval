#!/usr/bin/env python3
"""Require a prompt sidecar for every generated material plate.

AI-generated runtime textures cannot be iterated if the prompt lives only in a
dated report. Each family directory under assets/materials/pbr/ that ships a
PNG must keep prompt.json with the full generation prompt.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBR_DIR = ROOT / "assets" / "materials" / "pbr"
REQUIRED_KEYS = ("id", "family", "prompt", "target")
SKIP_DIR_NAMES = {"building_variants"}


def _family_dirs() -> list[Path]:
    if not PBR_DIR.is_dir():
        return []
    return sorted(
        path
        for path in PBR_DIR.iterdir()
        if path.is_dir() and path.name not in SKIP_DIR_NAMES
    )


def validate(root: Path | None = None) -> list[str]:
    base = (root or ROOT) / "assets" / "materials" / "pbr"
    errors: list[str] = []
    if not base.is_dir():
        return [f"missing PBR directory: {base}"]

    for family_dir in sorted(path for path in base.iterdir() if path.is_dir()):
        if family_dir.name in SKIP_DIR_NAMES:
            continue
        pngs = sorted(family_dir.glob("*.png"))
        if not pngs:
            continue
        prompt_path = family_dir / "prompt.json"
        rel_prompt = prompt_path.relative_to(root or ROOT)
        if not prompt_path.is_file():
            errors.append(f"missing prompt sidecar: {rel_prompt}")
            continue
        try:
            payload = json.loads(prompt_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errors.append(f"{rel_prompt}: invalid JSON ({exc})")
            continue
        if not isinstance(payload, dict):
            errors.append(f"{rel_prompt}: expected a JSON object")
            continue
        for key in REQUIRED_KEYS:
            value = payload.get(key)
            if not isinstance(value, str) or not value.strip():
                errors.append(f"{rel_prompt}: missing non-empty '{key}'")
        target = str(payload.get("target") or "")
        if target and not (root or ROOT).joinpath(target).is_file():
            errors.append(f"{rel_prompt}: target does not exist: {target}")
    return errors


def main() -> int:
    errors = validate()
    if errors:
        print("Texture prompt verification failed:")
        for error in errors:
            print(f"  - {error}")
        return 1
    print("Texture prompt verification passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
