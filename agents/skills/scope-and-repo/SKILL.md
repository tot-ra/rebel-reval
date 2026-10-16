---
name: rebel-scope-and-repo-map
description: Reval Rebel repository map, what is playable today, in/out-of-scope features, and the scope-change procedure. Read when planning a feature, creating tasks, or unsure where something lives.
---

# Scope and repository map

## Repository map

| Path | Role |
|------|------|
| `project.godot` | Godot **4.7** (pinned in [`.godot-version`](../../../.godot-version)), GL Compatibility, main scene `res://scenes/menu/main_menu.tscn` |
| `export_presets.cfg` | One macOS preset `rr` (universal) |
| `scripts/` | Runtime GDScript; autoload `DoorNavigator` (`scripts/global/door_navigator.gd`) |
| `scenes/` | Godot scenes plus legacy location notes |
| `content/` | Validated runtime JSON (transitions in `content/transitions/active_destinations.json`) |
| `assets/` | Runtime art; provenance in `assets/SOURCES.csv` |
| `tests/godot/`, `tests/python/` | Automated tests |
| `tools/` | Validators, capture, export, and CI helpers |
| `docs/` | Active docs; ADRs in `docs/adr/`; reports in `docs/reports/` |
| `story/`, `history/` | Narrative and research, mixed canon status. Start at [`history/RESEARCH_INDEX.md`](../../../history/RESEARCH_INDEX.md) |
| `characters/`, `img/`, `music/`, `sounds/`, `bin/` | Reference art, marketing images, audio library, legacy build artifact |

Large binaries follow [`docs/ASSET_STORAGE_POLICY.md`](../../../docs/ASSET_STORAGE_POLICY.md). `docs/reports/images/` is excluded from import via `.gdignore`.

## Playable today

Main menu → New Game opens in the seamless city inside Kalev's smithy (first spirit duel against the porter fought in place, Kalev takes the apprentice; hold Esc skips) → Lower Town (`reval_east`) → forge, with Mart conversation and anvil spearhead pickup. Also implemented: movement, manifest transitions, interactables, session `GameState`, inventory/journal, quick menu, district map with click-to-travel, phase director hooks, save service, combat foundation (through P1-026b), packaged macOS export. Do not assume full combat, night consequence, or faction-ledger loops exist.

## Scope

The game is a three-act faction RPG ([ADR 0008](../../../docs/adr/0008-three-act-campaign-and-faction-scope.md), amended by [ADR 0017](../../../docs/adr/0017-legacy-design-reintroduction.md)). Delivery order is strict: demo → vertical-slice MVP → Act 1 → Act 2 → Act 3. Legacy reintroduction is tracked in **P7** and [`docs/LEGACY_REINTRODUCTION.md`](../../../docs/LEGACY_REINTRODUCTION.md).

**In scope (gated by their tasks):** an 18-year-old clairvoyant orphan apprentice as protagonist with Kalev as master smith and the forge as hub, spirit-world dialogue combat, and hybrid physical combat with per-school guilt ([ADR 0033](../../../docs/adr/0033-teen-protagonist-and-spirit-dialogue-combat.md), age amended by [ADR 0058](../../../docs/adr/0058-protagonist-age-18.md); the prototype still controls Kalev until its tasks land, and it replaces physical night-mission templates and tower bosses). The commission → investigation → modification → consequence → reflection loop. One dense Lower Town district for the slice. Seven core characters plus faction casts. Authored offline dialogue. Eight factions with ledger standing and Living City Hope/Fear. Night missions. Hammer combat, forge techniques, dual-school magic, NATURAL aspects, Hingepuu psyche. Seamless traversal of Reval and its hinterland, including walking into buildings ([ADR 0019](../../../docs/adr/0019-seamless-contiguous-location-streaming.md), [ADR 0027](../../../docs/adr/0027-reval-hinterland-streaming-group.md), [ADR 0028](../../../docs/adr/0028-seamless-building-interiors.md)). All state is deterministic.

**Out of scope:** a seamless Estonia-wide open world: distant regions (Saaremaa, Padise, Pärnu and the other travel maps) keep an explicit journey with a loading transition. Other cities. Runtime LLM, procedural quests, or free-text chat. Party control, army or fleet battles, survival sims. Tower capture, naval, and castle-building mini-games (need an ADR first). Activating a map before its task and gates pass. Shipping legacy pixel sprites or old HUD art. A universal good/evil morality score.

## Scope change procedure

A new major system, mechanic, area, or pillar needs all three: (1) removal of equivalent-cost scope, named explicitly; (2) the next numbered ADR in `docs/adr/` (Status / Context / Decision / Alternatives / Consequences); (3) a task with allowed files, dependencies, and verification. The ADR must be merged or human-approved before coding.

Other rules:

- Do not implement ideas from legacy root or `scenes/` markdown unless README / ADR 0017 reconciles them and they have a task.
- Named historical claims need confidence labels in `docs/CANON.md`.
- Do not add major frameworks, event buses, or giant scene edits without a task that names the allowed files and verification.
- **Asset freeze (P0-040):** do not add or replace legacy isometric tiles/props/characters, pixel-frame animation assets, or superseded HUD/NATURAL/element art. New production art needs a task naming the exact files. Fixes to shipped assets need the same.
