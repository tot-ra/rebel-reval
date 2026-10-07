# Time, phases, and patrols

Status: implemented for the vertical slice and Act 1 climax (tasks **P1-010** phase profiles, **P1-011** rest anchors and patrols). Scope: campaign phases, the authored per-location rules each phase applies, phase-boundary autosave, patrols and patrol barks, and the Toompea hill-gate curfew. Out of scope: the visual day/night cycle and weather ([`WORLD_PRESENTATION.md`](./WORLD_PRESENTATION.md), [`SKY_WEATHER_STATE_CONTRACT.md`](../SKY_WEATHER_STATE_CONTRACT.md)).

## Player-facing behavior

- Story time advances by phase; the sky clock and calendar ([below](#clock-and-calendar)) run alongside it. The slice runs `phase.prologue_day → phase.investigation_morning → phase.investigation_night → phase.consequence_night → phase.reflection_morning`. Act 1 adds `phase.act1_climax` (St. George's Night).
- Kalev advances the phase by resting at a bed (`PhaseRestAnchor`, default anchor `bed_alcove` in the smithy). Quest controllers can block rest until a commitment is made (for example the prologue ledger choice).
- Each phase can move or hide NPCs, hide props, and switch watch patrols on or off per location. Patrols walk their authored path and bark when they pass near Kalev (every 14 s at most, 96 px radius).
- Every phase change autosaves to slot 0 ([`STATE_AND_SAVES.md`](./STATE_AND_SAVES.md#saves)).

## Runtime pieces

| Piece | File | Role |
|---|---|---|
| `PhaseDirector` (autoload) | `scripts/phase/phase_director.gd` | Listens to `GameState.phase_changed`, resolves the phase profile, autosaves, snaps sun angle and music night bias, emits `profile_applied(profile, phase_id)`. `advance_to_next_phase()` follows `sequence_index`. |
| `PhaseProfileModel` | `scripts/phase/phase_profile_model.gd` | Looks up `phase_profile` records in `ContentDB`. |
| `MapPhaseBinder` | `scripts/phase/map_phase_binder.gd` | Per-scene: scenes register NPCs, props, and patrols; the binder applies the profile's `locations[]` entry for the current location. |
| `PhaseRestAnchor` | `scripts/phase/phase_rest_anchor.gd` | Bed interactable that advances the phase. |
| `MapPatrolController` | `scripts/phase/map_patrol_controller.gd` | Walks a `MapDefinition` patrol path (48 px/s × district speed scale). |
| `MapPatrolBarkPresenter` | `scripts/phase/map_patrol_bark_presenter.gd` | Proximity patrol barks through `DialogueRunner.play_bark`. Aftermath models swap its bark pool. |
| `HillGateCurfewController` | `scripts/world/hill_gate_curfew_controller.gd` | Opens or closes the Pikk jalg and Lühike jalg gates per phase and stores them as `hill_gate.*` location states. |
| `JurisdictionModel` | `scripts/world/jurisdiction_model.gd` | Vocabulary for the 1343 Toompea (Danish) / All-linn (Lübeck law) boundary, for developer tools. |

## Content

Phase profiles are `type: phase_profile` records ([`schemas/phase_profile.schema.json`](../../schemas/phase_profile.schema.json)), currently `content/examples/valid/slicephase.*.json` and `content/packages/st_georges_night/content/slicephase.act1_climax.json`.

```json
{"phase_id": "phase.investigation_night", "sequence_index": 2,
 "presentation": {"cycle_enabled": false, "cycle_progress": "0.02", "music_night_tracks": true},
 "locations": [{"location_id": "loc.lower_town_slice",
   "patrols": [{"patrol_id": "viru_watch", "enabled": true}],
   "npcs": [{"npc_id": "mart", "anchor_id": "brewery_door", "visible": true}]}]}
```

Patrol paths and NPC anchors are map data with stable IDs ([`MAP_AUTHORING.md`](../MAP_AUTHORING.md)).

## Verify

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_phase
```

## Clock and calendar

Two time layers run alongside story phases:

- **Day/night clock** (`scripts/global/day_night_cycle.gd`): the outdoor sun follows the player's local system time, so one game day lasts one real day. Phase profiles may pin it (`presentation.cycle_enabled: false` with a fixed `cycle_progress`). The debug overlay can scale it for review.
- **Campaign calendar** (`GameCalendar`, `scripts/global/game_calendar.gd`): each phase maps to a Julian 1343 date leading into St. George's Night in late April (`date_for_phase`). While an outdoor cycle runs, every completed solar day advances the date. Market days, seasons, and moon phase read this date ([`WORLD_LIFE.md`](./WORLD_LIFE.md#market-day)).

`MusicDirector` plays night themes at about −6 dB at full night.

## Limits

- Quest gating uses phases only. The clock and calendar drive presentation and ambient world life, not quest state.
- The hill-gate curfew and jurisdiction model serve the inactive Toompea map. They are not reachable in the shipped slice.
