# P0-037 shared character rig production proof

Recorded: 2026-07-21
Task: `P0-037`
Host: macOS 26.3 arm64, Apple M5 Pro (18 cores), 48 GB RAM
Toolchain: Godot 4.7.1.stable.official.a13da4feb, Blender 5.2.0 LTS, Python 3.9.6, NumPy 2.0.2

## Verdict

**Pass.** The shared low-poly rig meets the P0-037 runtime and production-speed contracts:

- Kalev exposes idle, walk, forge strike, hammer attack, guard, hit, and fall through one retargeted skeleton and one canonical animation API.
- The same clips play at every facing by rotating the 3D rig; there are no per-direction meshes or clips.
- Mart is a data-only identity/equipment/garment swap on the same imported body and animation library.
- An end-to-end generated-body rebuild for the committed Innkeeper variant completed in **16.83 seconds**, including skeleton retarget, body generation, GLB export, and Godot reimport. This is well under the one-working-day variant budget.
- All **76** source clips pass through the same deterministic skeleton retarget during that rebuild. Exposing the already-retargeted `PickUp` clip as canonical `pickup`, adding its focused contract, and completing the strict test gate took **21 seconds**, well under the one-hour animation budget.

Final visual art approval remains owned by P0-040/P2-004 and is not part of this rig-production gate.

## Runtime evidence

Command:

```bash
tools/run_godot_checked.sh --require-test-summary p0_037 -- \
  /Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_character_rig
```

Expected result: `16 test(s), 0 failure(s), 0 error(s)` and no unallowlisted engine diagnostics.

The focused suite proves:

1. every required canonical animation exists and starts on Kalev;
2. the same walk clip serves four facings through rig transforms;
3. the visible-height scale contract remains 2.0 world units / 64 gameplay pixels;
4. Mart preserves Kalev's skeleton and shared animation library while swapping identity, equipment, tint, and garment data;
5. generated Innkeeper, Henning, and Townswoman bodies preserve the shared skeleton/canonical contract;
6. variant gait overrides select alternate clips without adding runtime branching;
7. equipment slots and skinned garments stay attached to the common skeleton.

Visual evidence: [`images/p0_037_character_rig.png`](images/p0_037_character_rig.png) shows Kalev at the frozen gameplay scale in idle, walk, run, forge strike, hammer attack, guard, hit, and fall poses, plus Mart on the same rig.

## Measured variant rebuild

The measurement ran in a detached temporary Git worktree so generated binaries and Godot imports could not alter the active working tree.

Procedure:

```bash
tmp_worktree="$(mktemp -d /tmp/rebel-reval-p0037.XXXXXX)"
git worktree add --detach "$tmp_worktree" HEAD
cd "$tmp_worktree"
/usr/bin/time -p tools/rebuild_hero_character.sh innkeeper
# Then run the focused runtime command from the previous section.
```

Raw result:

```text
Retargeted body height: 1.7081 units (ymin=-0.0052)
Wrote tools/character_build/innkeeper_skeleton.glb
BODY_STATURE=1.6575
BODY_ACTIONS=76
Wrote assets/characters/shared/innkeeper.glb
Character 'innkeeper' rebuilt and reimported.
real 16.83
user 58.85
sys 10.02
```

The focused runtime assertions remained 15/15 after the isolated rebuild measurement. After canonical `pickup` integration, the final focused suite is 16/16. The output GLB changed byte-for-byte because Blender 5.2.0 re-exported a binary committed with an earlier tool build; the semantic rig contract remained green. Generated binary churn is intentionally not committed as part of this proof.

### Budget accounting

| Deliverable | Measured end-to-end time | Budget | Result |
|---|---:|---:|---|
| Generated Innkeeper body with all 76 retargeted clips, export, import, and focused verification | 17.42 s (16.83 s rebuild + 0.59 s focused test) | Under one working day | Pass |
| Integrate existing retargeted `PickUp` as canonical `pickup`, add a non-looping source-clip contract, and complete focused verification | 21 s (02:48:10 mapping start to 02:48:31 clean strict-gate log) | Under one hour | Pass |

The variant timing excludes creative review and iteration because the committed Innkeeper spec already supplies the approved input parameters. New identity authoring remains a human art-direction activity, while this gate measures the repeatable production pipeline named by the task.

## Retarget and animation integration procedure

### Existing source clip

Every generated body already carries the same 76 clips from the CC0 build input. To expose one of them to gameplay:

1. Inspect the source animation names in `assets/characters/shared/kaykit_barbarian.glb` or the Godot import inspector.
2. Add one canonical-to-source entry to `SharedCharacterRig.CANONICAL_ANIMATIONS`.
3. Add the canonical name to `LOOPING_ANIMATIONS` only when the motion must loop.
4. Add the canonical name to `REQUIRED_ANIMATIONS` in `test_character_rig.gd` when it becomes part of the production contract.
5. Run the focused rig suite and capture the gameplay-scale showcase if the pose is visually new.

No mesh, skeleton, per-facing asset, or character-specific controller change is allowed for this path.

### New external motion clip

A motion that is not in the pinned 76-clip source set must be processed before runtime integration:

1. Confirm redistribution rights and add source/license/provenance metadata before copying the motion into the build input.
2. Retarget the motion to the exact shared skeleton node names and rest pose used by `kaykit_barbarian.glb`; preserve translation, rotation, and scale channel semantics.
3. Add the clip to the source GLB animation collection without replacing or renaming existing clips.
4. Run `tools/rebuild_hero_character.sh hero` and at least one non-hero body. `build_heroic_humanoid_glb.py` applies each character's translation factors and arm-rest offsets to every animation channel during skeleton retarget.
5. Integrate the resulting clip through the canonical mapping procedure above.
6. Verify the clip at four facings, at the 2.0-unit/64-pixel scale, and on a second generated body. Reject the clip if it requires per-character or per-direction assets.
7. Record elapsed authoring, retry, rebuild, import, test, and capture time. If total time exceeds one hour, replace or cut the motion per ADR 0007.

The current proof covers the existing 76-clip library. A future genuinely new external motion must retain its own measured provenance and timing record rather than inheriting this result.
