# CO-10: Walk into the sea, swim, dive, and be able to drown

Board rows: **R-957** (ADR amendment and acceptance) and **R-958** (drowning on top of WS-14b).
Priority: high. Depends on: WS-13, WS-05, and for R-958 also WS-14b.

## Player-facing goal

Kalev can walk off the Kalamaja beach into the water. Knee-deep, he wades and slows. Deeper, he starts
to swim, floating on the same waves the boats ride. He can dive, see the seabed through the WS-13
underwater pass, and come up for air. If he stays under too long, or swims out too far while overloaded
and exhausted, **he drowns** - the sea is genuinely dangerous, not a soft wall that pushes him back up.

## Why this is needed

[ADR 0021](../../adr/0021-swimming-and-diving.md) already designs swimming and diving in full: the
player-only `is_swimmable_cell` traversal layer, wading in `shallow_water`, swimming in
`water`/`deep_water`, rivers staying blocking, a per-map `swimming_allowed` flag, a 20 s breath meter,
a 12 kg / no-body-armour entry gate, no combat in water, save fields `medium` and `breath_s`. Two
things block it:

1. **The ADR is still `Proposed, 2026-09-25. Awaiting maintainer acceptance.`** Its own status line
   forbids implementation code until acceptance is recorded, and item 1 (the scope trade) is explicitly
   a maintainer choice that nobody has made. WS-14b is therefore blocked, not merely unstarted.
2. **The ADR explicitly rules out drowning.** Item 4 reads: "At zero Kalev is forced to the surface and
   takes a fixed, non-lethal stamina penalty. **No drowning death**: a death state adds a fail loop,
   save-scumming pressure and a new game-over path." The maintainer has now asked for drowning to be
   possible, so this is a decision reversal that has to be written down with its consequences, not a
   quiet code change.

Some of ADR 0021 item 6 has already landed independently: submerge/emerge and dive-splash SFX shipped
through the audio attribution pipeline. Animation clips, splash VFX and the ladder/stair anchors have not.

## Deliverable, part 1 (R-957): amend and accept the ADR

Edit `docs/adr/0021-swimming-and-diving.md` in place (an ADR amendment, keeping the original text
visible and marking what changed, in the style of ADR 0008 amended by ADR 0017):

1. **Status** records the maintainer's acceptance, the date, and the chosen scope trade from item 1.
   Until the maintainer names the trade, the row stays open - do not pick it on their behalf.
2. **Item 4 (Breath) rewritten** around drowning:
   - Breath drains in `DIVE` and, at a slower rate, in `SWIM` while exhausted or over the weight gate.
   - At zero breath: a distinct **struggling** state with clear audio and visual warning, a grace
     window long enough to reach the surface from the deepest authored cell, then death.
   - Death by drowning uses the **existing** death/respawn path. If there is no existing player-death
     path yet, the amendment says so and the drowning outcome degrades to the non-lethal rule until
     the death loop exists - that keeps this task honest instead of inventing a game-over system.
   - Named mitigations against the save-scum problem the original ADR raised: audible and visual
     warning before the grace window, a surface indicator while submerged, breath restored fully on
     surfacing, and no drowning in `shallow_water` wading at any breath value.
3. **Item 2 extended** if the maintainer wants Saaremaa and the other coastal maps swimmable. The
   ADR's current answer is "`reval_harbor_north` and `reval_harbor_east` only". The screenshot that
   prompted this pack was the Kalamaja shore, so at minimum the two harbour maps; `world.saaremaa`
   should be listed explicitly as allowed or deferred, not left ambiguous.
4. **Item 7** gains `breath_s` semantics for the struggling state and the drowning outcome, and states
   whether `MapStableStateStore.CURRENT_SAVE_VERSION` bumps.
5. `docs/CANON.md` gets the item 5 canon note with its existing confidence labels.

## Deliverable, part 2 (R-958): implement drowning on top of WS-14b

WS-14b ships the `PlayerSwimState` machine per the accepted ADR. This row adds only the lethal path:

1. The `struggling` state, its entry and exit conditions, and the grace window.
2. Breath drain in `SWIM` under the exhausted / overloaded conditions, not just in `DIVE`.
3. Death by drowning wired to the existing death/respawn path, with the last safe shore cell recorded
   so respawn does not drop the player back into deep water.
4. Warning feedback: breath UI state, audio cue (reuse the landed submerge/emerge/splash set where it
   fits), and an underwater visual cue through the WS-13 pass.
5. Save/load: `medium` and `breath_s` round-trip, and a save taken while struggling loads as `swim` at
   the surface with full breath (never loads straight back into death).

## Allowed files

**R-957:** `docs/adr/0021-swimming-and-diving.md`, `docs/CANON.md`,
`docs/tasks/water_sky/WS-14_swim_dive_adr.md`, `docs/tasks/coast/README.md`, `TODO.md`.

**R-958:** per the accepted ADR, plus explicitly: the `PlayerSwimState` file created by WS-14b,
`scripts/player/player_action_state_machine.gd`, the save service files WS-14b names, the breath UI
file WS-14b names, `tests/godot/test_player_swim_state.gd`, `tests/godot/test_player_drowning.gd`
(new), the save round-trip test WS-14b names, `tools/capture_co10_drowning.gd` (new),
`docs/reports/co10_drowning.md`, `docs/reports/images/co10_*.png`, `TODO.md`.

## Constraints and non-goals

- **R-958 must not start before R-957 records acceptance.** The ADR status line is a hard gate.
- No survival simulation: no wet items, no temperature, no stamina overhaul beyond the breath meter and
  the exhaustion condition the amendment names.
- No combat, spells or attacks in water. ADR 0021 item 4 stands on that point.
- No global walkability change. The player-only `is_swimmable_cell` layer from ADR 0021 item 3 is the
  only traversal change; NPC pathing, navigation baking and every map audit stay untouched.
- `river_water` stays blocking.
- No new game-over system. Drowning reuses the existing death path or degrades to non-lethal.
- Do not enable `swimming_allowed` on a map the accepted ADR does not list.

## Verification

**R-957:**

```bash
python3 tools/generate_active_docs_report.py --check
```

- ADR status records maintainer acceptance, the date and the named scope trade.
- Item 4 states the drowning rule, the grace window, the mitigations and the fallback if no death path
  exists. Item 2 lists every allowed map explicitly. Item 7 states the save behaviour and version
  decision. `docs/CANON.md` carries the canon note with confidence labels.

**R-958:**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_player_swim_state,test_player_drowning
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd
python3 tools/verify_map_audit.py
python3 tools/verify_map_activation.py
python3 tools/generate_active_docs_report.py --check
```

- `test_player_drowning.gd` asserts: breath drains only under the ADR's conditions; the struggling
  state fires with the documented warning; the grace window is long enough to surface from the deepest
  authored swimmable cell on both harbour maps; drowning death uses the existing death path; respawn
  lands on a recorded safe shore cell; wading in `shallow_water` never drowns at any breath value;
  a save taken while struggling loads as `swim` at the surface with full breath.
- Map audits and the walkable-cell counts are **byte-identical** to before, proving the swimmable layer
  did not leak into `is_walkable_cell`.
- Keyboard **and** gamepad clip through `tools/godot_render.sh`: wade in, swim out, dive, look at the
  seabed, run the breath down to the warning, surface in time; then a second clip that drowns and
  respawns on shore.

## Doc updates

`docs/adr/0021-swimming-and-diving.md`, `docs/CANON.md`, `docs/CONTROLS.md` (swim/dive inputs),
`docs/reports/co10_drowning.md`, `docs/tasks/water_sky/README.md` (WS-14 status),
`docs/tasks/coast/README.md`, `TODO.md`.

## TODO.md lines

```
- [ ] R-957 | deps: none | deliverable: ADR 0021 amended and accepted - maintainer acceptance and scope trade recorded in Status, item 4 rewritten from "no drowning death" to a struggling state with a documented grace window, named save-scum mitigations and a non-lethal fallback if no death path exists, item 2 listing every swimmable map explicitly including world.saaremaa, item 7 covering breath_s and the save version, plus the CANON canon note | allowed files: `docs/adr/0021-swimming-and-diving.md`, `docs/CANON.md`, `docs/tasks/water_sky/WS-14_swim_dive_adr.md`, `docs/tasks/coast/README.md`, `TODO.md` | verify: active docs check; Status carries acceptance, date and named trade; items 2/4/7 complete; CANON note carries confidence labels; maintainer sign-off recorded
- [ ] R-958 | deps: R-957, WS-14b | deliverable: drowning on top of PlayerSwimState - struggling state, breath drain while exhausted or overloaded in SWIM, death through the existing death path, safe-shore respawn cell, breath UI plus audio and underwater warning cues, and save/load that never restores into death | allowed files: per docs/tasks/coast/CO-10_swim_dive_drown.md | verify: `--filter=test_player_swim_state,test_player_drowning` plus the full suite; map audit and activation byte-identical walkable counts proving no is_walkable_cell leak; grace window sufficient from the deepest swimmable cell on both harbour maps; wading never drowns; struggling save loads at the surface; keyboard and gamepad clips for the survive case and the drown-and-respawn case
```
