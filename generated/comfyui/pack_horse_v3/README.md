# Medieval pack horse v3

This bundle replaces the unusable runtime horse that fused a Hunyuan ground disc into the body.

## Decision

- Recreated at the user's request on 2026-07-28 because the previous runtime GLB remeshed a grounded candidate and produced a flat wall.
- Floating mid-gray reference: `pack_horse_reference_floating.png` derived from the Leonardo v2 still with contact-plane shards removed.
- Local Hunyuan3D prompt: `5a481d5e-0306-4e55-8860-67b307668631`, seed `208744336`.
- Candidate: `pack_horse_candidate.glb`.
- Runtime target: `assets/animals/medieval/medieval_pack_horse.glb`.

## Production

Run from the repository root:

```bash
blender -b --factory-startup --python generated/comfyui/pack_horse_v3/production/build_pack_horse_v3.py
```

The production pass:

1. trims residual horizontal contact shards only;
2. preserves candidate topology with collapse decimate (no voxel remesh);
3. normalizes to 2.35 x 1.65 x 0.78 m (length x height x width);
4. unwraps UVs and embeds 512 px dark-bay albedo/normal/roughness;
5. applies the shared pack-horse quadruped rig with idle/walk clips.

Do not rebuild the pack horse through `tools/assets/build_medieval_animal_models.py -- pack_horse` alone. That shared remesh path collapses this open AI surface.

## Verification

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  tools/run_godot_checked.sh --require-test-summary pack-horse \
  "$GODOT_BIN" --headless --path . --script res://tools/run_godot_tests.gd -- --filter=test_medieval_animal_models
python3 tools/verify_asset_lint.py
```
