# Shared character rig (P0-037)

Status: **pipeline proof; pending second review and P2-004 model approval**  
Recorded: 2026-07-16  
Evidence: [`docs/reports/images/p0_037_character_rig.png`](../../docs/reports/images/p0_037_character_rig.png)

This folder owns the shared low-poly humanoid rig contract used by Kalev and later NPC variants. It deliberately does not edit the 2D player controller, map definitions, collision, navigation, or the P0-052 view layer.

## Source and approval boundary

The proof uses KayKit Character Pack: Adventurers, commit `672074b73ba276876a19e8816ecdc5241817ab47`. The bundled `Barbarian.glb` has one low-poly skeleton, 76 clips, embedded atlas material, and interchangeable equipment. Kay Lousberg releases the pack under CC0 1.0; the local license copy is [`shared/KAYKIT_CC0_LICENSE.txt`](shared/KAYKIT_CC0_LICENSE.txt), and the binary plus Godot-extracted texture have provenance rows in `assets/SOURCES.csv`.

The model is a technical P0-037 proof, not approved final Kalev art. P2-004 owns the approved Kalev/Mart/Aita/Kaja/Henning/Jürgen models after P0-040 freezes the art bible. Replacing this proof model must preserve the API and tests below.

## Stable runtime contract

Instantiate [`kalev/kalev.tscn`](kalev/kalev.tscn) or another variant and call:

```gdscript
character.set_facing(logic_direction)
character.play_animation(&"walk")
```

`set_facing()` rotates the 3D root, so no animation or asset is duplicated per direction. `play_animation()` accepts only the canonical project names below; vendor clip names remain private to `shared_character_rig.gd`.

| Canonical name | KayKit source clip | Use |
|---|---|---|
| `idle` | `Idle` | neutral loop |
| `walk` | `Walking_A` | logic-plane locomotion loop |
| `run` | `Running_B` | faster stride with contralateral forward/backward arm swing |
| `forge_strike` | `1H_Melee_Attack_Chop` | downward work strike |
| `hammer_attack` | `1H_Melee_Attack_Slice_Diagonal` | combat strike |
| `guard` | `Blocking` | held guard loop |
| `hit` | `Hit_A` | damage reaction |
| `fall` | `Death_A` | non-looping fall |

The runtime applies a non-destructive `SkeletonModifier3D` after every animation update to move the compact vendor silhouette toward adult heroic proportions: the head is reduced to `0.64`, both leg segments are lengthened to `1.30`, both arm segments to `1.24`, and the torso is compressed slightly to `0.88`. This keeps every mesh and animation on the shared rig while making the figure read closer to the grounded proportions of classic isometric RPGs.

The shared model is normalized to `2.0` world units. `CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE` is `28.125`, which projects that height to the carried-forward 64 px target in the 1600 x 900 viewport. P0-052 may read these constants but must not duplicate or silently change them; P0-040 can replace them when ART_BIBLE v2 is approved.

## Variant procedure

1. Duplicate a `.tres` in `kalev/` or `variants/`.
2. Give it a stable character ID and material tint.
3. Optionally assign an equipment `PackedScene` and toggle silhouette pieces.
4. Create a thin inherited `.tscn` that points the shared rig at that resource.
5. Run the character rig tests and inspect the gameplay-scale showcase.

`mart.tscn` proves this path: it uses the same model, skeleton, and animation library, changes the material tint and hat, and removes Kalev's bone-attached hammer. No mesh or animation was copied.

## Retarget procedure

The bundled clips were authored for the same KayKit humanoid skeleton used by this proof, so they play directly. For a Mixamo-class or other external humanoid library, use Godot's import retargeter rather than changing runtime code:

1. Export one animation-only glTF/GLB at 30 FPS with a T-pose facing +Z. Keep root motion only when gameplay owns root motion explicitly.
2. In Godot's Advanced Import Settings, select the `Skeleton3D`, assign `SkeletonProfileHumanoid`, and verify every required body mapping. Fix red/magenta missing or duplicate mappings before import.
3. Enable bone renaming and a unique skeleton node name so animation track paths match the shared target. Normalize position tracks for differing body heights; remove unmapped and non-bone tracks for animation-only libraries.
4. Use Rest Fixer's axis overwrite when source and target bone rests differ. Enable silhouette fixing only for an A-pose source and inspect feet/knees after import.
5. Import the file as an `AnimationLibrary`, attach it to the rig's `AnimationPlayer`, then add exactly one canonical-to-source entry in `CANONICAL_ANIMATIONS`.
6. Run `test_character_rig.gd`, inspect the clip at four root rotations, and regenerate the evidence sheet. Reject clips with foot sliding, ground penetration, hand/equipment separation, or a changed ground pivot.

Reference: [Godot stable documentation — Retargeting 3D Skeletons](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html).

## Measured production budget

Cold-cache measurements on 2026-07-16, Godot 4.7.1, Apple M5 Pro:

| Operation | Start → verified | Result |
|---|---:|---|
| Import shared rig, map all seven clips, attach hammer, add contract test | 21:06 → 21:10 EEST | 4 min |
| Produce Mart via material/equipment resource swap and verify shared skeleton/library | 21:06 → 21:10 EEST (inside the same batch) | under 4 min incremental |
| Add one canonical animation mapping | measured as part of the seven-clip batch | under 1 min average; under the 1 hour budget |

These are pipeline-operation timings, not P2-004 art-direction/modeling time. A new approved silhouette may take longer, but a variant that conforms to this rig must remain under one working day.

## Verification

```bash
godot --headless --path . --script assets/characters/showcase/verify_character_rig.gd
godot --headless --path . --script tools/run_godot_tests.gd
godot --path . --audio-driver Dummy --resolution 1600x900 assets/characters/showcase/character_rig_showcase.tscn -- --capture-p0-037
python3 tools/validate_asset_sources.py
```

All four `test_character_rig.gd` cases must pass: required animations/equipment, transform-driven facing, data-only second variant, and 64 px scale. The isolated verifier is available for rig iteration; the full repository suite remains the merge gate.
