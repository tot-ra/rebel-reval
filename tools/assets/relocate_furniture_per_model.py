#!/usr/bin/env python3
"""Colocate each furniture GLB with its Godot sidecars under assets/props/furniture/<stem>/."""
from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FURNITURE = ROOT / "assets/props/furniture"

# Longest stems first so shared prefixes resolve to the right owner.
ROOT_MODELS = sorted(
    [
        "chest_merchant_strongbox",
        "chest_burgher_household",
        "chest_poor_household",
        "smithy_chair",
        "smithy_bed",
    ],
    key=len,
    reverse=True,
)

NESTED_LAYOUTS: tuple[tuple[Path, list[str]], ...] = (
    (FURNITURE / "medieval_storage", ["common_open_rack", "burgher_cupboard", "elite_armarium"]),
    (FURNITURE / "tables", ["medieval_table_kit"]),
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

SKIP_DIRS = {".git", ".godot", "build", "bin", ".worktrees"}


def owner(filename: str, models: list[str]) -> str | None:
    for model in models:
        if filename == model or filename.startswith(f"{model}.") or filename.startswith(f"{model}_"):
            return model
    return None


def collect_moves_in(parent: Path, models: list[str]) -> list[tuple[Path, Path]]:
    moves: list[tuple[Path, Path]] = []
    for path in sorted(parent.iterdir()):
        if not path.is_file():
            continue
        model = owner(path.name, models)
        if model is None:
            continue
        dest = parent / model / path.name
        moves.append((path, dest))
    return moves


def collect_moves() -> list[tuple[Path, Path]]:
    moves = collect_moves_in(FURNITURE, ROOT_MODELS)
    for parent, models in NESTED_LAYOUTS:
        moves.extend(collect_moves_in(parent, sorted(models, key=len, reverse=True)))
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
        asset_name = dest.name[: -len(".import")]
        text = dest.read_text(encoding="utf-8")
        old = f"res://{src.parent.relative_to(ROOT).as_posix()}/{asset_name}"
        new = f"res://{dest.parent.relative_to(ROOT).as_posix()}/{asset_name}"
        if old in text:
            dest.write_text(text.replace(old, new), encoding="utf-8")


def build_replacements(moves: list[tuple[Path, Path]]) -> list[tuple[str, str]]:
    reps: list[tuple[str, str]] = []
    for src, dest in moves:
        name = src.name
        rel_old = src.relative_to(ROOT).as_posix()
        rel_new = dest.relative_to(ROOT).as_posix()
        reps.append((f"res://{rel_old}", f"res://{rel_new}"))
        reps.append((rel_old, rel_new))
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
        if path.resolve() == Path(__file__).resolve():
            continue
        original = path.read_text(encoding="utf-8")
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
    for parent in [FURNITURE, *(layout[0] for layout in NESTED_LAYOUTS)]:
        for model_dir in sorted(p for p in parent.iterdir() if p.is_dir()):
            for path in sorted(model_dir.iterdir()):
                if path.is_file():
                    flat = parent / path.name
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
