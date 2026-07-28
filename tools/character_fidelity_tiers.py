"""Frozen character fidelity tiers for P0-140 / ADR 0016.

Classifies runtime humanoid GLBs under ``assets/characters/**`` and enforces
per-tier triangle and embedded-texture budgets. Shader set and instancing
method are documented in ``docs/VISUAL_FIDELITY_PLAN.md`` and ratified in
``docs/adr/0016-tiered-character-fidelity.md``.
"""

from __future__ import annotations

import importlib.util
import json
import struct
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHARACTER_SPECS = ROOT / "tools" / "character_specs.py"
CHARACTERS_DIR = ROOT / "assets" / "characters"

TIER_HERO = 0
TIER_NAMED_NPC = 1
TIER_CROWD = 2

# Build-input GLBs are not shipped at runtime; skip tier enforcement.
BUILD_INPUT_GLBS = frozenset(
    {
        "assets/characters/shared/kaykit_barbarian.glb",
    }
)

# Garment accessories exported beside the hero body (P0-037 garments list).
GARMENT_GLBS = frozenset(
    {
        "assets/characters/shared/hero_cape.glb",
        "assets/characters/shared/hero_hat.glb",
    }
)


@dataclass(frozen=True)
class TierBudget:
    tier: int
    label: str
    triangle_cap: int
    texture_max_px: int
    shader_set: str
    instancing: str


TIER_BUDGETS: dict[int, TierBudget] = {
    TIER_HERO: TierBudget(
        tier=TIER_HERO,
        label="hero",
        triangle_cap=60_000,
        texture_max_px=2048,
        shader_set="full_pbr_skin_hair_eyes",
        instancing="skeleton_mesh_instance",
    ),
    TIER_NAMED_NPC: TierBudget(
        tier=TIER_NAMED_NPC,
        label="named_npc",
        triangle_cap=56_000,
        texture_max_px=1024,
        shader_set="shared_skin_plus_pbr_swaps",
        instancing="skeleton_mesh_instance",
    ),
    TIER_CROWD: TierBudget(
        tier=TIER_CROWD,
        label="crowd",
        triangle_cap=12_000,
        texture_max_px=512,
        shader_set="crowd_simplified_pbr",
        instancing="multimesh_or_vat",
    ),
}

GARMENT_TRIANGLE_CAP = 1024
GARMENT_TEXTURE_MAX_PX = 1024


def _load_character_specs(root: Path) -> dict[str, dict]:
    specs_path = root / CHARACTER_SPECS.relative_to(ROOT)
    if not specs_path.is_file():
        return {}
    spec = importlib.util.spec_from_file_location("character_specs", specs_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"could not import {specs_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return dict(module.CHARACTERS)


def tier_for_spec_name(spec_name: str, entry: dict) -> int:
    if "fidelity_tier" in entry:
        return int(entry["fidelity_tier"])
    # Backward-compatible default until every row carries an explicit tier.
    if spec_name in {"hero", "mart", "henning", "townswoman"}:
        return TIER_HERO
    return TIER_NAMED_NPC


def classify_character_glb(rel_path: str, root: Path = ROOT) -> int | None:
    normalized = rel_path.replace("\\", "/")
    if normalized in BUILD_INPUT_GLBS:
        return None
    if normalized in GARMENT_GLBS:
        return TIER_HERO

    specs = _load_character_specs(root)
    for spec_name, entry in specs.items():
        if entry.get("output", "").replace("\\", "/") == normalized:
            return tier_for_spec_name(spec_name, entry)

    if not normalized.startswith("assets/characters/") or not normalized.endswith(".glb"):
        return None
    # Unknown runtime GLB: conservative Tier 1 until a spec assigns a tier.
    return TIER_NAMED_NPC


def inspect_glb(path: Path) -> dict[str, int]:
    payload = path.read_bytes()
    if payload[:4] != b"glTF":
        raise ValueError(f"{path}: not a binary glTF file")
    json_length = struct.unpack_from("<I", payload, 12)[0]
    document = json.loads(payload[20 : 20 + json_length])

    triangles = 0
    max_texture_px = 0
    for mesh in document.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            if primitive.get("mode", 4) != 4:
                continue
            if "indices" in primitive:
                accessor = document["accessors"][primitive["indices"]]
                triangles += accessor.get("count", 0) // 3
            elif "POSITION" in primitive.get("attributes", {}):
                accessor = document["accessors"][primitive["attributes"]["POSITION"]]
                triangles += accessor.get("count", 0) // 3

    for image in document.get("images", []):
        if "bufferView" in image:
            # Embedded images: dimensions are not in JSON; skip until exporters
            # embed mime metadata. Texture caps apply once P0-144 ships UVs.
            continue
        source = image.get("source")
        if source is None:
            continue
        if source < len(document.get("images", [])):
            # External URI images are not embedded in the GLB payload.
            continue

    for texture in document.get("textures", []):
        source = texture.get("source")
        if source is None:
            continue
        image = document.get("images", [{}])[source]
        if "width" in image and "height" in image:
            max_texture_px = max(max_texture_px, int(image["width"]), int(image["height"]))

    return {
        "triangles": triangles,
        "max_texture_px": max_texture_px,
    }


def iter_runtime_character_glbs(root: Path = ROOT) -> list[Path]:
    characters_root = root / CHARACTERS_DIR.relative_to(ROOT)
    if not characters_root.is_dir():
        return []
    return sorted(path for path in characters_root.rglob("*.glb") if path.is_file())


def validate_character_tier_budgets(*, root: Path = ROOT) -> list[str]:
    errors: list[str] = []
    for glb_path in iter_runtime_character_glbs(root=root):
        rel = glb_path.relative_to(root).as_posix()
        tier = classify_character_glb(rel, root=root)
        if tier is None:
            continue
        try:
            stats = inspect_glb(glb_path)
        except (OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
            errors.append(f"{rel}: could not inspect GLB ({exc})")
            continue

        triangles = int(stats["triangles"])
        max_texture_px = int(stats["max_texture_px"])

        if rel in GARMENT_GLBS:
            if triangles > GARMENT_TRIANGLE_CAP:
                errors.append(
                    f"{rel}: garment triangle budget exceeded "
                    f"({triangles}>{GARMENT_TRIANGLE_CAP})"
                )
            if max_texture_px > GARMENT_TEXTURE_MAX_PX:
                errors.append(
                    f"{rel}: garment texture budget exceeded "
                    f"({max_texture_px}px>{GARMENT_TEXTURE_MAX_PX}px)"
                )
            continue

        budget = TIER_BUDGETS[tier]
        if triangles > budget.triangle_cap:
            errors.append(
                f"{rel}: tier {tier} ({budget.label}) triangle budget exceeded "
                f"({triangles}>{budget.triangle_cap})"
            )
        if max_texture_px > budget.texture_max_px:
            errors.append(
                f"{rel}: tier {tier} ({budget.label}) texture budget exceeded "
                f"({max_texture_px}px>{budget.texture_max_px}px)"
            )

    return errors
