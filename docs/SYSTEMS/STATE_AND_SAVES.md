# Game state, rules, and saves

Status: implemented (tasks **P1-007** session state, **P1-008** save envelope, **P1-009** debug presets). Scope: the campaign state model, the declarative condition/effect engine every content record uses, save slots, and developer state jumps. Ownership rules and the state table are in [`ARCHITECTURE.md`](../ARCHITECTURE.md#state-persistence-and-content). This file covers behavior and usage.

## GameState

`scripts/state/game_state.gd` (`GameState`) is the single campaign model. It holds:

| Data | Range / shape | Written by |
|---|---|---|
| Phase | `phase.*` ID; slice order is `prologue_day → investigation_morning → investigation_night → consequence_night → reflection_morning` | `set_phase` effect, `PhaseDirector` rest anchors |
| Flags, facts | `flag.*` booleans/values, `fact.*` known evidence | effects, investigations |
| Relationships | `char.*` → `-3..3` | `adjust_relationship` |
| Pressures | `pressure.suspicion`, `pressure.solidarity`, `pressure.scarcity` → `0..3` | `adjust_pressure` |
| Faction ledger events | explicit `event_id` per faction | `record_faction_event` ([`FACTIONS_AND_ECONOMY.md`](./FACTIONS_AND_ECONOMY.md)) |
| Living City Hope/Fear | `0..20`, default 8, deltas `-5..5` | Living City events ([`LIVING_CITY.md`](./LIVING_CITY.md)) |
| Quest and location states | per `quest.*` / `loc.*` | `QuestManager`, `set_location_state` |
| Forged records | `ForgedRecord` per commission | forge commission runner |
| Inventory bag, equipment | `InventoryBag` 8×5 grid, 28 kg cap | [`INVENTORY_MECHANICS.md`](../INVENTORY_MECHANICS.md) |
| Forge technique | Iron / Ember / Root or none | quick menu technique toggle |
| Magic resources, grants | willpower etc. | [`MAGIC.md`](./MAGIC.md) |
| NATURAL aspect ranks, psyche states | baseline 5, cap 50 | [`NATURAL.md`](./NATURAL.md), [`PSYCHE.md`](./PSYCHE.md) |
| Guilt per school (`guilt.church`, `guilt.folk`, `guilt.civic`), recorded act IDs, used rite IDs | level 0..10 per school; saved under `guilt` (optional in older saves) | [`SPIRIT_DIALOGUE.md`](./SPIRIT_DIALOGUE.md#guilt-implemented-sd-03) |
| Learned spirit-duel moves (`move.<kind>.<element>`) | set of ids; saved under `learned_moves` (optional in older saves) | [`SPIRIT_DIALOGUE.md`](./SPIRIT_DIALOGUE.md#observation-mode-implemented-prototype-sd-06) |
| Language comprehension (`lang.*`) | 0..100 per language, Estonian fixed at 100; saved under `language_comprehension` (optional in older saves) | [`SPIRIT_DIALOGUE.md`](./SPIRIT_DIALOGUE.md#language-comprehension-implemented-sd-08) |
| Hero traits (`trait.*` -> `gift` or `scar`) | one origin per trait; saved under `traits` (optional in older saves) | [`SPIRIT_DIALOGUE.md`](./SPIRIT_DIALOGUE.md#traits-and-temperaments-implemented-sd-15) |
| Weather snapshot | JSON-safe `SkyWeatherState` payload | [`SKY_WEATHER_STATE_CONTRACT.md`](../SKY_WEATHER_STATE_CONTRACT.md) |
| World items, stable map objects | placed/taken items, `MapStableStateStore` | [`WORLD_LIFE.md`](./WORLD_LIFE.md) |

Signals: `phase_changed`, `items_changed`, `equipment_changed`, `forged_record_added`, `faction_event_recorded`, `living_city_event_recorded`. Serialization lives in `game_state_persistence.gd` (`GameStatePersistence`, save `CURRENT_VERSION` 2).

## Conditions and effects

Content never runs code. Dialogue nodes, choices, barks, quest transitions, and debug presets carry declarative operations from the allowlist in [`schemas/common.schema.json`](../../schemas/common.schema.json). `StateRuleEvaluator` (`scripts/state/state_rule_evaluator.gd`) is the runtime counterpart: `evaluate_conditions(conditions, state)` and `apply_effects(effects, state)`.

| Conditions (`op`) | Effects (`op`) |
|---|---|
| `always`, `flag_is`, `flag_not`, `fact_known`, `phase_is`, `pressure_at_least`, `relationship_at_least`, `faction_standing_at_least`, `district_pressure_at_least`, `district_price_tier_at_least`, `item_owned`, `quest_state_is`, `forged_modification_is`, `memory_recorded`, `commission_deadline_met`, `commission_deadline_missed` | `set_flag`, `set_fact`, `set_phase`, `set_quest_state`, `adjust_pressure`, `adjust_relationship`, `record_faction_event`, `add_item`, `remove_item`, `set_location_state`, `record_memory` |

Each operation takes `key` (a content ID), optional `value`, and an `amount` from `-3..3`. Adding an op means changing the schema, the Python validator, and `StateRuleEvaluator` together.

## SessionState and replacement

`SessionState` (autoload, `scripts/session/session_state.gd`) owns the live `GameState`, `ContentDB`, `SaveService`, the debug presets, and `Act2MissionHost`. It also owns the weather payload; map runtimes only bind to it (`bind_environment_runtime`), so map transitions keep the weather timeline.

A new game seeds the starter magic grants (`magic.grant.starter_fireball`, `starter_earth_tremor`, `starter_iron_skin`) and 8 willpower.

`replace_state(replacement, reason)` is the only way to swap the live state (load, debug preset). It emits `state_replaced(previous, current, reason)` once; long-lived consumers must rebind in that handler.

## Saves

| Item | Behavior |
|---|---|
| Location | `user://saves/slot_<n>.json`, slots `0..8`, with `slot_<n>.bak.json` rolling backup and an atomic temp-file write |
| Autosave | `PhaseDirector` saves to slot 0 on every phase change |
| Manual save | Quick menu → **Save game** (current slot) |
| Load | Main menu **Load** opens the save list (`scenes/menu/save_list_overlay.gd`); entries show phase, location, spawn, and time |
| Envelope | `SaveEnvelope` validates and migrates (envelope version 1). A failed load leaves the live state untouched |
| Fixtures | Released saves in `content/saves/released/` (must keep loading), Act 1 boundary and Act 2 route saves in `content/saves/act1/`, `content/saves/act2/`. See [`content/saves/README.md`](../../content/saves/README.md) |

## Debug state jumps

In debug builds, F10 toggles `DebugStateInspector`, which applies presets from `content/debug/debug_state_presets.json`: `reset` (demo fresh, post pickup), `phase` (each slice phase), and `branch` (Maker's Mark ledger branches, dialogue trust). Presets go through `replace_state` and never touch save files. The quick menu **Debug** button opens the broader `DebugOverlay`.

## Verify

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_save
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_state_rule
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_debug_state
python3 tools/validate_content.py content/examples/valid content/examples/support
```
