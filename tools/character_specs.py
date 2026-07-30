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
- face: portrait-scale identity knobs merged over BASE_FACE; consumed by the
  head generator without changing the shared head bone or animation tracks.
- features: discrete identity and clothing knobs merged over BASE_FEATURES;
  consumed by the body generator (hair_style, beard_style, sleeve_style,
  tunic_length, outerwear, pauldrons).
- palette: sRGB color overrides merged over the base PALETTE of the
  generator (skin, tunic, sleeves, sleeve_band, pants, boots, belt, hair,
  beard, eyes, outerwear, trim, ...).
- output: runtime glb path relative to the repo root.
- fidelity_tier: 0 = hero cast (Kalev, Mart, Aita, Kaja, Henning, Jürgen, Ellen base),
  1 = named NPC (shopkeepers, faction figures), 2 = crowd/battle (future). Frozen caps
  live in tools/character_fidelity_tiers.py and docs/VISUAL_FIDELITY_PLAN.md.
- garments: garment ids to export as separate skinned glbs next to the
  body ("cape", "hat"). Usually only the shared hero set carries these.
"""

BASE_PROPORTIONS = {
    "leg_length": 1.85,
    "arm_length": 1.25,
    "torso_length": 0.88,
    "shoulder_width": 0.78,
    # Height of the arm sockets above the chest bone. The chibi carries them
    # halfway up to the head, which left them 1.4 cm below the neck base: any
    # deltoid mass around such a socket rises past the neck and reads as huge
    # shoulder pads on a character with no neck. Dropping them puts the
    # acromion below the neck base, as on a real shoulder girdle.
    "shoulder_drop": 0.62,
    # Lateral placement of the hip joints. The chibi source stands splay-legged:
    # at the old 0.95 the sockets sat 0.325 m apart on a 1.63 m body - wider
    # than the pelvis itself - so the thighs emerged outside the hips instead of
    # under them. Every spec was narrowed by the same ratio, keeping body-type
    # differences relative.
    "hip_socket_width": 0.62,
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

# Default feature set for the body generator. Specs override individual keys
# to change identity and situation without adding runtime branches:
# - hair_style: "full" | "short" | "bald" | "ponytail" | "bun" | "long"
# - beard_style: "full" | "short" | "none"
# - sleeve_style: "long" (tunic sleeve + undersleeves + cuff) | "bare" (short
#   tunic sleeve, skin to the wrist)
# - tunic_length: "long" (knee hem) | "short" (hip hem)
# - outerwear: "none" | "apron" | "vest" | "surcoat" | "kirtle"
# - armor_style: "none" | "mail"; mail replaces the torso/upper-sleeve shell
#   while leaving the anatomical skin envelope and cloth layers independent.
# - anatomical_layers: build skin, muscle-shaped silhouette, and clothing as
#   separate skinned meshes around the same skeleton.
# - pauldrons: shoulder armor plates baked into the body glb
BASE_FEATURES = {
    "hair_style": "full",
    "beard_style": "full",
    "sleeve_style": "long",
    "tunic_length": "long",
    "outerwear": "none",
    "armor_style": "none",
    "anatomical_layers": True,
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

# Face values are deliberately independent from head_scale. This lets named
# characters have recognisable portrait silhouettes while preserving a shared
# head bone, attachment point and complete animation library.
BASE_FACE = {
    "width": 1.0,
    "depth": 1.0,
    "length": 1.0,
    "jaw_width": 1.0,
    "nose_length": 1.0,
    "eye_spacing": 1.0,
    "brow_height": 1.0,
}

CHARACTERS = {
    # Kalev is the player's working blacksmith body. The leather apron and
    # rolled-looking pale sleeves keep his profession legible from behind,
    # where the gameplay camera sees him most often.
    "hero": {
        "shape": {
            "bulk": 1.05,
            "chest_breadth": 1.08,
            "belly": 1.01,
            "head_scale": 0.98,
        },
        "face": {
            "width": 0.97,
            "depth": 1.02,
            "length": 1.04,
            "jaw_width": 1.06,
            "nose_length": 1.05,
            "brow_height": 0.92,
        },
        "features": {
            "hair_style": "short",
            "beard_style": "short",
            "tunic_length": "short",
            "outerwear": "apron",
        },
        "palette": {
            "tunic": (0.38, 0.24, 0.14, 1.0),
            "sleeves": (0.84, 0.83, 0.80, 1.0),
            "sleeve_band": (0.22, 0.42, 0.72, 1.0),
            "pants": (0.16, 0.12, 0.10, 1.0),
            "boots": (0.42, 0.28, 0.16, 1.0),
            "belt": (0.62, 0.46, 0.28, 1.0),
            "hair": (0.48, 0.32, 0.20, 1.0),
            "beard": (0.42, 0.28, 0.16, 1.0),
            "outerwear": (0.24, 0.16, 0.10, 1.0),
            "trim": (0.48, 0.31, 0.17, 1.0),
        },
        "output": "assets/characters/shared/heroic_humanoid.glb",
        "fidelity_tier": 0,
        "garments": ["cape", "hat"],
    },
    # Mart is a named person, not a tint of Kalev. His adolescent skeleton,
    # narrower frame and plain vest remain compatible with every shared clip.
    "mart": {
        "proportions": {
            "leg_length": 1.72,
            "arm_length": 1.16,
            "torso_length": 0.82,
            "shoulder_width": 0.66,
            "hip_socket_width": 0.59,
            "head_size": 0.31,
            "hand_size": 0.76,
            "arm_relax_degrees": 48.0,
            "forearm_relax_degrees": 42.0,
        },
        "shape": {
            "bulk": 0.86,
            "chest_breadth": 0.91,
            "belly": 0.94,
            "head_scale": 1.01,
        },
        "face": {
            "width": 0.92,
            "depth": 0.96,
            "length": 1.02,
            "jaw_width": 0.88,
            "nose_length": 0.91,
            "eye_spacing": 1.04,
            "brow_height": 1.05,
        },
        "features": {
            "hair_style": "full",
            "beard_style": "none",
            "tunic_length": "short",
            "outerwear": "vest",
        },
        "palette": {
            "skin": (0.82, 0.62, 0.46, 1.0),
            "tunic": (0.48, 0.43, 0.33, 1.0),
            "sleeves": (0.72, 0.69, 0.60, 1.0),
            "sleeve_band": (0.32, 0.44, 0.38, 1.0),
            "pants": (0.18, 0.20, 0.20, 1.0),
            "boots": (0.30, 0.22, 0.15, 1.0),
            "belt": (0.38, 0.25, 0.15, 1.0),
            "hair": (0.36, 0.24, 0.15, 1.0),
            "outerwear": (0.27, 0.31, 0.27, 1.0),
            "trim": (0.45, 0.39, 0.27, 1.0),
        },
        "output": "assets/characters/shared/mart.glb",
        "fidelity_tier": 0,
        "garments": [],
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
            "hip_socket_width": 0.65,
        },
        "shape": {
            "bulk": 1.10,
            "chest_breadth": 1.14,
            "belly": 1.04,
            "head_scale": 0.98,
        },
        "face": {
            "width": 1.02,
            "depth": 1.02,
            "length": 1.08,
            "jaw_width": 1.12,
            "nose_length": 1.08,
            "eye_spacing": 0.96,
            "brow_height": 0.88,
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
            "outerwear": (0.24, 0.27, 0.31, 1.0),
            "trim": (0.58, 0.49, 0.31, 1.0),
        },
        # A career officer reads clean-cut: cropped hair, no beard, plated
        # shoulders and a belted surcoat over the darker uniform.
        "features": {
            "hair_style": "short",
            "beard_style": "none",
            "outerwear": "surcoat",
            "pauldrons": True,
        },
        "output": "assets/characters/shared/henning.glb",
        "fidelity_tier": 0,
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
        "face": {
            "width": 1.10,
            "depth": 1.08,
            "length": 0.96,
            "jaw_width": 1.08,
            "nose_length": 1.04,
            "eye_spacing": 1.03,
            "brow_height": 1.02,
        },
        "palette": {
            "tunic": (0.45, 0.36, 0.24, 1.0),
            "pants": (0.28, 0.24, 0.20, 1.0),
            "hair": (0.38, 0.30, 0.24, 1.0),
            "beard": (0.32, 0.24, 0.18, 1.0),
            "outerwear": (0.29, 0.18, 0.11, 1.0),
            "trim": (0.55, 0.39, 0.22, 1.0),
        },
        "features": {
            "hair_style": "bun",
            "beard_style": "short",
            "sleeve_style": "bare",
            "tunic_length": "short",
            "outerwear": "apron",
        },
        "output": "assets/characters/shared/innkeeper.glb",
        "fidelity_tier": 1,
        "garments": [],
    },
    # Rank-and-file town watch: slimmer than the hero, spear-equipped, no
    # pauldrons. The narrow shoulders and hip-length hem read as a patrol guard
    # rather than a guild worker or officer.
    "watchman": {
        "proportions": {
            "leg_length": 1.78,
            "arm_length": 1.22,
            "torso_length": 0.86,
            "shoulder_width": 0.72,
            "hip_socket_width": 0.6,
        },
        "shape": {
            "bulk": 0.94,
            "chest_breadth": 0.96,
            "belly": 0.96,
            "head_scale": 0.98,
        },
        "face": {
            "width": 0.94,
            "depth": 1.0,
            "length": 1.04,
            "jaw_width": 0.96,
            "nose_length": 1.02,
            "eye_spacing": 0.98,
            "brow_height": 0.94,
        },
        "palette": {
            "tunic": (0.34, 0.33, 0.30, 1.0),
            "sleeves": (0.72, 0.70, 0.66, 1.0),
            "pants": (0.18, 0.17, 0.16, 1.0),
            "boots": (0.24, 0.20, 0.16, 1.0),
            "belt": (0.42, 0.34, 0.22, 1.0),
            "hair": (0.28, 0.22, 0.18, 1.0),
            "beard": (0.24, 0.19, 0.15, 1.0),
            "outerwear": (0.29, 0.30, 0.29, 1.0),
            "trim": (0.46, 0.42, 0.31, 1.0),
        },
        "features": {
            "hair_style": "short",
            "beard_style": "none",
            "tunic_length": "short",
            "outerwear": "vest",
        },
        "output": "assets/characters/shared/watchman.glb",
        "fidelity_tier": 1,
        "garments": [],
    },
    # Livonian watch sergeant: broader and taller than the watchman, with baked
    # pauldrons and a helmet garment. Stays below Captain Henning so rank reads
    # at gameplay scale without sharing the captain's silhouette.
    "sergeant": {
        "proportions": {
            "leg_length": 1.84,
            "arm_length": 1.26,
            "torso_length": 0.90,
            "shoulder_width": 0.88,
            "hip_socket_width": 0.64,
        },
        "shape": {
            "bulk": 1.06,
            "chest_breadth": 1.10,
            "belly": 1.02,
            "head_scale": 0.98,
        },
        "face": {
            "width": 1.04,
            "depth": 1.03,
            "length": 1.02,
            "jaw_width": 1.08,
            "nose_length": 1.03,
            "eye_spacing": 0.96,
            "brow_height": 0.90,
        },
        "palette": {
            "tunic": (0.24, 0.26, 0.30, 1.0),
            "pants": (0.14, 0.15, 0.17, 1.0),
            "boots": (0.10, 0.09, 0.08, 1.0),
            "belt": (0.34, 0.22, 0.14, 1.0),
            "hair": (0.26, 0.20, 0.16, 1.0),
            "armor": (0.42, 0.44, 0.48, 1.0),
            "outerwear": (0.31, 0.32, 0.35, 1.0),
            "trim": (0.56, 0.48, 0.31, 1.0),
        },
        "features": {
            "hair_style": "short",
            "beard_style": "none",
            "outerwear": "surcoat",
            "pauldrons": True,
        },
        "output": "assets/characters/shared/sergeant.glb",
        "fidelity_tier": 1,
        "garments": ["hat"],
    },
    # Danish crown man-at-arms reference for the Toompea garrison. Unlike the
    # Lower Town burgher watch, he can plausibly carry a mail hauberk; the red
    # and off-white cloth identifies Danish allegiance without claiming a
    # modern national uniform. His body uses the same anatomy-first skeleton,
    # muscle, skin, and clothing contract as every other generated humanoid.
    "danish_warrior": {
        "proportions": {
            "leg_length": 1.88,
            "arm_length": 1.27,
            "torso_length": 0.91,
            "shoulder_width": 0.90,
            "hip_socket_width": 0.64,
            "hand_size": 0.84,
        },
        "shape": {
            "bulk": 1.04,
            "chest_breadth": 1.08,
            "belly": 1.0,
            "head_scale": 0.97,
        },
        "face": {
            "width": 1.0,
            "depth": 1.02,
            "length": 1.05,
            "jaw_width": 1.08,
            "nose_length": 1.04,
            "eye_spacing": 0.97,
            "brow_height": 0.91,
        },
        "palette": {
            "skin": (0.74, 0.55, 0.41, 1.0),
            "tunic": (0.80, 0.77, 0.67, 1.0),
            "sleeves": (0.76, 0.74, 0.68, 1.0),
            "sleeve_band": (0.48, 0.10, 0.09, 1.0),
            "pants": (0.36, 0.13, 0.12, 1.0),
            "boots": (0.22, 0.14, 0.09, 1.0),
            "belt": (0.35, 0.20, 0.11, 1.0),
            "hair": (0.30, 0.22, 0.15, 1.0),
            "beard": (0.27, 0.19, 0.13, 1.0),
            "mail": (0.38, 0.41, 0.43, 1.0),
            "outerwear": (0.48, 0.10, 0.09, 1.0),
            "trim": (0.82, 0.77, 0.61, 1.0),
        },
        "features": {
            "hair_style": "short",
            "beard_style": "short",
            "sleeve_style": "long",
            "tunic_length": "short",
            "outerwear": "surcoat",
            "armor_style": "mail",
            "anatomical_layers": True,
        },
        "output": "assets/characters/shared/danish_warrior.glb",
        "fidelity_tier": 1,
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
            "hip_socket_width": 0.69,
            "head_size": 0.30,
            "hand_size": 0.72,
        },
        "shape": {
            "bulk": 0.90,
            "chest_breadth": 0.92,
            "belly": 0.98,
            "head_scale": 1.0,
        },
        "face": {
            "width": 0.94,
            "depth": 0.96,
            "length": 1.01,
            "jaw_width": 0.92,
            "nose_length": 0.98,
            "eye_spacing": 1.05,
            "brow_height": 1.03,
        },
        "palette": {
            "tunic": (0.30, 0.36, 0.30, 1.0),
            "sleeves": (0.86, 0.84, 0.78, 1.0),
            "sleeve_band": (0.52, 0.32, 0.24, 1.0),
            "pants": (0.20, 0.16, 0.14, 1.0),
            "boots": (0.30, 0.22, 0.15, 1.0),
            "belt": (0.55, 0.42, 0.26, 1.0),
            "hair": (0.30, 0.20, 0.12, 1.0),
            "outerwear": (0.60, 0.53, 0.39, 1.0),
            "trim": (0.48, 0.29, 0.20, 1.0),
        },
        "features": {
            "hair_style": "long",
            "beard_style": "none",
            "outerwear": "kirtle",
        },
        "output": "assets/characters/shared/townswoman.glb",
        "fidelity_tier": 0,
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
        "face": {**BASE_FACE, **entry.get("face", {})},
        "features": {**BASE_FEATURES, **entry.get("features", {})},
        "palette": entry.get("palette", {}),
        "output": entry["output"],
        "fidelity_tier": int(entry.get("fidelity_tier", 1)),
        "garments": entry.get("garments", []),
        "skeleton_intermediate": f"tools/character_build/{name}_skeleton.glb",
    }
