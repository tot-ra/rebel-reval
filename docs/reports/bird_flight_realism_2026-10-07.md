# Bird wingbeats, flapping flocks and aerofoil wings - R-1188

Maintainer request: birds flew in a V but like aircraft, without beating their wings, and the models should read closer to The Witcher 3, KCD2 and RDR2 wildlife.

Feature documentation: [Bird flight](../FLORA_FAUNA.md#bird-flight).

## Root causes

- **Frozen followers.** Flock followers (P0-159) were MultiMesh copies of one Glide pose. Only the rigged leader moved its wings.
- **Weak leader stroke.** The leader used a symmetric 8-key see-saw of about ±25 degrees at ~1 beat/s, with no wrist fold, and glided between bursts for every family, ducks and geese included.
- **Comb wings.** Every species had the same rectangular wing made of separated cards. The trailing edge read as a saw blade, and the sky showed through between feathers.
- **Inverted feather lighting.** Feather quads were wound against their own normal. Bird materials are double-sided and Godot flips the normal of back faces, so every wing and tail was lit as if seen from below: darker and flatter than the body.

## Change

- Wingbeat kinematics: 56% downstroke with the wing spread, upstroke with the hand folded back at the wrist, body heave, per-family frequency and habit (continuous, flap-glide, bounding with closed wings). Per-species overrides cover swan, goose, mallard, heron, cormorant, snipe, eagle, kestrel, jackdaw and magpie.
- Followers flap through an 8-pose flipbook plus a rest pose. Each follower beats on its own clock, and the formation widens with wingspan.
- Anatomy revision 214: cambered double-sided wing plate, shingled coverts, rounded overlapping secondaries, pointed, slotted or rounded hand per family, paler underwings, white swan wings, mallard speculum, black gull wingtips. Feathers ride just above the plate's camber so they are not swallowed by it.
- Feather winding fixed for every bird pose, perched and standing included.

## Evidence

Captured with Godot 4.7.1 (Metal, Apple M5 Pro), in an isolated copy of the project (HEAD scripts plus this change), because concurrent uncommitted edits in `map_view_st_olaf_model.gd` and `map_view_prop_materials.gd` broke compilation of the shared working tree.

- Before: [flight catalogue page 0](images/bird_flight_realism_2026-10-07/before_flight_0.png)
- After: [page 0](images/bird_flight_realism_2026-10-07/after_flight_0.png), [page 2](images/bird_flight_realism_2026-10-07/after_flight_2.png), [herring gull top, 3/4 and underside](images/bird_flight_realism_2026-10-07/gull_closeup.png)
- [Wingbeat cycle](images/bird_flight_realism_2026-10-07/wingbeat_cycle.png): greylag goose, common tern, rook, chaffinch. Eight phases from the top of the stroke, then the rest pose (the chaffinch folds its wings).
- [Live flocks](images/bird_flight_realism_2026-10-07/flock_frames.png): three frames 45 ms apart from `MapViewBirdFlight` itself. Top row is a greylag goose skein, bottom row a cormorant flock. Every follower is at a different point of its stroke.

## Verification

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view_bird_flight,test_map_view_bird_meshes,test_map_view_bird_species,test_map_view_bird_ambient_audio,test_bird_catalog_realism,test_storybook_live_integration,test_storybook_models,test_map_view_3d_runtime,test_performance_benchmark,test_bird_audio_clips,test_medieval_animal_models,test_map_view_penned_fauna
```

Result: 12 files, 108 tests, 0 failures. New tests cover the stroke shape, the flight-style profiles, leader wing motion, followers cycling through poses, and the one-pose-per-frame skinned warm-up. Maximum catalogue triangles: 7,068 (cap 8,000).

Flipbook bake cost measured on the M5 Pro: catalogue species about 15 ms for all 9 poses, built on first flock. Skinned storybook species about 130 ms in total, now spread at one pose per frame (worst frame 23 ms) and cached per GLB for the session.

## Limits

Wings are rigid arm and hand sections on a two-joint rig, and feathers are cards rather than a groomed coat. Bodies and heads are unchanged from P0-216. This is closer to, but not at, AAA wildlife fidelity: that needs sculpted, textured and skinned bird assets.
