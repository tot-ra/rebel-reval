# Forge cat - game-ready production pass (integrated, rig v2)

> **rig v2 rework.** The first pass shipped a skeleton that was rotated 90 deg
> relative to the body, so the cat appeared to walk sideways. Root cause: the
> orientation step assigned `obj.rotation_euler` on a freshly imported glTF
> object, which the importer leaves in `QUATERNION` rotation mode - the
> assignment was silently ignored and the body stayed along X while the rig was
> authored along Y. The rework fixes the orientation, measures bone placement
> from the mesh, re-authors the walk as a lateral-sequence feline gait with a
> ground-contact audit, adds a face mesh (eyes, slit pupils, nose leather,
> whiskers), bakes six coats plus a roughness map, and scales the body to 0.60 m.

Separate production pass over the visually approved Hunyuan3D base shape
(`../forge_cat_hunyuan3d_v1.glb`), following `../PRODUCTION_PLAN.md`. The
production GLB is integrated through `assets/characters/cat/cat_rig.tscn`; its
adapter preserves the existing `SharedCharacterRig` gameplay contract.

## Deliverables

- `forge_cat_production_v1.glb` - LOD0 mesh + `forge_cat` material + 22-bone
  quadruped armature + `idle`, `walk`, `sleep`, `lick`, and `stretch` animations
  (single-file GLB, textures embedded).
- `lod/forge_cat_lod1.glb`, `lod/forge_cat_lod2.glb` - decimated distance LODs
  (mesh + UV, shared-material placeholder, no embedded textures).
- `tex/forge_cat_albedo.png`, `tex/forge_cat_normal.png`,
  `tex/forge_cat_roughness.png`, `tex/forge_cat_ao.png` - 1024 texture set
  (AO also multiplied into the albedo).
- `tex/coats/forge_cat_albedo_*.png` - five town coats over the same UVs, swapped
  at runtime by `assets/characters/cat/cat_coat_variants.gd`.
- `previews/walk_cycle.png`, `previews/pose_sheet.png`, `previews/coat_sheet.png`
  - review sheets from `render_review.py`.
- `previews/prod_{front,side,back,threeq}.png` - Blender previews.
- `previews/godot_preview.png` - in-engine Godot preview under forge-like light.
- `reports/production_report.json`, `godot_verify/godot_verify.json` - metrics.
- `production_build.py`, `render_textured.py`, `render_clay.py`,
  `godot_verify/` - reproducible build + verification.

## Results vs plan

| Item | Target | Result |
|------|--------|--------|
| LOD0 triangles | 8k target / 12k cap | 8,360 (100% quads) |
| LOD1 triangles | 3-4k | 3,500 |
| LOD2 triangles | 800-1,200 | 1,000 |
| Non-manifold edges | remove 2,169 | 0 |
| Boundary edges | remove 6 | 0 |
| Connected components | 1 | 1 (no floating/duplicate/hidden geometry) |
| UV sets | 1 | 1 (`UVMap`, non-overlapping) |
| Texture set | 1024 | 1024 albedo/normal/roughness/AO + 5 coat albedos |
| Rig | quadruped | 22 bones placed from measured feet, back line, skull and tail curve |
| Weights | clean | automatic bone-heat, then 894 cross-limb weights stripped below the hips |
| Animations | ForgeCat runtime contract | `idle` 5.0s, `walk` 0.6s, `sleep` 3.0s, `lick` 1.6s, `stretch` 2.0s; all 30fps |
| Scale / origin | metric, feet on ground | 0.598 x 0.199 x 0.404 m (0.289 m withers), origin between paws, min Y = 0 |
| Face parts | readable at game distance | separate 820-triangle mesh: 2 eyes, 2 slit pupils, nose leather, 10 whiskers |
| Coats | town variation | `forge` (embedded) + tabby_brown, tabby_grey, black, ginger, white_black |

## Godot in-engine verification (`godot_verify/`)

Loaded via `GLTFDocument` (tests the raw GLB, not a pre-baked import):

- Import error code: `0` (no errors).
- 2 meshes: the `forge_cat` fur body (1 surface) and the `ForgeCatFace` parts
  (eye/pupil/nose/whisker materials), both skinned to the same skeleton.
- Skeleton imported (22 bones); all five canonical runtime clips are present and play.
- AABB `[0.598, 0.404, 0.199]`, min Y = `0.0` -> ground contact OK.
- Metric scale OK (all axes < 1 m).

## Decisions

- **Retopology by voxel remesh, not QuadriFlow.** QuadriFlow cancels
  unreliably in headless Blender 5.2 on this multi-protrusion mesh even with a
  fully manifold, normals-consistent input. `voxel_remesh` is a standard clean
  quad retopology method for AI/scan geometry and yields a single manifold,
  all-quad, boundary-free surface over the approved silhouette.
- **Paws reworked procedurally**: the rounded cuff ends are compressed into low
  feet, the sole band is snapped to one flat ground plane (consistent ground
  contact for all four paws), and toe boxes are nudged forward. Fully
  anatomical paw sculpting is left as a flagged GUI refinement for the final
  approval gate (see limitations).
- **Textures**: AO baked from self-occlusion; a short-fur tangent normal is
  authored from procedural noise; albedo is charcoal-gray with restrained
  warm-brown forge highlights (top/back gradient) and AO multiplied in. One
  material, `metallic=0`, `roughness=0.82` scalar.
- **Walk cycle is solved, not posed.** Each foot follows a target trajectory
  through a two-link solver: linear constant-speed travel while planted, an
  eased swing with a sine lift, and a paw bone that counter-rotates the chain so
  the sole stays flat on the floor. Footfalls use the lateral sequence a cat
  actually walks in - left hind, left fore, right hind, right fore at 25% phase
  offsets, 0.66 duty factor - which keeps two or three feet down at all times.
  Stride 0.134 m per stance over a 0.6 s cycle = **0.337 m/s ground speed**, the
  figure `CatRig.WALK_REFERENCE_SPEED_WORLD` is set to.
- **Rest clips plant feet in world space, then settle the root.** Sleep/lick/stretch
  pitch the spine/chest that parents the forelegs. A root-only `body_up` term left
  the belly under the floor so the cat vanished from the dimetric camera.
  `_pose_leg_world` measures the live hip, and `_settle_planted_frame` lifts the
  root until skinned mesh penetration is under 4 mm. `audit_pose_ground` covers
  every canonical clip; `budget_ok.pose_ground_pass` fails the build on regress.
- **The gait is audited, not eyeballed.** `audit_gait` replays the clip and
  measures world-space paw tips: contact height error 0.000 m, floor penetration
  0.0004 m, worst stance slip 0.045 m/s, swing clearance 0.024 m, support count
  never below two. `budget_ok.gait_pass` fails the build if any of those regress.
- **Animations** use full-pose boundary keys so transitions do not inherit stale
  bones. Idle, walk, and sleep are looped by `CatRig`; lick and stretch are
  one-shot. Root translation is keyed along the bone's local Y (world up); the
  first pass used local Z, which shunted the sleeping cat backwards instead of
  lowering it onto its paws.
- **No spine pitch during the walk.** The spine sits above the forelegs in the
  hierarchy, so pitching it swings the planted forefeet; the body's vertical
  motion comes from the root, which the leg solver compensates for.
- **Face parts follow the livestock kit convention** (`tools/assets/medieval_animal_rigs.py`):
  small primitives with flat materials, placed by ray-casting outward from
  inside the skull against muzzle-tip and ear-line landmarks, joined into one
  mesh and bound rigidly to the `head` bone.
- **Runtime integration**: `cat_rig.tscn` instances this GLB and `cat_rig.gd`
  adapts its canonical animation names without changing forge collision or navigation.

## Known limitations / follow-ups (pending approval)

- **Edge flow is a uniform voxel-grid quad field**, not hand-placed anatomical
  deformation loops. Adequate for a small ambient forge cat; if closer
  deformation is needed, run an interactive QuadriFlow/manual retopo pass in the
  Blender GUI over this same silhouette.
- **Paw anatomy is approximate** (flat contact + toe hint, not sculpted pads/toes).
- **Orientation**: the cat faces `+Z` in Godot, the `SharedCharacterRig`
  convention, so `cat_rig.tscn` needs no correction yaw. Ambient actors turned
  by `look_at` (which faces `-Z`) get a 180 deg model yaw from
  `MapViewMedievalAnimalModels.MODEL_YAW`.
- **Coat stripes are procedural bands**, masked by the countershading gradient
  so they fade off the belly. They read as mackerel tabby at game distance but
  are not per-hair authored markings.
- **One ear tip carries a thin dark sliver** left by the voxel remesh; visible
  only in close-up renders, not from the game camera.
- **`sleep` reads as a loaf, not a curl.** The body is a standing silhouette, so
  it settles onto folded legs rather than curling round; a curled cat would need
  a second sculpt.
- **The skull has no brow or socket relief**, so the eyes sit in a smooth head.
  Sculpted sockets would need an interactive pass over the same silhouette.

## Reproduce

```
blender -b --python production_build.py                       # build GLB + LODs + textures + coats + report + gait audit
blender -b --python render_review.py                          # walk-cycle, pose and coat review sheets
blender -b --python render_textured.py -- forge_cat_production_v1.glb previews/prod
Godot --path godot_verify                                     # in-engine verify + preview
```
