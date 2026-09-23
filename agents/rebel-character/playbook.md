# Character playbook

Read `agents/playbook.md` first for shared workflow, tooling, and Git lessons.
This file contains lessons specific to the Character role.

## Role-specific lessons
- An NPC "standing on the smithy anvil" is usually an authored anvil-bound activity (`ap.visitor.inspect` / `ap.forge.anvil`), not a stray spawn. In prologue prefer Henning inspect over Mart while `flag.mart_missing`.
- After `AnimationPlayer.seek()` in a no-frame pose audit, measure equipment from the skeleton bone global pose. `BoneAttachment3D.global_transform` may remain stale until a process frame updates it.
- During equipment hot-swap tests, do not assert a PackedScene root name. A queued sibling with the same name can make Godot auto-rename the replacement. Assert scene-specific child geometry instead.
- Do not copy hammer attachment orientation onto a long blade without pose-space clearance checks. The same `handslot.r` transform can point a sword through the torso.
- Full-character pose probes can hang when several imported rigs are instantiated and freed in one `SceneTree`. Run one actor or pose per process.
- Forge-cat sleep or stretch burial is usually uncompensated spine or chest pitch on foreleg parents. Plant feet from the live hip world position and lift the root until skinned mesh min Z clears the floor. Assert every clip in `audit_pose_ground`.
- Locomotion arm defects on the KayKit chibi retarget are neutral-pose problems. Rebuild the swing as `rotate(lateral_axis, neutral + amplitude * phase)` and take only the mean-centred phase from the clip. Flip the left arm's phase or both arms swing with the same-side leg.
- Before blaming mesh radii for wide legs or big shoulders, measure hip and arm sockets against the pelvis and neck base.
- Bone-level proportion changes shift `BODY_STATURE`. Update `SharedCharacterRig.HEROIC_MODEL_SCALE` to `2.0 / BODY_STATURE` and regenerate character LODs.
- `SharedCharacterRig.sync_action_presentation` must resolve the Animation via `source_animation_name` and null-check it. After a one-shot ends, `current_animation` can be empty while the canonical attack name is still active.
- Default session equipment can support charged attacks, which swing on button release. Drive the full press/release pair in click-path tests.
- When correcting a Blender-imported animal axis, validate the authored head direction against the runtime rig before changing dimensions.
