# AGENTS.md

Operational guide for AI agents and contributors working on **Reval Rebel**.

- Product vision, story, and scope: [`README.md`](./README.md) (source of truth)
- Work queue: project task board (`tasks` tool) for claims and progress; [`TODO.md`](./TODO.md) is the durable ID index
- Architecture and file ownership: [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md)
- Canon and visual baseline: [`docs/CANON.md`](./docs/CANON.md), [`docs/ART_BIBLE.md`](./docs/ART_BIBLE.md)
- Setup, headless commands, known issues: [`docs/SETUP.md`](./docs/SETUP.md), [`docs/reports/known_runtime_defects.md`](./docs/reports/known_runtime_defects.md)

README and this file override conflicting legacy documents. `docs/WRITING_GUIDE.md` and `docs/DECISIONS/` are planned (**P0-003**..**P0-005**) but do not exist yet.

## Repository map

| Path | Role |
|------|------|
| `project.godot` | Godot **4.7** (pinned in [`.godot-version`](./.godot-version)), GL Compatibility, main scene `res://scenes/menu/main_menu.tscn` |
| `export_presets.cfg` | One macOS preset `rr` (universal) |
| `scripts/` | Runtime GDScript; autoload `DoorNavigator` (`scripts/global/door_navigator.gd`) |
| `scenes/` | Godot scenes plus legacy location notes |
| `content/` | Validated runtime JSON (transitions in `content/transitions/active_destinations.json`) |
| `assets/` | Runtime art; provenance in `assets/SOURCES.csv` |
| `tests/godot/`, `tests/python/` | Automated tests |
| `tools/` | Validators, capture, export, and CI helpers |
| `docs/` | Active docs; ADRs in `docs/adr/`; reports in `docs/reports/` |
| `story/`, `history/` | Narrative and research, mixed canon status. Start at [`history/RESEARCH_INDEX.md`](history/RESEARCH_INDEX.md) |
| `characters/`, `img/`, `music/`, `sounds/`, `bin/` | Reference art, marketing images, audio library, legacy build artifact |

**Playable today:** main menu → Lower Town (`reval_east`) → forge, with Mart conversation and anvil spearhead pickup. Also implemented: movement, manifest transitions, interactables, session `GameState`, inventory/journal, quick menu, district map with click-to-travel, phase director hooks, save service, combat foundation (through P1-026b), packaged macOS export. Do not assume full combat, night consequence, or faction-ledger loops exist.

## Conventions

- Typed GDScript, `class_name` where useful, small reusable scenes, composition
- Scenes use `uid://` references. Commit `*.import` sidecars; `.godot/` is gitignored. `docs/reports/images/` is excluded from import via `.gdignore`
- Do not hand-edit giant city `.tscn` files without visual verification
- Stable content IDs look like `quest.bitter_brew`, `char.aita`, `flag.aita_detained`
- Large binaries follow [`docs/ASSET_STORAGE_POLICY.md`](./docs/ASSET_STORAGE_POLICY.md)

## Commands

Install Godot 4.7 per [`docs/SETUP.md`](./docs/SETUP.md). **Never open visible Godot windows:** pass `--headless` to every Godot command. Render captures that need a GPU run as `tools/godot_render.sh --script <tool>.gd` (minimized window, no focus).

| Purpose | Command |
|---------|---------|
| Headless import / startup smoke | See `docs/SETUP.md` (`--check-only` hangs, `DEF-001`) |
| Godot tests | `godot --headless --path . --script tools/run_godot_tests.gd` (runs `tests/godot/test_*.gd`) |
| Content validator | `python3 tools/validate_content.py content/examples/valid content/examples/support` |
| Content validator tests | `python3 -m unittest tests.python.test_validate_content -v` |
| Content schema examples | `python3 tools/validate_content_examples.py` |
| Active docs / links | `python3 tools/generate_active_docs_report.py --check` |
| Asset provenance / lint | `python3 tools/validate_asset_sources.py`, `python3 tools/verify_asset_lint.py` |
| Storage hygiene | `python3 tools/verify_storage_hygiene.py` |
| Map composition audit | `python3 tools/verify_map_composition.py` |
| Legacy archive headers | `python3 tools/archive_speculative_docs.py --dry-run` (no output = OK) |
| Performance report | `tools/run_performance_report.sh [out.json] [--quick]` (see `docs/PERFORMANCE_REPORT.md`) |
| Pre-commit gates | `tools/run_pre_commit_checks.sh [staged\|all]` |
| Export | `mkdir -p build && godot --headless --export-release "rr" ./build/rr.dmg` |

Tests use the repository's own harness (no GUT). Add `tests/godot/test_*.gd` files with zero-argument `test_*` methods; shared assertions are in `tests/godot/test_case.gd`. Add runtime JSON under `content/` only when it passes `tools/validate_content.py`. CI (`.github/workflows/ci.yml`) runs these checks plus a macOS export smoke. Codesigning is not configured.

## Map authoring (mandatory)

Before touching map content, read [`docs/MAP_AUTHORING.md`](./docs/MAP_AUTHORING.md) and [ADR 0009](./docs/adr/0009-map-blueprint-authoring-architecture.md).

- Author through `MapBlueprint` primitives and reviewed prefabs (`scripts/map/prefabs/urban_prefab_package.gd`). Do not add new giant `MapDefinition` dictionary factories. Existing ones get only narrow fixes.
- Register every blueprint explicitly in `scripts/map/map_blueprint_registry.gd` with its required gameplay anchors. Do not discover blueprints by walking the filesystem.
- Preserve every stable ID (map, transition, spawn, anchor, patrol, prop, structure, landmark, prefab instance, prefab-local). Moving, reordering, regenerating, or chunking must not rename IDs.
- Use typed primitive placement for one-off geometry and allowlisted prefab-child overrides for exceptions. Do not use raw runtime dictionaries.
- Generated terrain, collision, navigation, marker, and view nodes are disposable output. Fix the blueprint or compiler, not the nodes.
- Preview, runtime, chunking, navigation, and 3D must consume the same compiled `MapDefinition` fingerprint. Never persist chunk coordinates, node paths, or instance IDs.
- `MapBlueprintDiagnostic.code` values are a stable API. `error` rejects output. Review `warning` diagnostics (e.g. `MAP_GEOMETRY_OVERLAP`) with an explicit decision. Do not hide them.
- Migrate one map at a time. A migration is not done until the deterministic, semantic snapshot, collision/navigation, scene, and visual parity checks pass. Do not regenerate parity fixtures just to get green.

**Pre-commit gate** for any blueprint, prefab, compiler/validator, transition registry, map audit, or `MAP_AUTHORING.md` change:

```bash
godot --headless --path . --script tools/validate_map_blueprints.gd
godot --headless --path . --script tools/run_godot_tests.gd
python3 tools/verify_map_audit.py
python3 tools/verify_map_activation.py
python3 tools/verify_map_conversion_plan.py
python3 tools/generate_active_docs_report.py --check
git diff --check
```

Pipeline stages: `tools/run_map_pipeline_ci.sh parser|compiler|audit|persistence|parity|routes|benchmark-smoke`. Review `build/benchmarks/large-map-ci-smoke.json` after benchmark runs.

## Scope

The game is a three-act faction RPG ([ADR 0008](./docs/adr/0008-three-act-campaign-and-faction-scope.md), amended by [ADR 0017](./docs/adr/0017-legacy-design-reintroduction.md)). Delivery order is strict: demo → vertical-slice MVP → Act 1 → Act 2 → Act 3. Legacy reintroduction is tracked in **P7** and [`docs/LEGACY_REINTRODUCTION.md`](./docs/LEGACY_REINTRODUCTION.md).

**In scope (gated by their tasks):** Kalev as fixed protagonist with the forge as hub. The commission → investigation → modification → consequence → reflection loop. One dense Lower Town district for the slice. Seven core characters plus faction casts. Authored offline dialogue. Eight factions with ledger standing and Living City Hope/Fear. Night missions. Hammer combat, forge techniques, dual-school magic, NATURAL aspects, Hingepuu psyche. All state is deterministic.

**Out of scope:** open world or seamless full Reval. Other cities. Runtime LLM, procedural quests, or free-text chat. Party control, army or fleet battles, survival sims. Tower capture, naval, and castle-building mini-games (need an ADR first). Activating a map before its task and gates pass. Shipping legacy pixel sprites or old HUD art. A universal good/evil morality score.

**Rules:**

- Do not implement ideas from legacy root or `scenes/` markdown unless README / ADR 0017 reconciles them and they have a task.
- Named historical claims need confidence labels in `docs/CANON.md`.
- Do not add major frameworks, event buses, or giant scene edits without a task that names the allowed files and verification.
- **Scope change** (new major system, mechanic, area, or pillar) needs all three: (1) removal of equivalent-cost scope, named explicitly; (2) the next numbered ADR in `docs/adr/` (Status / Context / Decision / Alternatives / Consequences); (3) a task with allowed files, dependencies, and verification. The ADR must be merged or human-approved before coding.
- **Asset freeze (P0-040):** do not add or replace legacy isometric tiles/props/characters, pixel-frame animation assets, or superseded HUD/NATURAL/element art. New production art needs a task naming the exact files. Fixes to shipped assets need the same.

## Task contract

Every delegated task must be independently verifiable ("improve combat" is invalid). Each task states: player-facing goal, allowed files, dependencies (task IDs and content IDs), constraints and non-goals, deliverable, exact verification (command, test, or screenshot), and doc updates.

`TODO.md` format: `- [ ] ID | deps: ID,ID or none | deliverable: ... | verify: ...`. Prefer tasks whose dependencies are done.

## Definition of done

- Player-visible behavior satisfies the task's `verify` line
- Tests or validators cover state transitions and failure modes
- Keyboard/mouse and gamepad paths are checked where input applies
- Save/load is verified when persistent state is touched
- Active docs and stable IDs are updated in the same change
- New assets have source, rights, and approval rows in `assets/SOURCES.csv`
- Visual changes include screenshots or captured states
- No unrelated systems or speculative abstractions were added
- A second reviewer (human or agent) confirms correctness, simplicity, and scope
