"""Character generation specs: one entry per generated body.

Both pipeline stages read this registry — `build_heroic_humanoid_glb.py`
(plain python3) and `generate_hero_body.py` (Blender's python) — so a new
character body is one dict entry here plus a rebuild run:

    tools/rebuild_hero_character.sh <spec_name>

See docs/CHARACTER_GENERATION.md for the full procedure and the meaning of
every knob. All palette colors are authored in sRGB.

Spec fields (all optional except output):
- proportions: overrides merged over BASE_PROPORTIONS; consumed by the
  skeleton retarget, so limb lengths and widths also reshape every
  animation clip consistently.
- shape: high-level mesh knobs merged over BASE_SHAPE; consumed by the body
  generator (multipliers on generated geometry, not on bones).
- palette: sRGB color overrides merged over the base PALETTE of the
  generator (skin, tunic, pants, boots, belt, hair, beard, eyes, ...).
- output: runtime glb path relative to the repo root.
- garments: garment ids to export as separate skinned glbs next to the
  body ("cape", "hat"). Usually only the shared hero set carries these.
"""

BASE_PROPORTIONS = {
    "leg_length": 1.85,
    "arm_length": 1.25,
    "torso_length": 0.88,
    "shoulder_width": 0.85,
    "hip_socket_width": 0.95,
    "head_size": 0.32,
    "hand_size": 0.85,
    # Degrees the upper arms are folded toward the body across every clip.
    # The CC0 source clips were authored around a barrel-wide chibi torso, so
    # on our slim bodies the arms read as spread wings without this.
    "arm_relax_degrees": 14.0,
}

BASE_SHAPE = {
    # Multiplies every generated radius: overall bulk without touching bones.
    "bulk": 1.0,
    # Extra breadth for the chest/shoulder rings only.
    "chest_breadth": 1.0,
    # Extra girth for the waist/hip rings only (belly).
    "belly": 1.0,
    # Visual head sphere size (bone-independent).
    "head_scale": 1.0,
}

CHARACTERS = {
    # The shared hero body used by Kalev, Mart, and current NPC variants.
    "hero": {
        "output": "assets/characters/shared/heroic_humanoid.glb",
        "garments": ["cape", "hat"],
    },
    # Worked example for docs/CHARACTER_GENERATION.md: a stocky innkeeper
    # frame — shorter legs, broad chest, real belly, heavier bulk.
    "innkeeper": {
        "proportions": {
            "leg_length": 1.60,
            "arm_length": 1.20,
            "shoulder_width": 0.92,
            "torso_length": 0.92,
        },
        "shape": {
            "bulk": 1.12,
            "chest_breadth": 1.10,
            "belly": 1.35,
            "head_scale": 1.05,
        },
        "palette": {
            "tunic": (0.45, 0.36, 0.24, 1.0),
            "pants": (0.28, 0.24, 0.20, 1.0),
            "hair": (0.38, 0.30, 0.24, 1.0),
            "beard": (0.32, 0.24, 0.18, 1.0),
        },
        "output": "assets/characters/shared/innkeeper.glb",
        "garments": [],
    },
}


def spec(name: str) -> dict:
    if name not in CHARACTERS:
        raise KeyError(
            f"unknown character spec '{name}'; known: {sorted(CHARACTERS)}"
        )
    entry = CHARACTERS[name]
    return {
        "name": name,
        "proportions": {**BASE_PROPORTIONS, **entry.get("proportions", {})},
        "shape": {**BASE_SHAPE, **entry.get("shape", {})},
        "palette": entry.get("palette", {}),
        "output": entry["output"],
        "garments": entry.get("garments", []),
        "skeleton_intermediate": f"tools/character_build/{name}_skeleton.glb",
    }
