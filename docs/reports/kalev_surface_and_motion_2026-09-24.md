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

Matched before/after plates rendered offline in Blender 5.2 from the two exported
GLBs, so both halves of every plate use one camera, one light rig and one shading
setup. The "before" half is the pre-change body, blob SHA-256
`c5de85fb2dc6cd35ed354f1715be25a0094852641c7015dafa9464ac7fd9a376`, read from
commit `c0bcf3b7`. Surface plates use EEVEE with the atlas bound; motion plates
use Workbench single-colour shading so pose reads without texture distraction.

| Plate | Engine | File |
|-------|--------|------|
| Three-quarter turnaround | Blender EEVEE | `images/kalev_surface_motion/three_quarter_before_after.png` |
| Side profile | Blender EEVEE | `images/kalev_surface_motion/side_profile_before_after.png` |
| Head portrait | Blender EEVEE | `images/kalev_surface_motion/head_three_quarter_before_after.png` |
| Walk cycle | Blender Workbench | `images/kalev_surface_motion/walk_cycle_before_after.png` |
| Run cycle | Blender Workbench | `images/kalev_surface_motion/run_cycle_before_after.png` |
| Walk ground contact | Blender EEVEE over a floor plane | `images/kalev_surface_motion/walk_ground_contact.png` |

These are offline asset plates, not engine captures. For in-engine review of the
same assets run the existing preview capture:

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
- **Ankle roll on the hip phase.** Ankle and toe rotation followed a quarter-cycle
  cosine, so the foot was neutral at both heel strike and toe-off and pointed
  through mid-stance; the character walked on its toes. Driving both from the same
  sine as the hip makes the toe point at toe-off and lift for heel strike.
- **Authored idle.** Shoulder drop, lower-arm hinge, chest breath, hip sway and
  slow head drift now run on separate loop harmonics instead of a 0.4-degree
  shoulder-only variation.

## Verification

- `python3 tools/assets/kalev_rebuild/verify_asset.py` - 51,998 body triangles,
  eight body regions, 76 clips, six fitted garments; body SHA-256
  `a9e241582371c150e0ac5ab1b94cd9ed87e6ef1e953312dd08bb09948b6b6383`.
- `python3 tools/validate_asset_sources.py` - schema ok; atlas rows registered.
- Focused Godot suite
  `--filter=test_kalev_rebuild,test_kalev_live_integration,test_character_rig,test_character_wardrobe`:
  4 files, 52 tests, 0 failures.
- Sole clearance, measured on the evaluated foot meshes over 13 samples per cycle
  (lowest vertex height in metres, rest pose sole is Z=0):

  | Clip | Before | After |
  |------|--------|-------|
  | `Walking_A` | floats up to +0.078 mid-stride | +0.0058 to +0.0115, spread 0.0057 |
  | `Running_B` | ungrounded | +0.0090 to +0.0446, rise is the flight phase |
  | `Idle` | - | -0.0079 to +0.0082 |

  The first grounding attempt solved the pelvis drop in closed form and sank the
  feet 27-49 mm instead; probing the posed sole is what made the walk sit flat.
  Live integration confirms fresh walk and run still emit exactly one foot contact
  per half-cycle.
- `git diff --check` - clean aside from the existing CRLF normalization warning on
  `assets/SOURCES.csv`.

## Skinning left alone

A blanket `vertex_group_smooth` pass over the heat bind was tried and reverted.
The skeleton has no clavicle, so smoothing spread chest weight onto `upperarm`
and `chest`, and because `bind()` keeps only the four largest influences the
shoulder tore open along a hard crease. Rendering the unchanged CC0 clips
`Block`, `2H_Melee_Idle` and `1H_Melee_Attack_Chop` from both builds put the mean
luminance delta at 0.55-0.65 against the smoothed build and 0.16-0.21 against the
original bind, which is how the revert was confirmed rather than argued. Shoulder
and deltoid deformation is therefore unchanged by this pass and remains an open
rig limitation.

## Review boundary

This pass closes the projection seam and mannequin locomotion defects called out
for P0-220. Shoulder/neckline tailoring, hem joins, rigid hand grips and final
Witcher 3-level finish remain documented follow-ups from P0-214/P0-215.

Two artefacts survive and are visible in the side profile plate. Neither is a
regression; both are visible in the "before" half as well.

- The fill is a linear blur in world space, so along the exact silhouette where
  linen braies meet bare thigh it averages the two and leaves a faint warm streak
  on the cloth. A colour-aware (bilateral) weight would separate them.
- The clavicle and trapezius read as a soft lump in profile. That is sculpt
  geometry from the original reconstruction, not texture, and no atlas change
  can move it.

No reference plate holds honest colour for a surface turned away from both
cameras, so the grazing band is always invented. The remaining choice is how it
is invented, not whether.
