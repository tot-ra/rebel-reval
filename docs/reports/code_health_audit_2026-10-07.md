# Code-health audit: dead code, unwired features, stray files (2026-10-07)

Scope: every GDScript file under `scripts/` and `scenes/`, every scene, and every Markdown file, checked against the rule that each implemented feature is wired, documented, and reachable from the root README ([`AGENTS.md`](../../AGENTS.md#feature-documentation-mandatory)). This audit **removes nothing**. Each row needs a decision and a board task: wire it, finish it, or delete it.

## Method

- **Dead script**: no `.gd`, `.tscn`, `.tres`, or `project.godot` outside `tests/` and `tools/` references the file's path, `class_name`, or `uid://`.
- **Test-only script**: referenced only from `tests/` or `tools/`. Some of these are deliberate (gate models, audits), and others are features that were built but never mounted.
- **Unreferenced scene**: no script, scene, content, config, tool, or test references the `.tscn` path or UID. Scenes opened by hand in the editor show up here too, so check before deleting.
- **Unreachable doc**: `python3 tools/docs_index.py --check`.

## 1. Features built but not wired into play

| Feature | Files | Evidence | Needed to finish |
|---|---|---|---|
| Tower boss encounters (Nunnatorn, Kuldjala, Rentenitorn) | `scripts/combat/{nunnatorn,kuldjala,rentenitorn}_{boss_encounter,state_model}.gd` | Only tests and `tools/verify_nunnatorn_acceptance.py` use them; interior scenes in `scenes/reval_monastery/`, `scenes/reval_north/` never instantiate them | Mount each encounter in its interior scene and add a scene test. See [`SYSTEMS/COMBAT.md`](../SYSTEMS/COMBAT.md#towers-and-bosses) |
| Act 2 mission allies | `scripts/combat/mission_ally_{controller,script}.gd` | Tests only | Mount in Act 2 mission scenes when they exist |
| Padise monastery communities | `scripts/world/padise_monastery_controller.gd`, `padise_monk_actor.gd` | `scenes/world_travel/world_padise.tscn` does not use them | Mount in the Padise scene, or delete |
| Public-event overlays (festivals, processions) | `scripts/world/event_overlay_model.gd` | Tests only; no controller | Add a controller or delete |
| Act 2 finale, Act 3 ending | `scripts/quest/paide_finale_model.gd`, `act3_ending_model.gd` | Tests only | Expected until Act 2/3 scenes exist; keep, already documented in [`SYSTEMS/QUESTS.md`](../SYSTEMS/QUESTS.md#limits) |
| Investigative quest tiers | `scripts/quest/investigative_quest_model.gd` | Used by tests and `quest.stolen_iron`; no scene consumes the tiers | Wire into an investigation or delete |
| NATURAL points, psyche states, Living City events | `GameState` APIs (`spend_natural_point`, `apply_psyche_state`, Living City record) | No content op or scene writes them; reflection overlay only displays | P7-011 / P7-012. Status lines updated in [`NATURAL.md`](../SYSTEMS/NATURAL.md), [`PSYCHE.md`](../SYSTEMS/PSYCHE.md), [`LIVING_CITY.md`](../SYSTEMS/LIVING_CITY.md) |
| Settings without controls | `DialogueSettings.locale`, `.pseudo_localization`, `AudioSettings.voice_volume` | Stored and applied, absent from `GameSettingsOverlay` | Add rows, or drop the fields |

## 2. Duplicate implementations

| Duplicate | Files | Note |
|---|---|---|
| Two dialogue runners | `scripts/demo/demo_dialogue_runner.gd` + `demo_dialogue_box.gd` vs `scripts/dialogue/dialogue_runner.gd` + `dialogue_ui.gd` | The demo pair calls itself "superseded by P1-011 DialogueRunner" but still drives Mart's street talk (`DemoMartEncounter`) and the forge Henning/cat talks (`forge_dialogue_encounter.gd`). Migrate both to `DialogueRunner`, then delete the demo pair. [`SYSTEMS/DIALOGUE.md`](../SYSTEMS/DIALOGUE.md#limits) |

## 3. Dead scripts and scenes

Dead scripts (no references at all):

- `scenes/elements/FadeArea.gd` (+ `FadeArea.tscn`)
- `scenes/comparison_room/capture_variant.gd`, `verify_variants.gd` (+ `comparison_room.tscn`). Capture helpers from P0-033/P0-035; probably run by hand
- `scenes/map_prototype/capture_visual_target.gd`, `verify_visual_targets.gd`. Same pattern
- `scripts/ui/gameplay_help_hud.gd` (+ `scenes/elements/gameplay_help_hud.tscn`). Its own header says deprecated and unmounted
- `scripts/world/world_host_{launch_residents,mount_queue,package_inspector,residency_policy,seam_save}.gd`. Already deleted in the working tree by concurrent WB work at audit time

Unreferenced scenes (check for manual editor use before deleting):

`scenes/elements/building.tscn`, `location_hud.tscn`, `npc.tscn`, `turret.tscn`, `scenes/intro/intro.tscn`, `scenes/map/map.tscn`, `scenes/reval_toompea/domberg.tscn`, `maria_toomkirik.tscn`, `scenes/world/padise/padise_monastery2.tscn`, `scenes/tests/dialogue_overflow_test.tscn`, `dialogue_ui_test.tscn`, `font_glyph_render_test.tscn`.

Test-only by design (keep): `scripts/slice/*` gate models, `scripts/map/map_audit_registry.gd`, `map_blueprint_audit.gd`, `map_catalog.gd`, `map_composition_audit.gd`, `reval_fortification_registry.gd`, `scripts/quest/act1_traversal_model.gd`, `scripts/tower/completed_tower_packages.gd`, `scripts/map/definitions/outdoor/outdoor_prototype_renderer.gd`. Test-only view modules to wire or delete: `procedural_chicken_model.gd`, `map_view_environment_kit.gd`, `map_view_nunnatorn_interior.gd`.

## 4. Stray and malformed documents

| File | Problem | Suggested action |
|---|---|---|
| `content/es/**` (6 files) | Spanish pages for another product ("Planes de precios … Gratheon"); not game content | Delete from this repo |
| `character/WARRIOR-BUILD.md` | Empty (0 bytes) | Delete or write |
| `characters/order/README.md.md` | Double extension | Rename to `README.md` |
| `scenes/reval_toompea/Untitled.md` | Placeholder name | Rename or delete |
| `playbook.md`, `rebel_art_status_report_2026-07-29.md` (root) | Root clutter; the playbook index points at `agents/playbook.md` | Move under `agents/` and `docs/reports/` |

## 5. Broken links in legacy pages

Every Markdown file is now reachable, but some legacy pages link to files that were never written or have moved:

- `scenes/README.md`: about 190 links into the pre-reorganisation layout (`./revel_east/…`, `./revel_north/…`, `./revel_central_quarter/…`, `./lower_town/*_tower.md`).
- `characters/README.md`: about 25 links to `../../scenes/lower_town/…`, `../../scenes/events/…`, `../../scenes/world/…` location pages that do not exist.
- `assets/bestiary/README.md`: about 50 image links (`image-NN.png`, `kratt.png`, `../bandits/thug*.png`) with no files behind them, consistent with the P0-040 asset freeze.

Both READMEs carry `archive` / `reference` legacy status. Fixing them means pointing each link at the surviving `scenes/` note or removing it.

## 6. Documentation coverage after this audit

- Before: 530 of 921 Markdown files were unreachable from the root README, and most runtime systems (quests, dialogue, saves, phases, factions, HUD, settings, combat runtime, world life, 3D view) had no feature page.
- After: [`docs/README.md`](../README.md) is the hub, [`docs/SYSTEMS/`](../SYSTEMS/README.md) has one page per feature, and generated index blocks cover reports, tasks, characters, scenes, history, wiki, agents, content, and assets. `python3 tools/docs_index.py --check` keeps it that way.
