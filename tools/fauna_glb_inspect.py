"""Inspect fauna GLBs for the P0-160 normal + roughness PBR contract.

Runtime bird and medieval livestock GLBs must ship embedded tangent-space
normal maps and metallic-roughness textures on every textured body material.
Eye, pupil, and other accent materials are exempt.
"""

from __future__ import annotations

import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FAUNA_GLB_REL_ROOTS = (
    "assets/birds",
    "assets/animals",
)

# Accent materials on rigged livestock do not need full ORM maps.
EXEMPT_MATERIAL_NAME_PARTS = (
    "eye",
    "pupil",
    "cornea",
    "iris",
    "sclera",
)


def load_glb_document(path: Path) -> dict:
    payload = path.read_bytes()
    if payload[:4] != b"glTF":
        raise ValueError(f"{path}: not a binary glTF file")
    json_length = struct.unpack_from("<I", payload, 12)[0]
    return json.loads(payload[20 : 20 + json_length])


def material_needs_pbr(name: str, material: dict) -> bool:
    lowered = (name or "").lower()
    if any(part in lowered for part in EXEMPT_MATERIAL_NAME_PARTS):
        return False
    pbr = material.get("pbrMetallicRoughness", {})
    return "baseColorTexture" in pbr


def inspect_fauna_glb(path: Path) -> list[str]:
    """Return human-readable contract violations for one fauna GLB."""
    try:
        document = load_glb_document(path)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        return [str(exc)]

    materials = document.get("materials", [])
    if not materials:
        return [f"{path}: GLB has no materials"]

    errors: list[str] = []
    body_materials = [
        material
        for material in materials
        if material_needs_pbr(material.get("name", ""), material)
    ]
    if not body_materials:
        body_materials = [materials[0]]

    for material in body_materials:
        name = material.get("name", "unnamed")
        if material.get("normalTexture") is None:
            errors.append(f"material '{name}' missing normalTexture")
        pbr = material.get("pbrMetallicRoughness", {})
        if "metallicRoughnessTexture" not in pbr:
            errors.append(f"material '{name}' missing metallicRoughnessTexture")
    return errors


def iter_fauna_glbs(root: Path = ROOT) -> list[Path]:
    glbs: list[Path] = []
    for rel_root in FAUNA_GLB_REL_ROOTS:
        absolute = root / rel_root
        if not absolute.is_dir():
            continue
        glbs.extend(sorted(path for path in absolute.rglob("*.glb") if path.is_file()))
    return glbs


def validate_fauna_glb_pbr(*, root: Path = ROOT) -> list[str]:
    errors: list[str] = []
    for glb_path in iter_fauna_glbs(root=root):
        rel = glb_path.relative_to(root).as_posix()
        for issue in inspect_fauna_glb(glb_path):
            errors.append(f"{rel}: {issue}")
    return errors
