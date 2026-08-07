# Character playbook

Read `agents/playbook.md` first for shared workflow, tooling, and Git lessons.
This file contains lessons specific to the Character role.

## Role-specific lessons
- An NPC "standing on the smithy anvil" is usually an authored anvil-bound activity (`ap.visitor.inspect` / `ap.forge.anvil`) whose `approach_position` sits inside `forge_anvil` footprint, not a stray spawn; in prologue prefer Henning inspect over Mart (Mart stays hidden while `flag.mart_missing`).
- After `AnimationPlayer.seek()` in a no-frame pose audit, measure equipment from the skeleton bone global pose; `BoneAttachment3D.global_transform` may remain stale until a process frame updates it.
- During equipment hot-swap tests, do not assert a PackedScene root name: a queued sibling with the same name can make Godot auto-rename the replacement. Assert scene-specific child geometry instead.
- Do not copy hammer attachment orientation onto a long blade without pose-space clearance checks; the same `handslot.r` transform can point a sword through the torso. Compare grip/tip distance from chest in idle and attack, then render both plates.
- Full-character Godot pose probes can hang when several imported rigs are instantiated and freed in one `SceneTree`; run one actor/pose per process and use the checked runner so teardown failures stay isolated.
- Forge-cat sleep/stretch burial is usually uncompensated spine/chest pitch on foreleg parents, not a bad bind pose; plant feet from the live hip world position and lift the root until skinned mesh min Z clears the floor, then assert every clip in `audit_pose_ground` (walk-only gait audit will stay green while the loaf disappears).
- When continuing a failed parent session that died mid-`production_build.py` read, re-measure the exported GLB mesh AABB per clip before rewriting IK - pose sheets and tip bones can disagree after glTF Yup round-trip.
- Locomotion arm defects on the KayKit chibi retarget are neutral-pose problems, not amplitude problems: per-axis attenuation of the source delta only shrinks the cycle around a wrong pose. Rebuild the swing as `rotate(lateral_axis, neutral + amplitude * phase)` and take only the mean-centred phase from the clip.
- Derive a rebuilt swing axis from the skeleton (body axis mapped through the bone's parent rest rotation). Mirrored arm bones make a shared local axis send one elbow outward and desynchronise the arms.
- When posing a forearm inside an upper arm the same pass re-aims, undo the shoulder's adduction in the forearm's axis; otherwise the elbow bend leaks into forearm twist and running arms come out straighter than walking ones.
- Normalising a source rotation signal without removing its mean can freeze the motion: the chibi arm tracks carry a large mirrored DC offset, which yielded a near-constant phase (one arm parked forward, one back).
- Mirrored source bones report the same physical swing with opposite sign; flip the left arm's phase or both arms swing together and each moves *with* the leg on its own side. Verify against knee traces, not by eye.
- Before blaming mesh radii for "legs too wide", measure the hip sockets: the chibi stance put them 0.325 m apart on a 1.63 m body, wider than the pelvis, so the thighs emerged outside the hips. Same for "shoulders too big" - the arm sockets sat 1.4 cm below the neck base.
- Iterate character pose work on the skeleton intermediate (`build_heroic_humanoid_glb.py`, seconds) plus a numeric Blender audit; only run the full Blender body rebuild once the numbers land.
- Bone-level proportion changes shift the generator's `BODY_STATURE`; update `SharedCharacterRig.HEROIC_MODEL_SCALE` to `2.0 / BODY_STATURE` in the same change, and regenerate character LODs or they keep the old silhouette.
- `SharedCharacterRig.sync_action_presentation` must resolve the Animation via `source_animation_name` and null-check it; after a one-shot ends `AnimationPlayer.current_animation` can be empty while the canonical attack name is still active, and `.length` on null crashes the map view loop.
- Default session equipment can support charged attacks, which swing on button *release*. A click-path test that only sends the press sees `State.MOVE` and looks like a broken attack; drive the full press/release pair instead.
- When correcting a Blender-imported animal axis, validate the authored head direction against the runtime rig before changing dimensions; a sign error can place eyes/neck on the tail while all size and animation checks still pass.
