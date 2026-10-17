# Human motion library

Status: implemented (task **R-2211**). Scope: how the 76 clips reach realistic human rigs (ADR 0022). Out of scope: clip authoring, procedural motion (ADR 0040/0051), which still run on top of the mounted player.

## What changed

Every realistic body GLB used to embed the same 76 clips (about 4.6 MB each, 53 files, 267 MB). Bodies now ship **without animations**. Clips live once per body *shape*:

- `assets/characters/realistic/shared/motion/<shape>.glb` - armature, a one-triangle skinned anchor mesh (Godot only builds a `Skeleton3D` for a used skin) and the clips. Tracks equal to their bone's rest transform are dropped (Godot's `remove_immutable_tracks` did this at import anyway).
- `assets/characters/realistic/shared/motion/shapes.json` - `{"bodies": {body: shape}}`.

Why per shape and not one library: measured on the 49 bodies, scale tracks are constant, but rotation tracks differ by up to 5 deg (fingers, upper legs) and position tracks by up to 0.46 m on IK controls and 4-10 cm on hips and limbs. Hips travel is fitted to each rest pose, so stature scaling does not reproduce it (a child's hips would sit 10 cm off). Bodies whose tracks agree within 0.5 deg and 3 mm (outfit variants `_b/_c/_d`, citizen builds of one sex and age) share a shape: 49 bodies -> 29 shapes.

## Runtime

`SharedCharacterRig._ready` finds no `AnimationPlayer` in a realistic body and calls `scripts/characters/human_motion_library.gd` `attach(model, skeleton)`. That loads the body's shape once (cached), adds an `AnimationPlayer` under the body scene root and mounts the library as `""`. Rigs of one shape share the `Animation` resources. If the body's rig node is named differently from the shape's (`HumanMotionRig_001`), track paths are retargeted on a cached copy. Clip names and the 76-clip contract are unchanged; combat-roll, motion style, idle foot lock and swim modifiers act on the same player.

## Rebuild

`build_human.py` exports each body without clips plus a full export to `build/realistic_humans/motion_sources/<body>.glb` (`.gdignore`d). `tools/assets/realistic_humans/shared_motion.py [body ...]` clusters the sources, writes shapes and the manifest, strips any body GLB that still carries clips, and `rebuild.sh` runs it before the Godot import. A partial rebuild only reassigns the named bodies.

## Verify

`tests/godot/test_human_motion_library.gd` (no embedded players, every body has a shape, 76 clips, every track resolves to a bone, variants share resources, hips follow each body). Capture: `tools/godot_render.sh --script tools/capture_motion_library.gd -- --out=res://build/motion_library/after`.

## Measurements (2026-10-17)

| | before | after |
|---|---|---|
| realistic body GLBs (49 bodies) | 267 MB | 52 MB |
| shared motion shapes (29) | - | 42 MB |
| total | 267 MB | about 94 MB |
| key-bone poses, 10 bodies x 4 clips | - | max 1.9 mm, mean 0.19 mm from before |
| spawn of 10 rigs (cold) | 1162 ms | 1234 ms (noise level) |
| static memory for those 10 rigs | +44.3 MB | +46.0 MB |

## Limits

Per-shape sets still cost about 1.5 MB each; a shared rotation set plus per-shape positions would save about 30 MB more at up to 5 deg finger error. Memory per live shape is unchanged from before.
