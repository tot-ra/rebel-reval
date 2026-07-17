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
  generator (skin, tunic, sleeves, sleeve_band, pants, boots, belt, hair,
  beard, eyes, ...).
- output: runtime glb path relative to the repo root.
- garments: garment ids to export as separate skinned glbs next to the
  body ("cape", "hat"). Usually only the shared hero set carries these.
"""

BASE_PROPORTIONS = {
    "leg_length": 1.85,
    "arm_length": 1.25,
    "torso_length": 0.88,
    "shoulder_width": 0.78,
    "hip_socket_width": 0.95,
    "head_size": 0.32,
    "hand_size": 0.85,
    # Degrees the upper arms rotate around +Z (shoulder fold). Sets elbow
    # breadth: lower values keep elbows wider, higher values glue them to the
    # ribs. The CC0 KayKit clips assume a barrel-wide chibi torso.
    "arm_relax_degrees": 30.0,
    # Extra +Z fold applied only on the forearm bones. This swings the
    # handslots forward without pulling the elbows inward the way a single
    # shared angle did before.
    "forearm_relax_degrees": 52.0,
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
    # Palette matches the legacy Kalev pixel sprite (img/user__idle.gif).
    "hero": {
        "palette": {
            "tunic": (0.38, 0.24, 0.14, 1.0),
            "sleeves": (0.84, 0.83, 0.80, 1.0),
            "sleeve_band": (0.22, 0.42, 0.72, 1.0),
            "pants": (0.16, 0.12, 0.10, 1.0),
            "boots": (0.42, 0.28, 0.16, 1.0),
            "belt": (0.62, 0.46, 0.28, 1.0),
            "hair": (0.48, 0.32, 0.20, 1.0),
            "beard": (0.42, 0.28, 0.16, 1.0),
        },
        "output": "assets/characters/shared/heroic_humanoid.glb",
        "garments": ["cape", "hat"],
    },
    # Captain Henning: tall, broad-shouldered and disciplined. The dark Watch
    # palette and heavier upper body keep his authority readable at gameplay
    # scale without introducing bespoke runtime geometry.
    "henning": {
        "proportions": {
            "leg_length": 1.90,
            "arm_length": 1.28,
            "torso_length": 0.92,
            "shoulder_width": 0.96,
            "hip_socket_width": 1.0,
        },
        "shape": {
            "bulk": 1.10,
            "chest_breadth": 1.14,
            "belly": 1.04,
            "head_scale": 0.98,
        },
        "palette": {
            "skin": (0.73, 0.52, 0.38, 1.0),
            "tunic": (0.20, 0.25, 0.30, 1.0),
            "pants": (0.15, 0.17, 0.19, 1.0),
            "boots": (0.11, 0.09, 0.08, 1.0),
            "belt": (0.31, 0.20, 0.13, 1.0),
            "hair": (0.29, 0.23, 0.18, 1.0),
            "beard": (0.24, 0.19, 0.15, 1.0),
            "eyes": (0.05, 0.06, 0.07, 1.0),
        },
        "output": "assets/characters/shared/henning.glb",
        "garments": [],
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
