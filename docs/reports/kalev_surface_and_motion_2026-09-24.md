# Kalev surface and motion defects (2026-09-24)

Maintainer request: remove the torn front/back skin projection seam, ghost facial
features and smeared side band from the live Kalev body, and replace the
mannequin-stiff authored idle, walk and run with grounded cycles that swing the
arms and hinge the elbows.

Scope is the fresh Kalev rebuild assets and Blender build script only. Stable
`char.kalev` identity, the 41-bone skeleton, 76 clip names, eight body regions,
the `handslot.r` socket, wardrobe fit id `kalev_fresh`, gameplay, maps,
inventory, combat and save schema were not changed.

## Evidence

Matched before/after comparison plates from the isolated rebuild preview scene,
GL Compatibility renderer, 1280 px square:

| Plate | File |
|-------|------|
| Three-quarter turnaround | `images/kalev_surface_motion/three_quarter_before_after.png` |
| Side profile | `images/kalev_surface_motion/side_profile_before_after.png` |
| Head portrait | `images/kalev_surface_motion/head_three_quarter_before_after.png` |

Regenerate stills with:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  --rendering-method gl_compatibility --rendering-driver opengl3 \
  --script tools/capture_kalev_rebuild.gd
```

## What changed and why

### Skin surface

- **Seamless atlas bake.** The previous per-face front/back material switch left a
  torn silhouette seam and smeared reference plates across every side-facing
  surface. `bake_skin_atlas()` now smart-projects the body once, rasterizes each
  atlas texel in surface space, blends the original front/back/face plates by a
  cubed facing term, diffuses low-confidence grazing texels, and writes
  `materials/skin_atlas.jpg` plus the exported GLB copy
  `kalev_fresh_skin_atlas.jpg`.
- **Retired projection plates.** The six runtime `skin_projection_*.jpg/.png`
  sidecars were removed; provenance now points at the atlas rows in
  `assets/SOURCES.csv`.

### Locomotion

- **World-space elbow hinges.** Walk and run rotations are conjugated through each
  shoulder's rest drop so lower-arm keys close the elbow instead of twisting along
  the forearm axis.
- **Grounded pelvis.** `sole_probes()` tracks heel, ball and toe contact points;
  `ground_offset()` translates the pelvis each keyframe so the lowest sole probe
  stays on the floor through idle breath, walk load exchange and run flight.
- **Authored idle.** Shoulder drop, lower-arm hinge, chest breath, hip sway and
  slow head drift now run on separate loop harmonics instead of a 0.4-degree
  shoulder-only variation.

## Verification

- `python3 tools/assets/kalev_rebuild/verify_asset.py` - 51,998 body triangles,
  eight body regions, 76 clips, six fitted garments; body SHA-256
  `a0d7442b5c9097c0e8ec1c71e8460282711db157a4d3e436f7e4ff0d24932ff7`.
- `python3 tools/validate_asset_sources.py` - schema ok; atlas rows registered.
- Focused Godot suite
  `--filter=test_kalev_rebuild,test_kalev_live_integration,test_character_rig,test_character_wardrobe`:
  4 files, 52 tests, 0 failures.
- Sole clearance: authored idle/walk/run keyframes call `ground_offset()` so the
  lowest heel/ball/toe probe reaches Z=0 each frame; live integration confirms
  fresh walk and run emit exactly one foot contact per half-cycle.
- `git diff --check` - clean aside from the existing CRLF normalization warning on
  `assets/SOURCES.csv`.

## Review boundary

This pass closes the projection seam and mannequin locomotion defects called out
for P0-220. Shoulder/neckline tailoring, hem joins, rigid hand grips and final
Witcher 3-level finish remain documented follow-ups from P0-214/P0-215.
