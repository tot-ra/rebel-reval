# Forge cat - game-ready production pass (result)

Separate production pass over the visually approved Hunyuan3D base shape
(`../forge_cat_hunyuan3d_v1.glb`), following `../PRODUCTION_PLAN.md`. This is a
reviewable candidate only. The shipping cat rig (`assets/characters/cat/cat_rig.tscn`)
is **not** replaced, pending a separate final visual + in-engine approval.

## Deliverables

- `forge_cat_production_v1.glb` - LOD0 mesh + `forge_cat` material + 22-bone
  quadruped armature + `idle` animation (single-file GLB, textures embedded).
- `lod/forge_cat_lod1.glb`, `lod/forge_cat_lod2.glb` - decimated distance LODs
  (mesh + UV, shared-material placeholder, no embedded textures).
- `tex/forge_cat_albedo.png`, `tex/forge_cat_normal.png`, `tex/forge_cat_ao.png`
  - 1024 texture set (AO also multiplied into the albedo).
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
| Texture set | 1024 | 1024 albedo/normal/AO |
| Rig | quadruped | 22 bones: root, pelvis, spine, chest, neck, head, 4x(upper/lower/paw), 4x tail |
| Weights | clean | automatic bone-heat |
| Idle | 4-6s loop @30fps | 5.0s (150f), seamless (first=last), root fixed, paws locked |
| Scale / origin | metric, feet on ground | 0.52 x 0.17 x 0.37 m, origin between paws, min Y = 0 |

## Godot in-engine verification (`godot_verify/`)

Loaded via `GLTFDocument` (tests the raw GLB, not a pre-baked import):

- Import error code: `0` (no errors).
- 1 mesh, 1 surface, material `forge_cat` (StandardMaterial3D).
- Skeleton imported (22 bones); `idle` present (5.0s) and plays.
- AABB `[0.5176, 0.3664, 0.174]`, min Y = `0.0` -> ground contact OK.
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
- **Idle** is authored seamless (matched first/last keyframes). glTF does not
  carry a loop flag, so looping is enabled by the Godot import/AnimationPlayer
  at integration time.
- **Existing rig untouched**: this candidate is separate and additive.

## Known limitations / follow-ups (pending approval)

- **Edge flow is a uniform voxel-grid quad field**, not hand-placed anatomical
  deformation loops. Adequate for a small ambient forge cat; if closer
  deformation is needed, run an interactive QuadriFlow/manual retopo pass in the
  Blender GUI over this same silhouette.
- **Paw anatomy is approximate** (flat contact + toe hint, not sculpted pads/toes).
- **Orientation**: the cat's length runs along the model's X axis (Godot Y-up).
  Set the instance yaw to face the desired in-game direction.
- **No roughness map** (single scalar); add one if the forge look needs varied
  sheen.

## Reproduce

```
blender -b --python production_build.py                       # build GLB + LODs + textures + report
blender -b --python render_textured.py -- forge_cat_production_v1.glb previews/prod
Godot --path godot_verify                                     # in-engine verify + preview
```
