"""Write live character scenes for realistic humans (ADR 0022).

    python3 tools/assets/realistic_humans/write_scenes.py [name ...]

Each named cast member's `assets/characters/variants/<name>.tscn` keeps its
identity resource (`<name>_variant.tres`) and health ring, and swaps its body
for the realistic GLB, dressed in the spec's first outfit. Every realistic
body shares one uniform model scale (2.0 world units per Kalev's 1.80 m), so
relative statures stay true. Kalev's scene is maintained by hand.
"""
from pathlib import Path
import json
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
import specs  # noqa: E402

MODEL_SCALE = 2.0 / specs.SPECS["kalev"]["height_m"]
HEALTH_RING = {"aita", "ellen", "jurgen", "kaja", "henning", "mart", "watchman"}


def scene(name):
    spec = specs.SPECS[name]
    outfits = json.loads((ROOT / f"assets/characters/realistic/{name}/outfits.json").read_text())
    outfit = next(iter(outfits.values()))
    res = f"res://assets/characters/realistic/{name}"
    lines = [f"[gd_scene load_steps={5 + len(outfit)} format=3]", "",
             '[ext_resource type="Script" path="res://assets/characters/realistic/realistic_rig.gd" id="1_rig"]',
             f'[ext_resource type="PackedScene" path="{res}/{name}.glb" id="2_model"]',
             f'[ext_resource type="Resource" path="res://assets/characters/variants/{name}_variant.tres" id="3_variant"]',
             '[ext_resource type="Script" path="res://scripts/ui/character_health_ring_3d.gd" id="4_health_ring"]']
    ids = []
    for i, garment in enumerate(outfit):
        ids.append(f"{5 + i}_{garment}")
        lines.append(f'[ext_resource type="Resource" path="{res}/{garment}.tres" id="{ids[-1]}"]')
    node = "".join(part.capitalize() for part in name.split("_"))
    outfit_array = ", ".join(f'ExtResource("{i}")' for i in ids)
    lines += ["", f'[node name="{node}" type="Node3D"]', 'script = ExtResource("1_rig")',
              'variant = ExtResource("3_variant")',
              f"model_scale = Vector3({MODEL_SCALE:.7f}, {MODEL_SCALE:.7f}, {MODEL_SCALE:.7f})",
              "use_anatomical_muscles = false",
              f"default_outfit = Array[Resource]([{outfit_array}])", "",
              '[node name="Model" type="Node3D" parent="."]', "",
              f'[node name="{node}Body" parent="Model" instance=ExtResource("2_model")]']
    if name in HEALTH_RING:
        lines += ["", '[node name="HealthRing" type="Node3D" parent="."]', 'script = ExtResource("4_health_ring")']
    return "\n".join(lines) + "\n"


def main(names):
    for name in names or [n for n in specs.SPECS if n != "kalev"]:
        path = ROOT / f"assets/characters/variants/{name}.tscn"
        path.write_text(scene(name))
        print("wrote", path.relative_to(ROOT))


if __name__ == "__main__":
    main(sys.argv[1:])
