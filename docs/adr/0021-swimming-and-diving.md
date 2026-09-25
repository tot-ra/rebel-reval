# ADR 0021: Swimming and diving

## Status

**Proposed, 2026-09-25. Awaiting maintainer acceptance.** No implementation code may land until this
line records the maintainer's acceptance and the chosen scope trade (Decision 1). Task: WS-14a
(board R-899). Implementation: WS-14b, blocked on this ADR.

## Context

The water and sky pack ([`docs/tasks/water_sky/README.md`](../tasks/water_sky/README.md)) ported the
Tidewater look: baked FFT sea (WS-03/04), boats on the same field through `OceanFftSampler` (WS-05),
and an underwater view pass with Snell's window and a waterline across the lens (WS-13, WS-13b). The
camera can now go under water, but Kalev cannot. P0-227 kept the camera above water on purpose.

Today every water terrain blocks movement. `MapTypes.WATER_TERRAINS` (`water`, `river_water`,
`shallow_water`, `deep_water`) is rejected by `MapVerification.is_walkable_cell`, which NPC pathing,
`nearest_walkable_cell` and every map audit share. Active maps with water are the harbour pair
(`reval_harbor_north`, `reval_harbor_east`); the Lower Town slice (`reval_east`) has almost none.

Swimming is a **new mechanic**. It is not in the README scope list. Under the `AGENTS.md`
scope-change rule it needs removal of equivalent-cost scope, this ADR, and a task with allowed
files and verification. The ADR must be accepted before coding.

Reference behaviour is Tidewater's player controller (MIT, see `notice.code.tidewater` in
[`docs/THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md)): `walk | deck | swim` modes, a surface
pull `y += (surface - y) * (1 - exp(-5 dt))`, halved upward velocity while floating, and
submerge/emerge events on the camera crossing the surface.

## Decision

The items below are the **proposed** decision. Items marked *maintainer choice* are not decided by
this document.

### 1. Scope trade (maintainer choice)

Swimming costs roughly **90-120 h**: WS-14b state machine, input, save and presentation (~40 h),
swim/tread/dive animation retarget (~24 h), splash VFX (~10 h), SFX with attribution (~8 h), map
anchor authoring for ladders and stairs on two harbour maps (~12 h), QA and captures (~12 h).
Candidates of comparable cost, none picked here:

| Candidate | Where it lives | Rough cost | Effect of deferring |
|---|---|---|---|
| Smuggling Run mini-game (`minigame.smuggling_run`) | `docs/MINI_GAMES.md`, A1 | ~80-100 h | Swimming can *carry* part of its fantasy (water infiltration) through authored night routes |
| Tavern Brawling mini-game (`minigame.tavern_brawl`) | `docs/MINI_GAMES.md`, slice/A1 | ~80 h | Removes a social-combat variant; hammer combat stays |
| P2-037..P2-042 bird GLB re-render batches | `TODO.md` P2 | ~96 h | Procedural birds stay; only fidelity is lost |
| Air Gust + Earth Tremor spells (R-722, R-724) | `docs/SYSTEMS/MAGIC.md` | ~32 h together, would need a third item | Fewer pagan combinations in Act 1 |
| WS-15 interactive ripples follow-ups beyond the landed version | water pack | ~30 h, would need a third item | Wakes stay at current fidelity |

Recommendation for the maintainer: **defer Smuggling Run to Act 2 or later**. It is the closest
overlap in player fantasy (night harbour infiltration), and an authored water route can cover part
of it. This is a recommendation only.

### 2. Where swimming is allowed

- `shallow_water`: **wading** (walkable for the player only, slowed).
- `water`, `deep_water`: **swimming** and diving.
- `river_water`: **not swimmable** in the first release. Currents need drift, audits and tuning for
  little gameplay value. It stays blocking.
- Maps: **`reval_harbor_north` and `reval_harbor_east` only**, gated by a per-map
  `swimming_allowed` flag in the blueprint (default `false`). Interiors, Lower Town, world
  locations and future maps stay dry until a task enables them.

### 3. Movement model on the orthogonal logic plane

Add a **player-only traversal layer**: `MapVerification.is_swimmable_cell(definition, grid, cell)`
returns true for `shallow_water`, `water` and `deep_water` cells that are not blocked by structures,
on maps with `swimming_allowed`. `is_walkable_cell`, `nearest_walkable_cell`, NPC pathing,
navigation baking and all map audits stay **unchanged**. `WATER_TERRAINS` stays as-is. The player
controller consults the swimmable layer only while in a water state (`WADE`, `SWIM`, `DIVE`).

Rejected: changing walkability globally (breaks NPC pathing, audits and every parity fixture).

### 4. Constraints and risk

- **Breath:** a breath meter of **20 s**, drained only in `DIVE`, refilled at the surface in 3 s.
  At zero Kalev is forced to the surface and takes a fixed, non-lethal stamina penalty. No drowning
  death: a death state adds a fail loop, save-scumming pressure and a new game-over path.
- **Gear:** entering `SWIM` requires the carried weight (bag plus equipped, the existing
  `reserved_weight_kg` rule) to be at most **12 kg** and no armour item equipped in the `body` slot (`EquipmentSilhouette.SLOT_ORDER`). The
  hammer may be carried (stowed on the back, unusable). Over the limit, entry is blocked at the
  wading edge with a prompt that names the reason. Wading has no weight rule.
- **Wet items:** no item damage or wet state. That would be a survival-sim system, which the README
  excludes.
- **Combat:** **none** in water. Attacks and spells are disabled in `SWIM` and `DIVE`. Enemies do
  not follow into water; they wait on the bank or lose track per their existing perception rules.
- **Quests and night missions:** water routes are allowed only as **authored** routes. A night
  mission may place a ladder or stair anchor to open an infiltration path. No quest may *require*
  swimming in the slice or Act 1 without its own task.
- **Consequences:** swimming is visible. Being seen swimming inside the harbour at night fires the
  existing `GameState.record_faction_event` hook as a suspicious-activity event (the same channel as trespass), not a
  new meter. Daytime swimming has no ledger effect.

### 5. Historical plausibility (canon note for `docs/CANON.md`)

To be added in WS-14b under *Daily Life & Social Relations*:

- **`plausible composite`**: Ordinary harbour folk, fishermen and some sailors in 14th-century
  Reval could swim, while many seafarers could not; ability was a personal skill, not a norm.
  Medieval lists of knightly accomplishments (for example Petrus Alfonsi's *Disciplina Clericalis*)
  include swimming, and Vegetius, read in the period, recommends it for soldiers. No Reval-specific
  source is known.
- **`invented`**: Kalev, a smith raised near the shore, can swim. He cannot swim in armour.

### 6. Assets needed (each a separate follow-up task)

1. Swim stroke, tread-water, dive-down, surface and climb-out clips, retargeted CC0 on the shared rig
   (character pipeline, ADR 0016/0020 budgets).
2. Splash VFX for entry, exit and strokes (GPU particles with a Compatibility fallback).
3. Stroke, submerge, emerge and climb-out SFX through the audio attribution pipeline
   (`CREDITS.md`).
4. Ladder and stair anchor props and blueprint anchors on the two harbour maps (map-authoring
   rules, stable IDs).

### 7. Save and load

- New persistent fields on the player record: `medium` (`walk | wade | swim | dive`) and
  `breath_s` (float).
- Loading a save in `dive` restores `swim` at the surface with full breath. Loading in `swim`
  restores the cell and floats at the surface.
- The fields are **optional with defaults** (`walk`, full breath), so older saves load unchanged.
  `MapStableStateStore.CURRENT_SAVE_VERSION` bumps from **2 to 3** only if the envelope validator
  rejects unknown keys; otherwise no bump. WS-14b must add a round-trip test either way.

## Alternatives

- **No swimming; keep water as a wall.** Zero cost, but the WS-13 underwater view has no gameplay
  use and the harbour stays a backdrop.
- **Wading only.** About a third of the cost; no diving, so WS-13 stays camera-only. A fallback if
  the maintainer wants a smaller trade.
- **Global walkability change.** Rejected in Decision 3.
- **Scripted swim cutscenes only.** Cheap, but not a mechanic; reads as a cheat in an RPG.

## Consequences

- Positive: the harbour becomes playable space; night missions gain an authored stealth route; the
  WS-05 sampler and WS-13 pass get a gameplay use.
- Negative: one new player state machine, one traversal layer and two save fields to maintain.
  Harbour maps need ladder and stair anchors. Every future map with water must decide the
  `swimming_allowed` flag.
- Scope: the item chosen in Decision 1 is removed or deferred in the same change that accepts this
  ADR (`docs/MINI_GAMES.md` or `TODO.md` updated accordingly).
- Follow-ups: WS-14b plus the four asset tasks in Decision 6, all blocked on acceptance.
