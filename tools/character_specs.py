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
    # Road bandit: a leaner civilian frame in patched dark wool and leather. He
    # has no Order insignia or armour, so the silhouette reads as a criminal
    # threat rather than another watch rank while retaining the shared rig clips.
    "bandit": {
        "proportions": {
            "leg_length": 1.80,
            "arm_length": 1.24,
            "torso_length": 0.86,
            "shoulder_width": 0.70,
            "hip_socket_width": 0.60,
            "hand_size": 0.80,
        },
        "shape": {
            "bulk": 0.92,
            "chest_breadth": 0.94,
            "belly": 0.92,
            "head_scale": 1.0,
        },
        "face": {
            "width": 0.98,
            "depth": 1.02,
            "length": 1.03,
            "jaw_width": 1.02,
            "nose_length": 1.02,
            "eye_spacing": 1.0,
            "brow_height": 0.96,
        },
        "palette": {
            "tunic": (0.16, 0.13, 0.12, 1.0),
            "sleeves": (0.30, 0.28, 0.25, 1.0),
            "sleeve_band": (0.42, 0.12, 0.08, 1.0),
            "pants": (0.12, 0.12, 0.13, 1.0),
            "boots": (0.18, 0.10, 0.07, 1.0),
            "belt": (0.25, 0.14, 0.08, 1.0),
            "hair": (0.12, 0.09, 0.07, 1.0),
            "beard": (0.10, 0.08, 0.06, 1.0),
            "outerwear": (0.25, 0.11, 0.08, 1.0),
            "trim": (0.46, 0.18, 0.10, 1.0),
        },
        "features": {
            "hair_style": "full",
            "beard_style": "short",
            "sleeve_style": "long",
            "tunic_length": "short",
            "outerwear": "vest",
        },
        "output": "assets/characters/shared/bandit.glb",
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
    # Aita, Kalev's older sister: a sturdy brewer/healer frame. The short
    # tunic, apron and bun make her work readable while keeping her on the
    # shared humanoid skeleton and full animation library.
    "aita": {
        "proportions": {
            "leg_length": 1.68,
            "arm_length": 1.20,
            "torso_length": 0.92,
            "shoulder_width": 0.70,
            "hip_socket_width": 0.72,
            "head_size": 0.31,
            "hand_size": 0.76,
        },
        "shape": {
            "bulk": 1.04,
            "chest_breadth": 1.06,
            "belly": 1.10,
            "head_scale": 1.03,
        },
        "face": {
            "width": 1.05,
            "depth": 1.02,
            "length": 0.98,
            "jaw_width": 1.03,
            "nose_length": 0.98,
            "eye_spacing": 1.02,
            "brow_height": 1.04,
        },
        "palette": {
            "skin": (0.82, 0.62, 0.46, 1.0),
            "tunic": (0.24, 0.34, 0.24, 1.0),
            "sleeves": (0.72, 0.66, 0.54, 1.0),
            "pants": (0.22, 0.18, 0.15, 1.0),
            "boots": (0.29, 0.19, 0.12, 1.0),
            "belt": (0.48, 0.31, 0.17, 1.0),
            "hair": (0.24, 0.12, 0.07, 1.0),
            "outerwear": (0.34, 0.20, 0.11, 1.0),
            "trim": (0.58, 0.43, 0.24, 1.0),
        },
        "features": {
            "hair_style": "bun",
            "beard_style": "none",
            "sleeve_style": "long",
            "tunic_length": "short",
            "outerwear": "apron",
        },
        "output": "assets/characters/shared/aita.glb",
        "fidelity_tier": 0,
        "garments": [],
    },
    # Kaja, the bilingual courier: leaner shoulders, longer stride and a
    # practical vest/ponytail silhouette for a mobile rebel liaison.
    "kaja": {
        "proportions": {
            "leg_length": 1.82,
            "arm_length": 1.20,
            "torso_length": 0.84,
            "shoulder_width": 0.62,
            "hip_socket_width": 0.68,
            "head_size": 0.30,
            "hand_size": 0.72,
        },
        "shape": {
            "bulk": 0.86,
            "chest_breadth": 0.88,
            "belly": 0.92,
            "head_scale": 0.98,
        },
        "face": {
            "width": 0.92,
            "depth": 0.98,
            "length": 1.05,
            "jaw_width": 0.88,
            "nose_length": 1.02,
            "eye_spacing": 1.06,
            "brow_height": 1.02,
        },
        "palette": {
            "skin": (0.76, 0.55, 0.40, 1.0),
            "tunic": (0.22, 0.28, 0.38, 1.0),
            "sleeves": (0.65, 0.52, 0.40, 1.0),
            "pants": (0.16, 0.18, 0.23, 1.0),
            "boots": (0.20, 0.13, 0.09, 1.0),
            "belt": (0.36, 0.22, 0.13, 1.0),
            "hair": (0.13, 0.08, 0.06, 1.0),
            "outerwear": (0.28, 0.18, 0.16, 1.0),
            "trim": (0.45, 0.36, 0.23, 1.0),
        },
        "features": {
            "hair_style": "ponytail",
            "beard_style": "none",
            "sleeve_style": "long",
            "tunic_length": "short",
            "outerwear": "vest",
        },
        "output": "assets/characters/shared/kaja.glb",
        "fidelity_tier": 0,
        "garments": [],
    },
    # Jürgen Witte: a tall, well-fed Hanseatic merchant. The restrained
    # surcoat and fuller torso distinguish wealth without adding a new rig.
    "jurgen": {
        "proportions": {
            "leg_length": 1.88,
            "arm_length": 1.27,
            "torso_length": 0.94,
            "shoulder_width": 0.86,
            "hip_socket_width": 0.66,
            "hand_size": 0.82,
        },
        "shape": {
            "bulk": 1.06,
            "chest_breadth": 1.08,
            "belly": 1.16,
            "head_scale": 1.01,
        },
        "face": {
            "width": 1.04,
            "depth": 1.05,
            "length": 1.02,
            "jaw_width": 1.04,
            "nose_length": 1.06,
            "eye_spacing": 0.98,
            "brow_height": 0.96,
        },
        "palette": {
            "skin": (0.76, 0.56, 0.42, 1.0),
            "tunic": (0.34, 0.18, 0.22, 1.0),
            "sleeves": (0.62, 0.52, 0.42, 1.0),
            "pants": (0.16, 0.15, 0.18, 1.0),
            "boots": (0.20, 0.12, 0.08, 1.0),
            "belt": (0.38, 0.23, 0.12, 1.0),
            "hair": (0.36, 0.22, 0.12, 1.0),
            "beard": (0.30, 0.18, 0.10, 1.0),
            "outerwear": (0.38, 0.16, 0.18, 1.0),
            "trim": (0.72, 0.56, 0.29, 1.0),
        },
        "features": {
            "hair_style": "full",
            "beard_style": "short",
            "sleeve_style": "long",
            "tunic_length": "long",
            "outerwear": "vest",
        },
        "output": "assets/characters/shared/jurgen.glb",
        "fidelity_tier": 0,
        "garments": [],
    },
    # Ellen Luik: an older midwife and song-keeper whose compact, grounded
    # frame, wrapped kirtle and bun remain readable without relying on color.
    "ellen": {
        "proportions": {
            "leg_length": 1.62,
            "arm_length": 1.15,
            "torso_length": 0.91,
            "shoulder_width": 0.67,
            "hip_socket_width": 0.71,
            "head_size": 0.32,
            "hand_size": 0.75,
        },
        "shape": {
            "bulk": 0.96,
            "chest_breadth": 0.97,
            "belly": 1.08,
            "head_scale": 1.04,
        },
        "face": {
            "width": 1.02,
            "depth": 1.00,
            "length": 1.02,
            "jaw_width": 0.98,
            "nose_length": 1.08,
            "eye_spacing": 1.01,
            "brow_height": 0.95,
        },
        "palette": {
            "skin": (0.72, 0.52, 0.39, 1.0),
            "tunic": (0.27, 0.25, 0.20, 1.0),
            "sleeves": (0.54, 0.49, 0.39, 1.0),
            "pants": (0.18, 0.16, 0.14, 1.0),
            "boots": (0.24, 0.17, 0.11, 1.0),
            "belt": (0.38, 0.25, 0.14, 1.0),
            "hair": (0.30, 0.29, 0.27, 1.0),
            "outerwear": (0.35, 0.29, 0.20, 1.0),
            "trim": (0.50, 0.42, 0.28, 1.0),
        },
        "features": {
            "hair_style": "bun",
            "beard_style": "none",
            "sleeve_style": "long",
            "tunic_length": "long",
            "outerwear": "kirtle",
        },
        "output": "assets/characters/shared/ellen.glb",
        "fidelity_tier": 0,
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


# ---------------------------------------------------------------------------
# P0-153 procedural crowd variation.
#
# Hand-authored specs above give named people. Townsfolk need many bodies that
# are not clones, so a crowd variant is derived from a neutral template and a
# seed: `crowd_variant_entry(template, seed)` always returns the same entry for
# the same pair (string-seeded `random.Random` hashes with SHA-512, so it is
# stable across processes and Python versions). The committed roster below is
# merged into CHARACTERS, so the skeleton retarget, body generator, LOD tool,
# shared-texture linker and asset lint treat every variant like any spec.
#
# Surface maps stay the shared palette-neutral family set (P0-200 forbids
# per-body PNG copies); "PBR texture swaps" are therefore expressed as the
# palette multiplied over those maps plus a per-variant `material_response`
# normal-strength multiplier per family (felted vs crisp wool, supple vs
# cracked leather), which the exporter writes as glTF `normalTexture.scale`.
# ---------------------------------------------------------------------------

CROWD_OUTPUT_DIR = "assets/characters/shared"
CROWD_MANIFEST = "assets/characters/variants/crowd_variation_manifest.json"

# Neutral adult frames. Variation multiplies these, so templates stay close to
# the middle of the range instead of reusing a caricatured named body.
CROWD_TEMPLATES = {
    "townsman": {
        "proportions": {},
        "shape": {"bulk": 1.0, "chest_breadth": 1.0, "belly": 1.04, "head_scale": 1.0},
        "stature_range": (0.91, 1.05),
        "choices": {
            "hair_style": ("full", "short", "short", "bald"),
            "beard_style": ("full", "short", "none"),
            "sleeve_style": ("long", "long", "bare"),
            "tunic_length": ("long", "short"),
            "outerwear": ("none", "apron", "vest"),
        },
        "grey_hair_chance": 0.2,
    },
    "townswoman": {
        # Same slighter frame as the authored townswoman body.
        "proportions": {
            "leg_length": 1.74,
            "arm_length": 1.18,
            "torso_length": 0.86,
            "shoulder_width": 0.64,
            "hip_socket_width": 0.69,
            "head_size": 0.30,
            "hand_size": 0.72,
        },
        "shape": {"bulk": 0.90, "chest_breadth": 0.92, "belly": 0.98, "head_scale": 1.0},
        "stature_range": (0.93, 1.05),
        "choices": {
            "hair_style": ("long", "bun", "ponytail"),
            "beard_style": ("none",),
            "sleeve_style": ("long",),
            "tunic_length": ("long",),
            "outerwear": ("kirtle", "kirtle", "none"),
        },
        "grey_hair_chance": 0.15,
    },
}

# Complexion endpoints (sRGB) for a Baltic/North German port population:
# fair indoor skin to wind- and sun-weathered outdoor workers.
CROWD_SKIN_FAIR = (0.87, 0.69, 0.56)
CROWD_SKIN_WEATHERED = (0.68, 0.47, 0.34)

CROWD_HAIR = {
    "flaxen": (0.68, 0.55, 0.34),
    "light_brown": (0.48, 0.34, 0.21),
    "dark_brown": (0.25, 0.17, 0.11),
    "auburn": (0.52, 0.27, 0.14),
    "grey": (0.57, 0.55, 0.51),
}

# Commoner cloth colours reachable with 14th-century Baltic dyes: undyed wool,
# woad, madder, weld, walnut hulls and woad-over-weld green. Deliberately muted:
# saturated kermes reds and bright blues belonged to wealthier patrons.
CROWD_DYES = {
    "undyed_grey": (0.46, 0.44, 0.40),
    "undyed_brown": (0.36, 0.28, 0.20),
    "woad_blue": (0.27, 0.35, 0.46),
    "madder_red": (0.52, 0.25, 0.18),
    "weld_yellow": (0.60, 0.52, 0.28),
    "walnut_brown": (0.30, 0.21, 0.14),
    "woad_weld_green": (0.35, 0.40, 0.28),
}
CROWD_LINEN = {
    "bleached_linen": (0.84, 0.82, 0.76),
    "raw_linen": (0.72, 0.67, 0.56),
}
CROWD_LEATHER = {
    "tan": (0.50, 0.35, 0.21),
    "dark": (0.28, 0.20, 0.14),
    "oiled": (0.38, 0.26, 0.16),
}

CROWD_GAITS = ("Walking_A", "Walking_B", "Walking_C")

# Normal-strength multipliers per texture family (see hero_body_textures).
CROWD_MATERIAL_RESPONSE_RANGE = {"cloth": (0.75, 1.35), "leather": (0.8, 1.3)}

# Committed individuated roster: (template, seed). Adding a body is one row
# here plus `tools/rebuild_hero_character.sh crowd_<template>_<seed:02d>`.
CROWD_ROSTER = (
    ("townsman", 1),
    ("townsman", 2),
    ("townswoman", 1),
    ("townswoman", 2),
)


def crowd_variant_name(template: str, seed: int) -> str:
    return f"crowd_{template}_{seed:02d}"


def _jitter(rng, low: float, high: float) -> float:
    return round(rng.uniform(low, high), 4)


def _faded(rng, color: tuple, spread: float = 0.04) -> tuple:
    """Per-garment wear: sun-bleaching or grime shifts one dye lot slightly."""
    shift = rng.uniform(-spread, spread)
    return tuple(round(min(1.0, max(0.0, channel + shift)), 4) for channel in color) + (1.0,)


def crowd_variant_entry(template: str, seed: int) -> dict:
    """Return a CHARACTERS-style entry for one deterministic crowd body."""
    import random

    if template not in CROWD_TEMPLATES:
        raise KeyError(f"unknown crowd template '{template}'; known: {sorted(CROWD_TEMPLATES)}")
    base = CROWD_TEMPLATES[template]
    rng = random.Random(f"reval-crowd:{template}:{seed}")

    # Stature scales the bone chain lengths the retarget reads, so the whole
    # animation library follows the new height. Head size is left alone: a
    # taller adult does not grow a proportionally larger head.
    stature = _jitter(rng, *base["stature_range"])
    proportions = {**BASE_PROPORTIONS, **base["proportions"]}
    varied_proportions = {
        key: round(proportions[key] * stature, 4)
        for key in ("leg_length", "arm_length", "torso_length")
    }
    build = _jitter(rng, 0.88, 1.14)
    varied_proportions["shoulder_width"] = round(
        proportions["shoulder_width"] * (1.0 + (build - 1.0) * 0.6), 4
    )
    shape = dict(base["shape"])
    shape["bulk"] = round(shape["bulk"] * build, 4)
    shape["chest_breadth"] = round(shape["chest_breadth"] * _jitter(rng, 0.94, 1.08), 4)
    shape["belly"] = round(shape["belly"] * _jitter(rng, 0.92, 1.22), 4)
    face = {key: _jitter(rng, 0.93, 1.07) for key in BASE_FACE}

    features = {key: rng.choice(options) for key, options in base["choices"].items()}
    if features["outerwear"] == "apron" and features["tunic_length"] == "long":
        # The generated apron is fitted over a hip-length hem only.
        features["tunic_length"] = "short"

    tone = rng.random()
    skin = tuple(
        round(fair + (weathered - fair) * tone, 4)
        for fair, weathered in zip(CROWD_SKIN_FAIR, CROWD_SKIN_WEATHERED)
    ) + (1.0,)
    if rng.random() < base["grey_hair_chance"]:
        hair_name = "grey"
    else:
        hair_name = rng.choice(sorted(name for name in CROWD_HAIR if name != "grey"))
    hair = CROWD_HAIR[hair_name] + (1.0,)
    beard = tuple(round(channel * 0.88, 4) for channel in hair[:3]) + (1.0,)

    dye_names = rng.sample(sorted(CROWD_DYES), 4)
    linen_name = rng.choice(sorted(CROWD_LINEN))
    boot_name, belt_name = rng.sample(sorted(CROWD_LEATHER), 2)
    palette = {
        "skin": skin,
        "hair": hair,
        "beard": beard,
        "tunic": _faded(rng, CROWD_DYES[dye_names[0]]),
        "outerwear": _faded(rng, CROWD_DYES[dye_names[1]]),
        "pants": _faded(rng, CROWD_DYES[dye_names[2]], 0.02),
        "sleeve_band": _faded(rng, CROWD_DYES[dye_names[3]]),
        "trim": _faded(rng, CROWD_DYES[dye_names[3]], 0.06),
        "sleeves": _faded(rng, CROWD_LINEN[linen_name], 0.03),
        "boots": _faded(rng, CROWD_LEATHER[boot_name], 0.02),
        "belt": _faded(rng, CROWD_LEATHER[belt_name], 0.02),
    }
    material_response = {
        family: _jitter(rng, *bounds)
        for family, bounds in sorted(CROWD_MATERIAL_RESPONSE_RANGE.items())
    }
    # Drawn last so adding it did not shift any body parameter above. Every
    # generated body ships all 76 clips, so gait variety is data-only.
    gait = rng.choice(CROWD_GAITS)

    name = crowd_variant_name(template, seed)
    return {
        "proportions": {**base["proportions"], **varied_proportions},
        "shape": shape,
        "face": face,
        "features": features,
        "palette": palette,
        "material_response": material_response,
        "output": f"{CROWD_OUTPUT_DIR}/{name}.glb",
        # Full generated bodies are Tier-1 quality; Tier-2 battle crowds use
        # the separate MultiMesh path (P0-154) and can bake these later.
        "fidelity_tier": 1,
        "garments": [],
        "crowd": {
            "template": template,
            "seed": seed,
            "stature_factor": stature,
            "build_factor": build,
            "gait": gait,
            "skin_tone": round(tone, 4),
            "hair": hair_name,
            "dyes": {
                "tunic": dye_names[0],
                "outerwear": dye_names[1],
                "pants": dye_names[2],
                "accent": dye_names[3],
                "sleeves": linen_name,
                "boots": boot_name,
                "belt": belt_name,
            },
        },
    }


def crowd_manifest() -> dict:
    """Resolved roster parameters; the committed JSON must equal this."""
    bodies = []
    for template, seed in CROWD_ROSTER:
        entry = crowd_variant_entry(template, seed)
        bodies.append(
            {
                "name": crowd_variant_name(template, seed),
                "output": entry["output"],
                **entry["crowd"],
                "proportions": entry["proportions"],
                "shape": entry["shape"],
                "face": entry["face"],
                "features": entry["features"],
                "palette": {key: list(value) for key, value in sorted(entry["palette"].items())},
                "material_response": entry["material_response"],
            }
        )
    return {"generator": "tools/character_specs.py crowd_variant_entry", "bodies": bodies}


CHARACTERS.update(
    {
        crowd_variant_name(template, seed): crowd_variant_entry(template, seed)
        for template, seed in CROWD_ROSTER
    }
)


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
        "material_response": entry.get("material_response", {}),
        "skeleton_intermediate": f"tools/character_build/{name}_skeleton.glb",
    }


def _main(argv: list[str]) -> int:
    import json
    from pathlib import Path

    manifest_text = json.dumps(crowd_manifest(), indent=2) + "\n"
    path = Path(__file__).resolve().parents[1] / CROWD_MANIFEST
    if argv == ["--write-crowd-manifest"]:
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(manifest_text)
        print(f"Wrote {CROWD_MANIFEST}")
        return 0
    if argv == ["--check-crowd-manifest"]:
        if not path.is_file() or path.read_text(encoding="utf-8") != manifest_text:
            print(f"{CROWD_MANIFEST} is stale; run --write-crowd-manifest")
            return 1
        print(f"{CROWD_MANIFEST} matches the seeded generator")
        return 0
    print("usage: character_specs.py --write-crowd-manifest | --check-crowd-manifest")
    return 2


if __name__ == "__main__":
    import sys

    raise SystemExit(_main(sys.argv[1:]))
