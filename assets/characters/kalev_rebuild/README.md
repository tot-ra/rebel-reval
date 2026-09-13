# Fresh Kalev reconstruction

An independent character study for the maintainer's request: realistic historical RPG presentation, with interchangeable clothes, armour and weapons. The starting point is an original adult-smith design generated on 12–13 September 2026. No previous Kalev model, character screenshot, anatomy generator, material palette or garment geometry is an input.

Open `preview.tscn` in Godot 4.7.1 and run the current scene. Keys 1–4 choose body/forge/travel/mail; W changes weapon; M changes motion. Drag to orbit, right-drag to pan, scroll to zoom. Gamepad A changes outfit, Y changes weapon, shoulders change motion, and left stick orbits. This is an isolated review scene; existing gameplay scenes continue using their current character.

The body is authored at 1.82 metres. The wrapper uniformly scales it to the existing two-world-unit character height contract. Stable narrative identity remains `char.kalev`. The new fit identifier is `kalev_fresh`, so outfits fitted to other bodies cannot be equipped accidentally.

`kalev_fresh.glb` contains independently named body regions and 76 motion clips (73 shared CC0 clips plus new idle, walk and run cycles). Six garment GLBs carry the same rest skeleton. They are mounted on the live skeleton through `CharacterWearable` and `CharacterWardrobe`; hiding covered body regions prevents clothing/body intersections. Hammer and sword use the existing `handslot.r` socket. These are presentation assets, with no inventory, save or combat-rule changes.

`source/kalev_fresh.blend` is editable and stores relative texture paths. `reference/sculpt.glb` is the compact normalized reconstruction before skinning and clothing. Both source directories are excluded from Godot import. The original front, rear and portrait images are preserved in `reference/`.

## Rebuild

From the repository root, with Blender 5.2 on PATH:

```sh
blender -b --python tools/assets/kalev_rebuild/inspect_motion_rig.py
blender -b --python tools/assets/kalev_rebuild/bake_materials.py
blender -b --python tools/assets/kalev_rebuild/build_character.py
blender -b --python tools/assets/kalev_rebuild/build_weapons.py
python3 tools/assets/kalev_rebuild/write_resources.py
godot --headless --path . --editor --import
python3 tools/assets/kalev_rebuild/verify_asset.py
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_kalev_rebuild
godot --path . --script tools/capture_kalev_rebuild.gd --resolution 1280x1280
```

The geometry-stripped CC0 motion source is extracted before Blender imports it. It supplies skeleton names and animations only. To regenerate the AI sculpt instead of rebuilding the preserved one, use `generate_base.py` with a local ComfyUI server that has `hunyuan3d-dit-v2-mv_fp16.safetensors`, then prepare oriented points and repair its surface before binding:

```sh
blender -b --python tools/assets/kalev_rebuild/build_character.py -- --source <generated.glb> --prepare-only --points-output build/kalev_rebuild/surface_points.ply
# Offline repair dependency: Python 3.10 with Open3D 0.19.0.
python tools/assets/kalev_rebuild/repair_surface.py build/kalev_rebuild/surface_points.ply build/kalev_rebuild/repaired_surface.ply
blender -b --python tools/assets/kalev_rebuild/import_surface.py -- build/kalev_rebuild/repaired_surface.ply
blender -b --python tools/assets/kalev_rebuild/build_character.py
```

These regeneration steps replace the preserved sculpt. The generation graph and seed are defined in that script; its output is not bitwise reproducible across GPU/model/runtime versions.

The generated surface is not a hand-retopologized digital double. Facial animation, individual finger articulation and garment cloth simulation are later production work. The review captures are the evidence for the current geometry and material quality; the concept images alone are not evidence of the game model.

Visual acceptance remains open: side projection seams, shoulder tailoring, hem joins and hand grips still need work before this meets the requested Witcher 3 level. See the report and actual engine captures.
