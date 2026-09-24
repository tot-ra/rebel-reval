#!/usr/bin/env python3
"""One-shot helper: colocate each storybook GLB with its sidecars under assets/storybook/<id>/."""
from __future__ import annotations

import argparse
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STORYBOOK = ROOT / "assets/storybook"

KEEP_AT_ROOT = {
    "README.md",
    "mammal_sources.json",
    "bird_plumage.gdshader",
    "bird_plumage.gdshader.uid",
    "storybook_character.gd",
    "storybook_character.gd.uid",
    "storybook_cat.gd",
    "storybook_cat.gd.uid",
}

SPECIAL_PREFIX = {
    "horse_pack_horse": "horse",
    "cow_cattle": "cow",
    "goose_greylag": "goose",
    "sheep_T_Sheep": "sheep",
}

MODELS = sorted(
    [
        "hooded_crow",
        "forge_cat",
        "watchman",
        "henning",
        "jurgen",
        "aita",
        "ellen",
        "mart",
        "kaja",
        "boar",
        "sheep",
        "goat",
        "horse",
        "goose",
        "duck",
        "gull",
        "hare",
        "hen",
        "cow",
        "dog",
        "pig",
        "fox",
        "rat",
        "robin",
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
    for prefix, model in SPECIAL_PREFIX.items():
        if filename.startswith(prefix):
            return model
    for model in MODELS:
        if filename == model or filename.startswith(f"{model}.") or filename.startswith(f"{model}_"):
            return model
    return None


def collect_moves() -> list[tuple[Path, Path]]:
    moves: list[tuple[Path, Path]] = []
    for path in sorted(STORYBOOK.iterdir()):
        if not path.is_file() or path.name in KEEP_AT_ROOT:
            continue
        model = owner(path.name)
        if model is None:
            raise SystemExit(f"Unassigned storybook root file: {path.name}")
        dest = STORYBOOK / model / path.name
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
        old = f"res://assets/storybook/{asset_name}"
        new = f"res://assets/storybook/{dest.parent.name}/{asset_name}"
        if old not in text:
            continue
        dest.write_text(text.replace(old, new), encoding="utf-8")


def build_replacements(moves: list[tuple[Path, Path]]) -> list[tuple[str, str]]:
    reps: list[tuple[str, str]] = []
    for src, dest in moves:
        name = src.name
        model = dest.parent.name
        reps.append((f"res://assets/storybook/{name}", f"res://assets/storybook/{model}/{name}"))
        reps.append((f"assets/storybook/{name}", f"assets/storybook/{model}/{name}"))
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
        if path.is_relative_to(STORYBOOK / "equipment"):
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


def patch_load_templates(dry_run: bool) -> None:
    """Fix format-string loaders that cannot be updated by naive substring replace."""
    patches = {
        ROOT
        / "scenes/debug/storybook_showcase.gd": (
            'load("res://assets/storybook/%s.%s" % [IDS[i], extension])',
            'load("res://assets/storybook/%s/%s.%s" % [IDS[i], IDS[i], extension])',
        ),
        ROOT
        / "tests/godot/test_storybook_models.gd": (
            'load("res://assets/storybook/%s.glb" % id)',
            'load("res://assets/storybook/%s/%s.glb" % [id, id])',
        ),
    }
    extra = ROOT / "tests/godot/test_storybook_models.gd"
    patches[extra] = (
        patches[extra][0],
        patches[extra][1],
    )
    for path, (old, new) in patches.items():
        text = path.read_text(encoding="utf-8")
        if old not in text:
            continue
        if dry_run:
            print(f"would patch template in {path.relative_to(ROOT)}")
        else:
            path.write_text(text.replace(old, new), encoding="utf-8")

    tscn_patch = (
        'load("res://assets/storybook/%s.tscn" % id)',
        'load("res://assets/storybook/%s/%s.tscn" % [id, id])',
    )
    path = ROOT / "tests/godot/test_storybook_models.gd"
    text = path.read_text(encoding="utf-8")
    if tscn_patch[0] in text:
        if dry_run:
            print(f"would patch tscn template in {path.relative_to(ROOT)}")
        else:
            path.write_text(text.replace(tscn_patch[0], tscn_patch[1]), encoding="utf-8")

    mart = (
        'load("res://assets/storybook/mart/mart.glb")',
        'load("res://assets/storybook/mart/mart.glb")',
    )
    text = path.read_text(encoding="utf-8")
    if mart[0] in text:
        if not dry_run:
            path.write_text(text.replace(mart[0], mart[1]), encoding="utf-8")


def moves_from_layout() -> list[tuple[Path, Path]]:
    moves: list[tuple[Path, Path]] = []
    for model_dir in sorted(p for p in STORYBOOK.iterdir() if p.is_dir() and p.name != "equipment"):
        for path in sorted(model_dir.iterdir()):
            if path.is_file():
                flat = STORYBOOK / path.name
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
    patch_load_templates(args.dry_run)
    print(f"{'Would update' if args.dry_run else 'Updated'} {count} text files; tracked {len(moves)} assets.")


if __name__ == "__main__":
    main()
