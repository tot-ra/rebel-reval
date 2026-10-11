#!/usr/bin/env python3
"""Move flat assets/props/environment/* into per-model subfolders and fix references."""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ENVIRONMENT = ROOT / "assets" / "props" / "environment"

MODELS = [
    "sacred_grove_ancient_oak",
    "root_cellar_mound",
]

REFERENCE_ROOTS = [
    ROOT / "assets" / "SOURCES.csv",
    ROOT / "scripts" / "map" / "view3d",
    ROOT / "tests",
    ROOT / "tools",
    ROOT / "generated" / "blender",
    ROOT / "docs",
]


def rewrite_text(text: str) -> tuple[str, int]:
    changes = 0
    for model in MODELS:
        for prefix in ("res://assets/props/environment/", "assets/props/environment/"):
            for old_suffix, new_suffix in (
                (f"{model}.", f"{model}/{model}."),
                (f"{model}_", f"{model}/{model}_"),
            ):
                old = prefix + old_suffix
                new = prefix + new_suffix
                if old in text:
                    count = text.count(old)
                    text = text.replace(old, new)
                    changes += count
    return text, changes


def git_mv_models() -> None:
    for model in MODELS:
        dest = ENVIRONMENT / model
        dest.mkdir(parents=True, exist_ok=True)
        for path in sorted(ENVIRONMENT.glob(f"{model}*")):
            if path.is_dir():
                continue
            target = dest / path.name
            if target.exists():
                continue
            subprocess.run(
                ["git", "mv", str(path), str(target)],
                cwd=ROOT,
                check=True,
            )


def fix_import_sidecars() -> None:
    for import_path in ENVIRONMENT.glob("*/*.import"):
        text = import_path.read_text(encoding="utf-8")
        model = import_path.parent.name
        basename = import_path.name.removesuffix(".import")
        expected = f'source_file="res://assets/props/environment/{model}/{basename}"'
        if expected in text:
            continue
        text2, count = re.subn(
            r'source_file="res://assets/props/environment/[^"]+"',
            expected,
            text,
            count=1,
        )
        if count:
            import_path.write_text(text2, encoding="utf-8")


def fix_generator_output_paths() -> None:
    for model in MODELS:
        script = ROOT / "tools" / f"generate_{model}.py"
        if not script.is_file():
            continue
        text = script.read_text(encoding="utf-8")
        old = f'OUTPUT = ROOT / "assets" / "props" / "environment" / "{model}.glb"'
        new = (
            f'OUTPUT = ROOT / "assets" / "props" / "environment" / "{model}" / "{model}.glb"'
        )
        if old in text:
            script.write_text(text.replace(old, new), encoding="utf-8")


def update_references() -> int:
    total = 0
    for base in REFERENCE_ROOTS:
        paths = [base] if base.is_file() else base.rglob("*")
        for path in paths:
            if not path.is_file():
                continue
            if path.suffix not in {".gd", ".py", ".json", ".csv", ".import", ".md"}:
                continue
            if ".worktrees" in path.parts or "build" in path.parts:
                continue
            try:
                original = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            updated, n = rewrite_text(original)
            if n:
                path.write_text(updated, encoding="utf-8")
                total += n
    return total


def main() -> None:
    git_mv_models()
    fix_import_sidecars()
    fix_generator_output_paths()
    changes = update_references()
    print(f"relocate_environment_per_model: updated {changes} path references")


if __name__ == "__main__":
    main()
