# Combat animation system

Status: implemented (task **R-1161**). Owner: dev. Scope: Kalev's melee move sets, evasion, cast gestures and the transitions between them. Enemy move sets, root motion and authored (non-library) clips are out of scope here; see §9.

Goal: Witcher-3-style readability. Every input produces a visible, weighted action; each weapon class swings differently; a chain of strikes reads as one motion; rolls and casts blend in and out instead of popping.

## 1. Principles

1. **One clock.** Gameplay timing (impact, duration, cancel windows) lives in `PlayerActionStateMachine`. The rig never runs its own clip clock for a committed action: `SharedCharacterRig.sync_action_presentation` maps the action's elapsed time onto the source clip every frame. The visible contact frame therefore lands on the single `attack_impact` signal at any frame rate.
2. **One record per move.** `CombatMove` stores logic timing and presentation (source clip contact second, hit-stop, lunge) side by side, so they cannot drift apart.
3. **Items own numbers, moves own motion.** An item's `gameplay.attack_profile` keeps base damage, reach, stamina and damage type. Its `gameplay.weapon_class` selects a move set; a move only scales the item's numbers (`damage_mult`, `reach_mult`, `stamina_mult`). Items without `weapon_class` fall back to the prefix of their authored `animation` (`hammer_*` -> hammer) and then to unarmed.
4. **Deterministic.** No randomness in move choice; the chain step is a pure function of input timing.

## 2. Attack input and combo chain

| Input | Keyboard / mouse | Gamepad | Result |
| --- | --- | --- | --- |
| Tap attack | left click (third / first person) | X | Next **light** strike of the chain, committed on release |
| Hold attack | hold left click | hold X | **Heavy** strike, fires when the hold passes the charge threshold (0.35 s), without waiting for release |
| Guard / parry | `F`, right click | LB | Unchanged (P1-026) |

Left click is routed by `MapClickInputController` (attack vs interact vs travel). `PlayerActionInput` ignores the `player_attack` action while the left button is down, so the input map binding only documents the default and serves rebinding.

Chain rules (`PlayerActionStateMachine`):

- Each weapon class has a three-step light chain. Step N+1 starts only if the press arrives during step N or within `COMBO_GRACE_SEC` (0.3 s) after it ends. Otherwise the chain restarts at step 0. A fourth press wraps to step 0.
- A press during a swing is buffered. Once that swing has landed its impact and passed its `cancel_sec`, the buffered strike starts immediately and cuts the follow-through. This is what makes a chain read as one motion instead of three separate swings.
- A heavy strike is its own verb: it never advances the chain, and the next light press after it is step 0.
- Each attack spends its stamina when it starts. A press without enough stamina does nothing.
- An attack turns Kalev toward a hostile within 1.8x reach in his front half-plane (soft lock) and lunges `lunge_px` toward it between start and impact. The lunge stops 30 px short of the target.

Input edges (`just_pressed` / `just_released`) are handed out once per physics frame (`PlayerActionInput._consume`). A tap that starts and ends inside one frame still produces exactly one light strike.

## 3. Evasion: roll and sidestep

| Input | Keyboard | Gamepad | Action |
| --- | --- | --- | --- |
| Roll | `Space` + direction | RT + left stick | Roll toward the held direction. Forward, left and right turn Kalev into the roll; backward (or no direction) rolls back while still facing the threat |
| Sidestep | `Q` + direction | RB + left stick | Short 0.28 s hop (`Dodge_*` clips, P1-025) |

| Property | Roll | Sidestep |
| --- | --- | --- |
| Duration | 0.62 s | 0.28 s |
| Distance | 112 px, ease-out over the first 0.5 s, get-up in place | 80 px, linear |
| Invulnerability | 0.04-0.40 s (while tucked); push-off and get-up are punishable | whole action |
| Stamina | 22 | 18 |
| Early exit | a buffered action may start from 0.48 s | after recovery |

Either evasion can cancel an attack's follow-through `EVADE_CANCEL_AFTER_IMPACT_SEC` (0.06 s) after its impact, never during the wind-up. Travel uses `move_and_slide`, so walls stop a roll exactly like walking. Distance is a pure function of the action clock.

Saved bindings from version 1 that still bind `Space` to attack drop that default on load (`InputBindingSettings.BINDINGS_VERSION` = 2). A deliberate custom binding survives.

## 4. Move sets

Clips come from the shared 76-clip CC0 library on the shared rig (ADR 0022). `source_contact_sec` was measured on the shared skeleton as the frame of peak `hand.r` speed / furthest reach (`foot.r` for the kick). Times are logic seconds; multipliers apply to the item's base profile.

| Class | Step | Canonical id | Source clip | Impact / duration / cancel | Contact | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Unarmed | 1 | `unarmed_attack` | `Unarmed_Melee_Attack_Punch_A` | 0.22 / 0.55 / 0.36 | 0.48 | jab |
| | 2 | `unarmed_attack_2` | `Unarmed_Melee_Attack_Punch_B` | 0.24 / 0.58 / 0.38 | 0.52 | cross |
| | 3 | `unarmed_attack_3` | `Unarmed_Melee_Attack_Kick` | 0.28 / 0.68 / 0.50 | 0.36 | x1.4 damage |
| | heavy | `unarmed_heavy_attack` | `Unarmed_Melee_Attack_Kick` | 0.42 / 0.88 / 0.70 | 0.36 | x1.8 damage, slower warp |
| Hammer | 1 | `hammer_attack` | `1H_Melee_Attack_Chop` | 0.34 / 0.76 / 0.52 | 0.68 | overhead chop |
| | 2 | `hammer_attack_2` | `1H_Melee_Attack_Slice_Horizontal` | 0.28 / 0.70 / 0.48 | 0.28 | flat sweep, wide arc |
| | 3 | `hammer_attack_3` | `2H_Melee_Attack_Slice` | 0.42 / 0.94 / 0.72 | 0.40 | two-hand finisher, x1.4 |
| | heavy | `hammer_charged_attack` | `2H_Melee_Attack_Chop` | 0.50 / 1.02 / 0.80 | 0.88 | item `charged_attack_profile` numbers |
| Sword | 1 | `sword_attack` | `1H_Melee_Attack_Slice_Diagonal` | 0.27 / 0.64 / 0.42 | 0.40 | diagonal cut |
| | 2 | `sword_attack_2` | `1H_Melee_Attack_Slice_Horizontal` | 0.22 / 0.58 / 0.38 | 0.28 | backhand, wide arc |
| | 3 | `sword_attack_3` | `1H_Melee_Attack_Stab` | 0.30 / 0.74 / 0.54 | 0.45 | lunging thrust, x1.3 |
| | heavy | `sword_heavy_attack` | `2H_Melee_Attack_Slice` | 0.42 / 0.92 / 0.70 | 0.40 | two-hand cut, x1.8 |
| Spear | 1 | `spear_attack` | `2H_Melee_Attack_Stab` | 0.30 / 0.70 / 0.48 | 0.45 | thrust |
| | 2 | `spear_attack_2` | `1H_Melee_Attack_Stab` | 0.28 / 0.66 / 0.46 | 0.45 | quick jab |
| | 3 | `spear_attack_3` | `2H_Melee_Attack_Slice` | 0.34 / 0.84 / 0.62 | 0.40 | shaft sweep, wide arc, x1.25 |
| | heavy | `spear_heavy_attack` | `2H_Melee_Attack_Stab` | 0.48 / 0.98 / 0.76 | 0.45 | long lunge, x1.25 reach, pierces guard |

Hammer step 1 and the hammer heavy deliberately repeat the item JSON timing so existing balance keeps one answer. Content fixtures: `item.forge_hammer` (hammer), `item.plain_sword` (sword), `item.watch_spear` (spear).

### Time warp

`CombatMove.source_time` maps logic time to clip time:

1. **Wind-up** (0 -> impact): quadratic ease. Most of the anticipation screen time goes to the wind-up, the downswing accelerates into the contact pose.
2. **Hit-stop** (impact -> impact + `hit_stop_sec`): the contact pose holds 30-100 ms. Weight comes from this pause, not from extra damage.
3. **Follow-through**: linear to the end of the clip.

Moves without a contact frame (rolls, sidesteps, hit reactions) stretch the clip linearly over the action duration.

## 5. Transitions

`SharedCharacterRig.play_animation` cross-fades with a duration chosen by `transition_blend_sec(from, to)`:

| Into | Blend | Why |
| --- | --- | --- |
| Attack from locomotion | 0.08 s | input must read instantly |
| Attack from attack (combo) | 0.10 s | chain flows from the previous follow-through |
| Roll / sidestep | 0.05 s | evasion is a panic button |
| Hit reaction | 0.04 s | impact must be immediate |
| Cast | 0.08 s | |
| Locomotion from an action | 0.22 s | a finished swing settles instead of popping to idle |
| Locomotion from locomotion | 0.18 s | walk / run changes |

While a clock-driven action plays, `set_locomotion_speed` leaves `speed_scale` at 1 and foot planting off; the action clock owns the pose.

**Root cause fixed by R-1161.** The previous presentation called `AnimationPlayer.pause()` and then `seek(t, true)`. On Godot 4.7 a paused player does not apply a seeked pose, so every swing stayed frozen at its blend-in pose (the right hand did not move at all). The rig now keeps the player playing, seeks every frame and calls `advance(0)`. `test_clock_driven_swing_actually_moves_the_weapon_hand` measures real bone travel, not seek times.

## 6. Cast gestures

Spells still resolve instantly in `MagicResolver`. After a successful cast, `SpellforgeController` asks the player for a gesture by delivery kind:

| Delivery | Gesture | Clip | Duration | Release |
| --- | --- | --- | --- | --- |
| `projectile` | `cast_projectile` | `Spellcast_Shoot` | 0.50 s | 0.18 s |
| `area_pulse`, `persistent_area` | `cast_area` | `Spellcast_Long` | 0.70 s | 0.36 s |
| anything else (self, touch) | `cast_self` | `Spellcast_Raise` | 0.62 s | 0.30 s |

Kalev is rooted during the gesture (state `CAST`). A cast is refused mid-swing, mid-roll, mid-sidestep and during a hit reaction; the armed spell stays armed. Casting from guard drops the guard.

## 7. The roll clip

The CC0 library has no roll, only 0.38 s side hops. `CombatRollClip` builds `combat/Roll_Forward` and `combat/Roll_Backward` per body on first use: it starts from the body's `Idle` frame, curls into a tuck (knees to chest, chin down, arms around the shins), rotates the hips 360 degrees about the lateral axis and stands up, re-solving hips height each key so the lowest body point touches the ground. Clips are cached per body and direction. `test_procedural_roll_tumbles_the_body_and_ends_standing` checks the body goes head over heels and ends where `Idle` starts.

## 8. Files and verification

| File | Role |
| --- | --- |
| `scripts/combat/combat_move.gd` | one move: timing, presentation, multipliers, time warp |
| `scripts/combat/combat_move_catalog.gd` | move sets per weapon class, roll and cast actions |
| `scripts/combat/attack_profile_resolver.gd` | item + move -> `AttackProfile` (`resolve_move`) |
| `scripts/player/player_action_state_machine.gd` | chain, cancel windows, `ROLL` and `CAST` states, roll i-frames |
| `scripts/player/player_action_input.gd` | once-per-frame input edges, roll action |
| `scripts/player.gd` | charge clock, stamina, soft lock, lunge, roll travel, cast gesture entry |
| `assets/characters/shared/shared_character_rig.gd` | canonical id -> clip, blends, clock-driven presentation |
| `scripts/characters/combat_roll_clip.gd` | procedural roll clips |
| `scripts/magic/spellforge_controller.gd` | cast gesture request |
| `scripts/settings/input_binding_settings.gd`, `project.godot` | `player_roll` action, bindings v2 |

Verification:

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_combat_animation
# End to end on engine frames: left click, Space+left roll and a cast animate the 3D PlayerRig
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_combat_animation_runtime
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_player_action_state_machine
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_combat_room
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_hammer_attack_presentation
```

## 9. Known limits and follow-ups

- Library clips are shared between classes (the sword horizontal slice also serves hammer step 2). Bespoke per-weapon clips are art work (P0-195 locomotion pass and a future combat clip pack).
- No root motion: travel is scripted in logic space (lunge, roll), the clip plays in place.
- The heavy strike has no separate charge-up pose while the button is held (0.35 s before it fires).
- Directional attacks (stick direction picks a different swing) and enemy move sets are not implemented.
