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
- features: discrete identity knobs merged over BASE_FEATURES; consumed by
  the body generator (hair_style, beard_style, sleeve_style, tunic_length,
  pauldrons).
- palette: sRGB color overrides merged over the base PALETTE of the
  generator (skin, tunic, sleeves, sleeve_band, pants, boots, belt, hair,
  beard, eyes, armor, ...).
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
    # ribs. The CC0 KayKit clips assume a barrel-wide chibi torso; on the
    # adult frame mid-30s still read as hands held too far apart in run.
    "arm_relax_degrees": 52.0,
    # Extra +Z fold applied only on the forearm bones. Brings handslots
    # forward so elbows do not trail behind the torso on locomotion; kept
    # below ~50° because larger offsets pushed hands up to the face.
    "forearm_relax_degrees": 45.0,
}

# Default feature set for the body generator (see generate_hero_body.py).
# Specs override individual keys to change identity without new code:
# - hair_style: "full" | "short" | "bald" | "ponytail" | "bun" | "long"
# - beard_style: "full" | "short" | "none"
# - sleeve_style: "long" (tunic sleeve + undersleeves + cuff) | "bare" (short
#   tunic sleeve, skin to the wrist)
# - tunic_length: "long" (knee hem) | "short" (hip hem)
# - pauldrons: shoulder armor plates baked into the body glb
BASE_FEATURES = {
    "hair_style": "full",
    "beard_style": "full",
    "sleeve_style": "long",
    "tunic_length": "long",
    "pauldrons": False,
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
    # Palette matches the legacy Kalev pixel sprite (character/inspiration/user__idle.gif).
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
            "armor": (0.38, 0.40, 0.44, 1.0),
        },
        # A career officer reads clean-cut: cropped hair, no beard, and
        # pauldrons that widen the already broad shoulder line.
        "features": {
            "hair_style": "short",
            "beard_style": "none",
            "pauldrons": True,
        },
        "output": "assets/characters/shared/henning.glb",
        "garments": [],
    },
    # Worked example for docs/CHARACTER_GENERATION.md: a stocky innkeeper
    # frame — shorter legs, broad chest, real belly, heavier bulk. Bare
    # forearms, a hip-length tunic and a bun keep him unmistakable next to
    # the long-tunicked, full-haired hero.
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
        "features": {
            "hair_style": "bun",
            "beard_style": "short",
            "sleeve_style": "bare",
            "tunic_length": "short",
        },
        "output": "assets/characters/shared/innkeeper.glb",
        "garments": [],
    },
    # A slighter townswoman frame: shorter and narrower than the hero, with
    # long hair and an ankle-length tunic reading as a dress. Base body for
    # tint variants of the female cast (Aita, Kaja) until P2-004 approves
    # bespoke briefs.
    "townswoman": {
        "proportions": {
            "leg_length": 1.74,
            "arm_length": 1.18,
            "torso_length": 0.86,
            "shoulder_width": 0.64,
            "hip_socket_width": 1.05,
            "head_size": 0.30,
            "hand_size": 0.72,
        },
        "shape": {
            "bulk": 0.90,
            "chest_breadth": 0.92,
            "belly": 0.98,
            "head_scale": 1.0,
        },
        "palette": {
            "tunic": (0.30, 0.36, 0.30, 1.0),
            "sleeves": (0.86, 0.84, 0.78, 1.0),
            "sleeve_band": (0.52, 0.32, 0.24, 1.0),
            "pants": (0.20, 0.16, 0.14, 1.0),
            "boots": (0.30, 0.22, 0.15, 1.0),
            "belt": (0.55, 0.42, 0.26, 1.0),
            "hair": (0.30, 0.20, 0.12, 1.0),
        },
        "features": {
            "hair_style": "long",
            "beard_style": "none",
        },
        "output": "assets/characters/shared/townswoman.glb",
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
        "features": {**BASE_FEATURES, **entry.get("features", {})},
        "palette": entry.get("palette", {}),
        "output": entry["output"],
        "garments": entry.get("garments", []),
        "skeleton_intermediate": f"tools/character_build/{name}_skeleton.glb",
    }
