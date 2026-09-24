# WS-14 — Swimming and diving (ADR first, then implementation)

Part of the [water and sky task pack](README.md). Reference behaviour: Tidewater's player controller
(`mode = walk | deck | swim`, `floating`, the pull to the surface
`y += (surface − y)·(1 − e^(−5·dt))`, the halved upward velocity when floating, stroke audio every
1.3 m, `submerge()`/`emerge()` on the camera crossing the surface, and ladder climb-out prompts).

> **Scope gate.** Swimming and diving are a **new mechanic**. They are not in the README scope, and
> P0-227 explicitly kept the camera above water. Under [`AGENTS.md`](../../../AGENTS.md) → *Scope-change
> rule*, no code may be written until **Phase 1** (the ADR) is accepted by a human maintainer and the
> ADR names the scope removed in exchange. Phase 2 is written out below so the ADR can reference a
> concrete, costed plan.

## Player-facing goal (after acceptance)

Kalev can wade into shallow water and slow down. In deeper harbour water he swims at the surface
with his head above the waves, bobbing with the swell. He can hold a key or button to dive, look
around underwater (WS-13 view) and surface again. He climbs out at beaches, stairs and ladders. He
can't swim while carrying heavy gear, so there's a real choice before jumping in.

---

## Phase 1 — ADR (documentation only)

### Allowed files

- `docs/adr/0021-swimming-and-diving.md` (new; confirm that 0021 is still the next free number)
- `TODO.md` (add WS-14a for the ADR and WS-14b for the implementation, with WS-14b blocked on the
  ADR)

### The ADR must decide (Status / Context / Decision / Alternatives / Consequences, like ADR 0001)

1. **Scope trade.** Which item from the README's "Explicitly excluded from the first campaign" list,
   or which approved slice task of comparable cost, is removed or deferred. The maintainer chooses.
   The agent lists candidates with rough costs and doesn't pick one.
2. **Where swimming is allowed.** Which water terrains (`shallow_water` for wading, `water` and
   `deep_water` for swimming, `river_water` with current drift or not at all), and which maps
   (vertical-slice Lower Town only, or harbour maps once active).
3. **Movement model on the orthogonal logic plane.** Water cells are non-walkable today
   (`scripts/map/map_verification.gd` `is_walkable_cell`). Decide whether swimming adds a separate
   traversal layer (recommended: the player only, with a separate `is_swimmable_cell`, and NPC
   pathing and map audits unchanged) or changes walkability globally (not recommended).
4. **Constraints and risk.** Is there a breath meter (and what happens at zero)? Can Kalev swim
   with the hammer or armour (weight rule)? What happens to inventory items that can get wet? Is
   combat allowed in water (recommended: no)? Can quests or night missions use water routes
   (escape and infiltration)? How does the faction-ledger and Living City consequence system see a
   swimming player (e.g. being seen swimming at the harbour at night)?
5. **Historical plausibility note** for `docs/CANON.md`: medieval swimming ability in Hanseatic
   Reval, with a confidence label.
6. **Assets needed.** Swim, tread-water and dive animation clips (retargeted CC0, following the
   character pipeline), splash VFX, and stroke, submerge and emerge SFX (audio attribution
   pipeline). List each as a separate follow-up task.
7. **Save and load.** The new persistent state (medium, breath) and the save envelope version bump
   rules.

### Phase 1 verification

- `python3 tools/generate_active_docs_report.py --check`.
- The maintainer's acceptance is recorded in the ADR status line. Without it, Phase 2 doesn't
  start.

---

## Phase 2 — Implementation (only after ADR acceptance)

### Allowed files (confirm against the accepted ADR; the ADR may narrow them)

- `scripts/map/map_verification.gd` (add `is_swimmable_cell`, leaving `is_walkable_cell` unchanged)
- `scripts/map/view3d/map_view_runtime_actors.gd`, `scripts/map/view3d/map_view_runtime_input.gd`
  (player medium state and input)
- `scripts/map/view3d/player_swim_state.gd` (new, `class_name PlayerSwimState`: a pure state machine)
- `scripts/map/view3d/underwater_pass.gd` (hook audio and the lens to the player's medium, not only
  the camera's)
- Save service files named by the ADR (the medium and breath fields)
- `docs/CONTROLS.md`, `docs/CANON.md`
- `tests/godot/test_player_swim_state.gd` (new), `tests/godot/test_save_service.gd`
- `docs/reports/images/ws14_*.png`
- `TODO.md`

### Dependencies

- TODO: WS-14a (the ADR accepted), **WS-13** (underwater view), **WS-05**
  (`OceanFftSampler.height_at`), and the animation asset follow-ups from the ADR.

### Deliverable

1. **`PlayerSwimState`**: a pure, deterministic state machine that can be tested headless.
   - States: `WALK`, `WADE`, `SWIM`, `DIVE`, `CLIMB_OUT`.
   - `WALK → WADE` when stepping into `shallow_water`. Speed is ×0.6 and running is disabled.
   - `WADE/WALK → SWIM` when the water depth at the player > 1.1 m (from the bed height and
     `height_at`). Speed is ×0.45. The hammer is stowed, or entry is blocked if the ADR weight rule
     forbids it, in which case a prompt explains why.
   - `SWIM → DIVE` while the dive action is held. Descend at 1.2 m/s to the bed or the ADR's maximum
     depth. Releasing it makes buoyancy return the player to the surface.
   - **Surface float** (Tidewater): `y += (surface_y − 0.15 − y)·(1 − exp(−5·dt))`, where
     `surface_y` comes from `OceanFftSampler.height_at`. Halve any upward velocity while floating.
     The head bobs with the real waves.
   - `SWIM → CLIMB_OUT` when the player is adjacent to a walkable cell that is a beach, stair or
     ladder anchor, and presses interact (the prompt uses the existing Interactable focus/prompt
     system), or walks into a beach. Quay walls without a ladder or stair anchor can't be climbed.
   - River current (if the ADR allows rivers): drift at `flow_direction·flow_strength`.
   - Breath (if the ADR has it): a meter that drains in `DIVE`, and whatever consequence the ADR
     decided at zero.
2. **Logic-plane traversal:** player movement consults `is_swimmable_cell` only while in a swim
   state. NPC pathing, `nearest_walkable_cell` and the map audits don't change.
3. **Presentation:** swim animations (from the asset follow-ups), splash VFX at entry and exit,
   ripples (WS-15 if present), and the camera switching WS-13 audio and lens by the **player's**
   medium in first person.
4. **Input:** keyboard and mouse plus gamepad bindings for dive and surface, documented in
   `docs/CONTROLS.md`. No new bindings are needed for swimming itself.
5. **Save and load:** persist the medium and breath. Loading a save made mid-swim restores the
   player floating at the surface.

### Phase 2 verification

1. The headless suite passes. `test_player_swim_state.gd` covers:
   - every transition, including the blocked entry under the weight rule
   - float convergence to `surface − 0.15` within 1 s
   - dive and resurface
   - climb-out only at allowed anchors
   - current drift
   - breath consequences
   The save round-trip covers a mid-swim save.
2. Map audits unchanged: `python3 tools/verify_map_audit.py`, `python3 tools/verify_map_activation.py`,
   and `godot --headless --path . --script tools/validate_map_blueprints.gd`.
3. A manual keyboard and gamepad run on the ADR's allowed map, with a clip showing wading, swimming
   with the head bobbing on the waves, diving (the WS-13 view), surfacing (wet lens) and climbing
   out at a ladder. Captures go in `docs/reports/images/ws14_*.png`.

### TODO rows

```text
- [ ] WS-14a | deps: WS-13 | deliverable: ADR 0021 swimming and diving naming the removed scope, allowed water/maps, player-only traversal layer, breath/gear/combat/consequence rules, canon note, asset follow-ups and save fields | allowed files: `docs/adr/0021-swimming-and-diving.md`, `TODO.md` | verify: active docs check; maintainer acceptance recorded in ADR status
- [ ] WS-14b | deps: WS-14a, WS-13, WS-05 | deliverable: PlayerSwimState (walk/wade/swim/dive/climb-out, FFT surface float, player-only swimmable traversal, ADR rules) with input, presentation hooks and save/load | allowed files: per accepted ADR 0021 | verify: swim state + save tests; map audits unchanged; keyboard/gamepad clip of wade/swim/dive/surface/climb-out
```
