#!/usr/bin/env python3
"""Colocate each Kalev smithy GLB with its Godot sidecars under assets/props/forge/<id>/."""
from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FORGE = ROOT / "assets/props/forge"

MODELS = sorted(
    [
        "smithy_charcoal_storage",
        "smithy_quench_bucket",
        "smithy_furnace",
        "smithy_bellows",
        "smithy_anvil",
    ],
    key=len,
    reverse=True,
)

TEXT_SUFFIXES = {
    ".gd",
    ".tscn",
    ".tres",
    ".import",
    ".md",
    ".json",
    ".csv",
    ".py",
    ".yml",
    ".yaml",
    ".cfg",
    ".txt",
    ".shader",
    ".uid",
}

SKIP_DIRS = {".git", ".godot", "build", "bin"}


def owner(filename: str) -> str | None:
    for model in MODELS:
        if filename == model or filename.startswith(f"{model}.") or filename.startswith(f"{model}_"):
            return model
    return None


def collect_moves() -> list[tuple[Path, Path]]:
    moves: list[tuple[Path, Path]] = []
    for path in sorted(FORGE.iterdir()):
        if not path.is_file():
            continue
        model = owner(path.name)
        if model is None:
            raise SystemExit(f"Unassigned forge root file: {path.name}")
        dest = FORGE / model / path.name
        moves.append((path, dest))
    return moves


def git_mv(src: Path, dest: Path, dry_run: bool) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dry_run:
        print(f"mv {src.relative_to(ROOT)} -> {dest.relative_to(ROOT)}")
        return
    subprocess.run(["git", "mv", str(src), str(dest)], cwd=ROOT, check=True)


def rewrite_import_sidecars(moves: list[tuple[Path, Path]]) -> None:
    for src, dest in moves:
        if not dest.name.endswith(".import"):
            continue
        asset_name = src.name[: -len(".import")]
        text = dest.read_text(encoding="utf-8")
        old = f"res://assets/props/forge/{asset_name}"
        new = f"res://assets/props/forge/{dest.parent.name}/{asset_name}"
        if old not in text:
            continue
        dest.write_text(text.replace(old, new), encoding="utf-8")


def build_replacements(moves: list[tuple[Path, Path]]) -> list[tuple[str, str]]:
    reps: list[tuple[str, str]] = []
    for src, dest in moves:
        name = src.name
        model = dest.parent.name
        reps.append((f"res://assets/props/forge/{name}", f"res://assets/props/forge/{model}/{name}"))
        reps.append((f"assets/props/forge/{name}", f"assets/props/forge/{model}/{name}"))
    reps.sort(key=lambda pair: len(pair[0]), reverse=True)
    return reps


def update_repo_paths(reps: list[tuple[str, str]], dry_run: bool) -> int:
    changed = 0
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        if path.suffix not in TEXT_SUFFIXES and path.name not in {"SOURCES.csv", "shipped_resource_manifest.json"}:
            continue
        if path == Path(__file__).resolve():
            continue
        original = path.read_text(encoding="utf-8")
        if "assets/props/forge/" not in original and "res://assets/props/forge/" not in original:
            continue
        updated = original
        for old, new in reps:
            updated = updated.replace(old, new)
        if updated != original:
            changed += 1
            if dry_run:
                print(f"would update {path.relative_to(ROOT)}")
            else:
                path.write_text(updated, encoding="utf-8")
    return changed


def moves_from_layout() -> list[tuple[Path, Path]]:
    moves: list[tuple[Path, Path]] = []
    for model_dir in sorted(p for p in FORGE.iterdir() if p.is_dir()):
        for path in sorted(model_dir.iterdir()):
            if path.is_file():
                flat = FORGE / path.name
                moves.append((flat, path))
    return moves


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--references-only",
        action="store_true",
        help="Skip git mv; refresh import sidecars and repo path strings (after a partial run).",
    )
    args = parser.parse_args()
    if args.references_only:
        moves = moves_from_layout()
    else:
        moves = collect_moves()
        if not moves:
            print("Nothing to move.")
            return
        for src, dest in moves:
            git_mv(src, dest, args.dry_run)
    if not args.dry_run:
        rewrite_import_sidecars(moves)
    reps = build_replacements(moves)
    count = update_repo_paths(reps, args.dry_run)
    print(f"{'Would update' if args.dry_run else 'Updated'} {count} text files; tracked {len(moves)} assets.")


if __name__ == "__main__":
    main()
