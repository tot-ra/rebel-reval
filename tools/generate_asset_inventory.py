#!/usr/bin/env python3
"""Generate the runtime image/audio asset inventory.

The inventory is intentionally conservative for P0-027: assets are not marked
`approved` unless provenance, rights, and style approval are already documented.
"""

from __future__ import annotations

import argparse
from collections import Counter
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "ASSET_INVENTORY.md"
RUNTIME_ROOTS = ("assets", "music", "sounds")
IMPORTED_MARKETING_ROOTS = ("img",)
SCAN_ROOTS = RUNTIME_ROOTS + IMPORTED_MARKETING_ROOTS
IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg", ".bmp", ".tga"}
AUDIO_EXTENSIONS = {".mp3", ".ogg", ".wav", ".flac", ".opus", ".aac"}
RUNTIME_EXTENSIONS = IMAGE_EXTENSIONS | AUDIO_EXTENSIONS
CLASSIFICATIONS = ("approved", "prototype", "unknown rights", "inconsistent", "archive")
ACTIVE_IMPORT_CLASSIFICATIONS = frozenset({"approved", "prototype"})


def iter_runtime_assets() -> list[Path]:
    """Return image/audio source files in P0-027 scope.

    The primary runtime scope is assets/music/sounds. Marketing images in img/
    are included only when Godot already imports them, matching the TODO caveat.
    """
    assets: list[Path] = []
    for root_name in RUNTIME_ROOTS:
        root = ROOT / root_name
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if path.is_file() and path.suffix.lower() in RUNTIME_EXTENSIONS:
                assets.append(path.relative_to(ROOT))
    for root_name in IMPORTED_MARKETING_ROOTS:
        root = ROOT / root_name
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if (
                path.is_file()
                and path.suffix.lower() in RUNTIME_EXTENSIONS
                and Path(f"{path.as_posix()}.import").exists()
            ):
                assets.append(path.relative_to(ROOT))
    return sorted(set(assets), key=lambda p: p.as_posix().casefold())


def iter_orphan_imports(runtime_assets: Iterable[Path]) -> list[Path]:
    """Return import sidecars whose source file is missing.

    These are not counted as runtime asset rows because the task asks for
    image/audio files, but listing them makes the verification boundary explicit.
    """
    runtime_asset_set = {path.as_posix() for path in runtime_assets}
    orphans: list[Path] = []
    for root_name in SCAN_ROOTS:
        root = ROOT / root_name
        if not root.exists():
            continue
        for path in root.rglob("*.import"):
            source = path.relative_to(ROOT).as_posix()[: -len(".import")]
            if Path(source).suffix.lower() in RUNTIME_EXTENSIONS and source not in runtime_asset_set:
                orphans.append(path.relative_to(ROOT))
    return sorted(orphans, key=lambda p: p.as_posix().casefold())


def has_import_sidecar(path: Path) -> bool:
    return (ROOT / f"{path.as_posix()}.import").exists()


def media_type(path: Path) -> str:
    return "audio" if path.suffix.lower() in AUDIO_EXTENSIONS else "image"


def classify(path: Path) -> tuple[str, str]:
    """Classify one runtime asset using conservative P0-027 rules."""
    p = path.as_posix()
    name = path.name.lower()

    if p.startswith("assets/bestiary/"):
        return "archive", "Folder has legacy-status archive in assets/bestiary/README.md."

    if p.startswith("img/"):
        return "archive", "Marketing image imported by Godot; excluded from active runtime asset candidates."

    if p == "assets/tiles/greybox_floor.png":
        return "prototype", "P0-030 greybox tile placeholder for district TileMapLayers until P0-040 orthogonal art lands."

    if media_type(path) == "audio":
        return "unknown rights", "No per-track source, creator, license, or approval manifest exists yet."

    if p.startswith("assets/UI/"):
        return "inconsistent", "Legacy HUD/system art is frozen until P0-040 defines the approved UI style."

    if p.startswith("assets/player/"):
        return "inconsistent", "Eight-direction pixel-frame animation set conflicts with the pending four-direction target."

    if p.startswith("assets/tiles/") or p in {
        "assets/tiles.png",
        "assets/tiles2.png",
        "assets/rocks.png",
        "assets/rocks-grass.png",
    }:
        return "inconsistent", "Legacy tile/isometric materials predate the orthogonal style decision."

    if "download" in name:
        return "unknown rights", "Generic download filename gives no source or license evidence."

    if p.startswith("assets/buildings/walls-and-turrets/") and (
        path.suffix.lower() in {".jpg", ".jpeg"} or "universal_upscale" in name
    ):
        return "unknown rights", "Rendered/reference wall asset has no source or license evidence."

    return "prototype", "Pre-art-bible runtime art candidate; provenance and approval are still pending P0-028/P0-040."


def active_import_violations(assets: Iterable[Path]) -> list[tuple[str, str, str]]:
    """Return active import paths that are not slice candidates or approved assets."""
    violations: list[tuple[str, str, str]] = []
    for path in assets:
        if path.parts[0] not in RUNTIME_ROOTS:
            continue
        cls, reason = classify(path)
        if cls not in ACTIVE_IMPORT_CLASSIFICATIONS:
            violations.append((path.as_posix(), cls, reason))
    return violations


def md_escape(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", " ")


def render_inventory() -> str:
    assets = iter_runtime_assets()
    orphans = iter_orphan_imports(assets)
    rows = []
    counts: Counter[str] = Counter()
    media_counts: Counter[str] = Counter()
    missing_sidecars: list[Path] = []
    scoped_root_count = sum(1 for path in assets if path.parts[0] in RUNTIME_ROOTS)
    imported_marketing_count = sum(1 for path in assets if path.parts[0] in IMPORTED_MARKETING_ROOTS)

    for path in assets:
        cls, reason = classify(path)
        counts[cls] += 1
        media_counts[media_type(path)] += 1
        sidecar = has_import_sidecar(path)
        if not sidecar:
            missing_sidecars.append(path)
        rows.append((path.as_posix(), media_type(path), cls, "yes" if sidecar else "no", reason))

    lines: list[str] = []
    lines.append("# Asset Inventory")
    lines.append("")
    lines.append("Generated by `python3 tools/generate_asset_inventory.py` for TODO P0-027, updated after the P0-029 quarantine, and active-path pruning for P0-030.")
    lines.append("")
    lines.append("## Scope")
    lines.append("")
    lines.append("- Includes active runtime image and audio source files under `assets/`, `music/`, and `sounds/` with common Godot runtime extensions.")
    lines.append("- Includes `img/` marketing image/audio files only when Godot can import them from the active tree; P0-029 quarantined marketing imports are excluded.")
    lines.append("- Excludes `quarantine/` because its `.gdignore` prevents Godot from importing files there; provenance remains in `assets/SOURCES.csv` using mirrored original paths.")
    lines.append("- Excludes Godot `*.import` sidecars from the per-file rows because they are metadata, not source image/audio files.")
    lines.append("- Uses conservative classifications. Nothing is marked `approved` until provenance, commercial rights, and style approval are documented.")
    lines.append("")
    lines.append("## Classification rules")
    lines.append("")
    lines.append("Priority order:")
    lines.append("")
    lines.append("1. `archive` - `assets/bestiary/` because its README is marked legacy-status `archive`, plus imported `img/` marketing files that are not active runtime candidates.")
    lines.append("2. `unknown rights` - all audio, generic `download*` art, and wall/reference renders without source/license evidence.")
    lines.append("3. `inconsistent` - legacy HUD/system UI, eight-direction player frame sets, and old tile/isometric materials that conflict with the pending P0-040 art direction.")
    lines.append("4. `prototype` - remaining runtime art candidates that may be useful but are not approved and still need P0-028 provenance plus P0-040 style review.")
    lines.append("5. `approved` - reserved for future assets with documented source, rights, edits, and human approval. Count is currently zero.")
    lines.append("")
    lines.append("## Counts by classification")
    lines.append("")
    lines.append("| Classification | Count |")
    lines.append("| --- | ---: |")
    for cls in CLASSIFICATIONS:
        lines.append(f"| {cls} | {counts[cls]} |")
    lines.append(f"| **Total** | **{len(rows)}** |")
    lines.append("")
    lines.append("## Counts by media type")
    lines.append("")
    lines.append("| Media type | Count |")
    lines.append("| --- | ---: |")
    for cls in ("image", "audio"):
        lines.append(f"| {cls} | {media_counts[cls]} |")
    lines.append(f"| **Total** | **{len(rows)}** |")
    lines.append("")
    lines.append("## Verification summary")
    lines.append("")
    lines.append(f"- Inventory row count: `{len(rows)}`")
    lines.append(f"- Runtime source files found under `assets/`, `music/`, and `sounds/`: `{scoped_root_count}`")
    lines.append(f"- Imported `img/` marketing source files included as archive: `{imported_marketing_count}`")
    lines.append(f"- Rows missing Godot `.import` sidecar: `{len(missing_sidecars)}`")
    lines.append(f"- Orphan `.import` sidecars with no source file, not counted as runtime assets: `{len(orphans)}`")
    active_violations = active_import_violations(assets)
    lines.append(f"- Active import path violations (must be `approved` or `prototype`): `{len(active_violations)}`")
    lines.append("- Reproduce with: `python3 tools/generate_asset_inventory.py --check`")
    lines.append("")
    if active_violations:
        lines.append("### Active import path violations")
        lines.append("")
        for path, cls, reason in active_violations:
            lines.append(f"- `{path}` ({cls}): {reason}")
        lines.append("")
    if missing_sidecars:
        lines.append("### Missing import sidecars")
        lines.append("")
        for path in missing_sidecars:
            lines.append(f"- `{path.as_posix()}`")
        lines.append("")
    if orphans:
        lines.append("### Orphan import sidecars excluded from row count")
        lines.append("")
        for path in orphans:
            lines.append(f"- `{path.as_posix()}`")
        lines.append("")
    lines.append("## Per-file inventory")
    lines.append("")
    lines.append("| Path | Media | Classification | Imported by Godot | Rationale |")
    lines.append("| --- | --- | --- | --- | --- |")
    for path, kind, cls, imported, reason in rows:
        lines.append(
            f"| `{md_escape(path)}` | {kind} | {cls} | {imported} | {md_escape(reason)} |"
        )
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate docs/ASSET_INVENTORY.md")
    parser.add_argument("--check", action="store_true", help="fail if docs/ASSET_INVENTORY.md is not up to date")
    args = parser.parse_args()

    rendered = render_inventory()
    if args.check:
        current = OUTPUT.read_text(encoding="utf-8") if OUTPUT.exists() else ""
        if current != rendered:
            print(f"{OUTPUT.relative_to(ROOT)} is not up to date")
            return 1
        violations = active_import_violations(iter_runtime_assets())
        if violations:
            print(
                f"{len(violations)} active import path violation(s); "
                "only approved or prototype assets may remain under assets/, music/, and sounds/"
            )
            for path, cls, _reason in violations:
                print(f"  - {path} ({cls})")
            return 1
        print(f"{OUTPUT.relative_to(ROOT)} is up to date")
        print("active import path ok")
        return 0

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(rendered, encoding="utf-8")
    print(f"wrote {OUTPUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
