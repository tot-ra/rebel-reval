#!/usr/bin/env python3
"""ADR 0025 Decision 3 building budgets as data, plus the machine check.

Triangle, material, LOD-sibling and on-disk caps live here so AR-04..AR-12 and
``verify_asset_lint.py`` read one table. Tiers are declared by path prefix or
an explicit manifest row; they are never inferred from triangle count.

Pre-kit facade openings under ``assets/buildings/facades/`` are grandfathered
until AR-04/AR-06 rebuild them as kit parts. The six house monoliths under
``assets/props/architecture/houses/`` stay exempt until AR-06 even if copied
into ``assets/buildings/``.
"""

from __future__ import annotations

import json
import re
import struct
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILDINGS_DIR = ROOT / "assets" / "buildings"

MI_B = 1024 * 1024
GLB_MAX_BYTES = 6 * MI_B
TEXTURE_MAX_BYTES = 4 * MI_B
KIT_SET_MAX_BYTES = 24 * MI_B
B_SET_MAX_BYTES = 12 * MI_B
BUILDINGS_TOTAL_MAX_BYTES = 96 * MI_B

TEXTURE_SUFFIXES = frozenset({".png", ".jpg", ".jpeg", ".webp", ".exr"})
SKIP_SUFFIXES = frozenset({".import"})

# Decision 3 triangle and material caps. LOD2 is a whole-building proxy, so a
# K-part has no LOD2 file of its own.
TIER_CAPS: dict[str, dict[str, int | None]] = {
    "K-S": {"lod0": 6_000, "lod1": 2_000, "lod2": 400, "materials": 6},
    "K-L": {"lod0": 14_000, "lod1": 4_500, "lod2": 900, "materials": 6},
    "B": {"lod0": 60_000, "lod1": 18_000, "lod2": 4_000, "materials": 8},
    "B-module": {"lod0": 3_000, "lod1": 900, "lod2": 150, "materials": 8},
    "K-part": {"lod0": 1_500, "lod1": 500, "lod2": None, "materials": 6},
}

# First matching prefix wins. Fortification wall runs use B-module; named
# towers and gates in the same set stay B.
TIER_PREFIXES: tuple[tuple[str, str], ...] = (
    ("assets/buildings/kit/", "K-part"),
    ("assets/buildings/assembled/k-s/", "K-S"),
    ("assets/buildings/assembled/k-l/", "K-L"),
    ("assets/buildings/fortification/modules/", "B-module"),
    ("assets/buildings/monastic/", "B"),
    ("assets/buildings/padise/", "B"),
    ("assets/buildings/toompea/", "B"),
    ("assets/buildings/civic/", "B"),
    ("assets/buildings/fortification/", "B"),
    ("assets/buildings/rural/", "B"),
)

SET_PREFIXES: dict[str, str] = {
    "kit": "assets/buildings/kit",
    "monastic": "assets/buildings/monastic",
    "padise": "assets/buildings/padise",
    "toompea": "assets/buildings/toompea",
    "civic": "assets/buildings/civic",
    "fortification": "assets/buildings/fortification",
    "rural": "assets/buildings/rural",
}

# Explicit path -> tier. Use this for one-off files that sit outside the
# prefix table; do not add a guess from mesh size.
TIER_MANIFEST: dict[str, str] = {}

GRANDFATHERED_PREFIXES: tuple[str, ...] = ("assets/buildings/facades/",)

GRANDFATHERED_PATHS: frozenset[str] = frozenset(
    {
        "assets/props/architecture/houses/merchant_timber/merchant_timber.glb",
        "assets/props/architecture/houses/merchant_timber/merchant_timber_log.glb",
        "assets/props/architecture/houses/merchant_stone/merchant_stone.glb",
        "assets/props/architecture/houses/merchant_stone/merchant_stone_rendered.glb",
        "assets/props/architecture/houses/craft_boda/craft_boda.glb",
        "assets/props/architecture/houses/craft_boda/craft_boda_pentice.glb",
    }
)

_LOD_FILE_RE = re.compile(r"^(?P<stem>.+)_lod(?P<lod>[12])$", re.IGNORECASE)
_LOD_MESH_RE = re.compile(r"(?:^|_|-)lod(?P<lod>[012])(?:_|$)", re.IGNORECASE)


@dataclass(frozen=True)
class BuildingClass:
    rel: str
    tier: str | None
    grandfathered: bool
    set_id: str | None


@dataclass(frozen=True)
class GlbStats:
    triangles_by_lod: dict[str, int]
    material_count: int
    embedded_images: int
    named_lods: frozenset[str]


def _posix(rel: str) -> str:
    return rel.replace("\\", "/")


def iter_building_glbs(root: Path = ROOT) -> list[Path]:
    buildings = root / "assets" / "buildings"
    if not buildings.is_dir():
        return []
    return sorted(path for path in buildings.rglob("*.glb") if path.is_file())


def is_grandfathered(rel: str) -> bool:
    normalized = _posix(rel)
    if normalized in GRANDFATHERED_PATHS:
        return True
    return any(normalized.startswith(prefix) for prefix in GRANDFATHERED_PREFIXES)


def set_id_for(rel: str) -> str | None:
    normalized = _posix(rel)
    for set_id, prefix in SET_PREFIXES.items():
        if normalized == prefix or normalized.startswith(prefix + "/"):
            return set_id
    return None


def classify_building_glb(rel: str) -> BuildingClass:
    normalized = _posix(rel)
    grandfathered = is_grandfathered(normalized)
    if grandfathered:
        return BuildingClass(normalized, None, True, set_id_for(normalized))
    if normalized in TIER_MANIFEST:
        return BuildingClass(
            normalized, TIER_MANIFEST[normalized], False, set_id_for(normalized)
        )
    for prefix, tier in TIER_PREFIXES:
        if normalized.startswith(prefix):
            return BuildingClass(normalized, tier, False, set_id_for(normalized))
    return BuildingClass(normalized, None, False, set_id_for(normalized))


def lod_file_role(path: Path) -> tuple[str, str]:
    """Return (lod0_stem, role) where role is lod0/lod1/lod2."""
    match = _LOD_FILE_RE.match(path.stem)
    if match:
        return match.group("stem"), f"lod{match.group('lod')}"
    return path.stem, "lod0"


def _mesh_lod(name: str) -> str | None:
    match = _LOD_MESH_RE.search(name or "")
    if match:
        return f"lod{match.group('lod')}"
    return None


def inspect_building_glb(path: Path) -> GlbStats:
    payload = path.read_bytes()
    if payload[:4] != b"glTF":
        raise ValueError(f"{path}: not a binary glTF file")
    json_length = struct.unpack_from("<I", payload, 12)[0]
    document = json.loads(payload[20 : 20 + json_length])

    triangles_by_lod: dict[str, int] = {"lod0": 0, "lod1": 0, "lod2": 0}
    named_lods: set[str] = set()
    for mesh in document.get("meshes") or []:
        mesh_lod = _mesh_lod(str(mesh.get("name") or ""))
        if mesh_lod is not None:
            named_lods.add(mesh_lod)
        bucket = mesh_lod or "lod0"
        for primitive in mesh.get("primitives") or []:
            if primitive.get("mode", 4) != 4:
                continue
            if "indices" in primitive:
                accessor = document["accessors"][primitive["indices"]]
                triangles_by_lod[bucket] += int(accessor.get("count", 0)) // 3
            elif "POSITION" in primitive.get("attributes", {}):
                accessor = document["accessors"][primitive["attributes"]["POSITION"]]
                triangles_by_lod[bucket] += int(accessor.get("count", 0)) // 3

    embedded = 0
    for image in document.get("images") or []:
        uri = image.get("uri")
        if "bufferView" in image:
            embedded += 1
        elif isinstance(uri, str) and uri.startswith("data:"):
            embedded += 1

    return GlbStats(
        triangles_by_lod=triangles_by_lod,
        material_count=len(document.get("materials") or []),
        embedded_images=embedded,
        named_lods=frozenset(named_lods),
    )


def _dir_bytes(root: Path, rel_prefix: str) -> int:
    folder = root / rel_prefix
    if not folder.is_dir():
        return 0
    total = 0
    for path in folder.rglob("*"):
        if not path.is_file() or path.suffix.lower() in SKIP_SUFFIXES:
            continue
        total += path.stat().st_size
    return total


def _sibling_path(lod0_path: Path, lod0_stem: str, role: str) -> Path:
    return lod0_path.with_name(f"{lod0_stem}_{role}.glb")


def _present_lods(path: Path, stats: GlbStats) -> set[str]:
    lod0_stem, role = lod_file_role(path)
    present = {role}
    present.update(stats.named_lods)
    if role == "lod0":
        for extra in ("lod1", "lod2"):
            if _sibling_path(path, lod0_stem, extra).is_file():
                present.add(extra)
    return present


def _triangles_for_role(path: Path, stats: GlbStats, role: str) -> int:
    _, file_role = lod_file_role(path)
    if file_role != "lod0":
        # A dedicated sibling is the whole mesh for that LOD.
        return sum(stats.triangles_by_lod.values())
    if stats.named_lods:
        return stats.triangles_by_lod.get(role, 0)
    return stats.triangles_by_lod["lod0"] if role == "lod0" else 0


def validate_building_budgets(*, root: Path = ROOT) -> list[str]:
    errors: list[str] = []
    buildings = root / "assets" / "buildings"
    if not buildings.is_dir():
        return errors

    for glb_path in iter_building_glbs(root=root):
        rel = glb_path.relative_to(root).as_posix()
        classified = classify_building_glb(rel)
        size = glb_path.stat().st_size
        if size > GLB_MAX_BYTES:
            errors.append(
                f"{rel}: GLB is {size} bytes; ADR 0025 cap is {GLB_MAX_BYTES} (6 MiB)"
            )

        if classified.grandfathered:
            continue
        if classified.tier is None:
            errors.append(
                f"{rel}: building GLB has no ADR 0025 tier; declare it by path "
                "prefix or TIER_MANIFEST, do not guess from mesh size"
            )
            continue

        try:
            stats = inspect_building_glb(glb_path)
        except (OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
            errors.append(f"{rel}: could not inspect building GLB ({exc})")
            continue

        caps = TIER_CAPS[classified.tier]
        _, role = lod_file_role(glb_path)
        present = _present_lods(glb_path, stats)

        if role == "lod0":
            if "lod1" not in present:
                errors.append(f"{rel}: missing LOD1 sibling ({glb_path.stem}_lod1.glb) or lod1 mesh")
            if caps["lod2"] is not None and "lod2" not in present:
                errors.append(f"{rel}: missing LOD2 sibling ({glb_path.stem}_lod2.glb) or lod2 mesh")

        triangles = _triangles_for_role(glb_path, stats, role)
        cap = caps[role]
        if cap is not None and triangles > int(cap):
            errors.append(
                f"{rel}: {classified.tier} {role} triangle budget exceeded "
                f"({triangles}>{cap})"
            )

        material_cap = int(caps["materials"] or 0)
        if stats.material_count > material_cap:
            kind = "K" if classified.tier.startswith("K") else "B"
            errors.append(
                f"{rel}: {kind} material slot budget exceeded "
                f"({stats.material_count}>{material_cap})"
            )

        if classified.tier == "K-part" and stats.embedded_images:
            errors.append(
                f"{rel}: kit part must embed 0 images, found {stats.embedded_images}"
            )

    for path in buildings.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in TEXTURE_SUFFIXES:
            continue
        size = path.stat().st_size
        if size > TEXTURE_MAX_BYTES:
            rel = path.relative_to(root).as_posix()
            errors.append(
                f"{rel}: texture is {size} bytes; ADR 0025 cap is {TEXTURE_MAX_BYTES} (4 MiB)"
            )

    kit_bytes = _dir_bytes(root, SET_PREFIXES["kit"])
    if kit_bytes > KIT_SET_MAX_BYTES:
        errors.append(
            f"assets/buildings/kit: set is {kit_bytes} bytes; ADR 0025 cap is "
            f"{KIT_SET_MAX_BYTES} (24 MiB)"
        )
    for set_id, prefix in SET_PREFIXES.items():
        if set_id == "kit":
            continue
        set_bytes = _dir_bytes(root, prefix)
        if set_bytes > B_SET_MAX_BYTES:
            errors.append(
                f"{prefix}: B set is {set_bytes} bytes; ADR 0025 cap is "
                f"{B_SET_MAX_BYTES} (12 MiB)"
            )

    total = _dir_bytes(root, "assets/buildings")
    if total > BUILDINGS_TOTAL_MAX_BYTES:
        errors.append(
            f"assets/buildings: tree is {total} bytes; ADR 0025 cap is "
            f"{BUILDINGS_TOTAL_MAX_BYTES} (96 MiB)"
        )
    return errors
