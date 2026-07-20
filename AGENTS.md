# AGENTS.md

Operational guide for AI agents and contributors working on **Reval Rebel**. Product vision, story, and scope live in [`README.md`](./README.md). Executable work lives in [`TODO.md`](./TODO.md). Until the planned `docs/` tree exists, this README and `AGENTS.md` override conflicting legacy documents.

## Repository map

| Path | Role | Notes |
|------|------|-------|
| `project.godot` | Godot project entry | Godot **4.7**, GL Compatibility renderer, main scene `res://scenes/menu/main_menu.tscn` |
| `export_presets.cfg` | Desktop export metadata | One macOS preset named `rr` targeting `./rr.dmg` |
| `scripts/` | Runtime GDScript | Player, NPC, doors, level base; autoload `DoorNavigator` in `scripts/global/` |
| `docs/MAP_AUTHORING.md` | Mandatory map-authoring contract | Blueprint primitives, stable IDs, deterministic compilation, parity checks, and migration policy |
| `scenes/` | Godot scenes and location design notes | 37 `.tscn` files; large markdown index under district folders |
| `assets/` | Sprites, tiles, UI, props | Prototype art plus `SOURCES.csv` provenance manifest |
| `characters/` | Character portraits and design prose | Mostly reference and archive material |
| `music/` | MP3 soundtrack library | Far larger than the vertical-slice budget |
| `sounds/` | Short SFX | Door and footstep samples |
| `story/`, `history/` | Narrative and research markdown | Mixed canon status; reconcile before implementing |
| `img/` | README and marketing images | Not runtime gameplay assets |
| `bin/` | Build artifact storage | Contains `rr.zip`; not a documented toolchain |
| Root legacy docs | `GAME-PILLARS.md`, `GAMEPLAY.md`, `QUESTS.md`, etc. | Reference only unless reconciled in README and added to `TODO.md` |

### Planned but not present yet

These paths are named in [`README.md`](./README.md) but do not exist in the repository yet:

- `docs/CANON.md`, `docs/ART_BIBLE.md`, `docs/WRITING_GUIDE.md`, `docs/ARCHITECTURE.md`, `docs/DECISIONS/` - see **P0-008**, **P0-040**, **P0-003** through **P0-005**
- `content/` - validated JSON for dialogue, quests, characters, items - see **P1-003**

### Current runtime surface (evidence-based)

- **Autoload:** `DoorNavigator` (`scripts/global/doorNavigator.gd`) - scene cache and transitions via `content/transitions/active_destinations.json` (stable scene/spawn ids), not hard-coded `scene_paths`
- **Main scene:** `scenes/menu/main_menu.tscn`
- **Playable demo path:** main menu → Lower Town (`reval_east`) → forge; Mart conversation and anvil spearhead pickup (D-003) work on that loop
- **Implemented today:** movement, manifest transitions, Interactable focus/prompt, session `GameState`, inventory/journal overlays, quick-access menu, district/world map overlay with click-to-travel (P1-031 / P1-031a, `M` / Districts), phase director hooks, content validation, map pipeline, save service APIs with tests, packaged macOS demo export with D-004 / D-004a proof
- **Open after packaging:** optional D-004b human video capture and D-004c in-binary packaged walkthrough; vertical-slice combat foundation through P1-026b is in place, night host P2-009 still blocked on forge/investigation deps

### Coding conventions observed in the repository

- GDScript with `class_name` where used (`Player` in `scripts/player.gd`)
- Scene resources use Godot 4 `uid://` references
- Godot import sidecars (`*.import`) are tracked; local editor cache `.godot/` is gitignored
- New production work should use **typed GDScript**, small reusable scenes, and composition as described in README; do not hand-edit giant city `.tscn` files unless the task includes visual verification
- Stable content IDs should follow forms such as `quest.bitter_brew`, `char.aita`, `flag.aita_detained` once `content/` exists
- Map work must follow [`docs/MAP_AUTHORING.md`](./docs/MAP_AUTHORING.md) and [ADR 0009](./docs/adr/0009-map-blueprint-authoring-architecture.md); generated scene nodes are not authored map content
- Task tracking format in `TODO.md`: `ID | deps | deliverable | verify`

## Setup

### Prerequisites

| Requirement | Status |
|-------------|--------|
| Git | Required to clone the repository |
| Godot 4.x editor matching project features | Pinned to **4.7** in [`.godot-version`](./.godot-version) and `project.godot` `config/features` |
| Pinned install instructions and CI alignment | [`docs/SETUP.md`](./docs/SETUP.md) (version pin and editor install; headless commands remain **P0-016**) |

### Clone

```bash
git clone <repository-url> rebel-reval
cd rebel-reval
```

### Install Godot

Pinned version: **4.7** ([`.godot-version`](./.godot-version), confirmed by `project.godot` `config/features`).

Follow [`docs/SETUP.md`](./docs/SETUP.md) for platform install steps, version verification, and opening `project.godot` in the editor. CI does not override this pin; [`.github/workflows/ci.yml`](./.github/workflows/ci.yml) checks `.godot-version` and `project.godot` before installing Godot 4.7.1 for automation.

## Import

Godot generates import metadata for binary assets. The repository tracks `*.import` sidecars for images, audio, and other resources.

| Action | Command or procedure | Status |
|--------|----------------------|--------|
| Import via editor | Open `project.godot` in Godot 4.7; the editor imports resources on load | Supported (manual) |
| Headless import on clean clone | Documented copy-paste shell command | **Supported** - see [`docs/SETUP.md`](./docs/SETUP.md) and [`docs/reports/startup_baseline.md`](./docs/reports/startup_baseline.md) |
| Import cache policy | Documented `.godot/` regeneration rules | **Not yet available** - dependency **P0-023** |
| Large binary sources | Follow [`docs/ASSET_STORAGE_POLICY.md`](./docs/ASSET_STORAGE_POLICY.md) | **Supported** - **P0-025** |

## Startup

| Action | Command or procedure | Status |
|--------|----------------------|--------|
| Run from editor | Open project in Godot, press **F5** or use **Project -> Run** | Supported (manual); starts `scenes/menu/main_menu.tscn` |
| Headless parser or startup check | Documented shell command that reaches a playable room without errors | **Supported** with workaround - `--check-only` hangs (`DEF-001`); use playable-room smoke in [`docs/SETUP.md`](./docs/SETUP.md) |
| Known-defect reproduction list | `docs/` or report with repro steps | **Supported** - [`docs/reports/known_runtime_defects.md`](./docs/reports/known_runtime_defects.md) (P0-019; critical/high defects with repro steps) |

Expected manual path today: main menu → Lower Town → forge using `DoorNavigator` manifest transitions. D-003 demo interaction (Mart talk + spearhead pickup into the bag) works on that path. Do not assume full combat, night consequence, or faction-ledger loops are complete.

## Tests

| Action | Status | TODO dependency |
|--------|--------|-----------------|
| Unit or integration test command | `godot --headless --script tools/run_godot_tests.gd` discovers `tests/godot/test_*.gd`, reports failures, and exits 0/1 | **P1-002** (minimal harness) |
| Scene transition automated test | **Supported at API level** - `tests/godot/test_transition_manifest.gd`; full scene transition tests remain future work | **P0-022**, **P1-002** |
| Combat or input state-machine tests | **Supported** - `tests/godot/test_player_action_state_machine.gd`, `tests/godot/test_combat_vitals.gd`, `tests/godot/test_forge_technique_iron.gd`, `tests/godot/test_combat_room.gd` | **P1-024** (integrated room) |
| Save round-trip and validation tests | `godot --headless --script tools/run_godot_tests.gd` (`tests/godot/test_save_service.gd`, `tests/godot/test_save_envelope.gd`) | **P1-008** |

Decision: P1-002 uses a small repository-owned headless GDScript harness instead of adding GUT or another addon. This keeps CI dependency-free while the project only needs discoverable unit/integration tests for early runtime foundations. Add new test scripts under `tests/godot/` with filenames `test_*.gd` and zero-argument methods named `test_*`. Shared assertions live in `tests/godot/test_case.gd`.

## Validation

| Action | Status | TODO dependency |
|--------|--------|-----------------|
| JSON schema validation for `content/` | `python3 tools/validate_content_examples.py` | **P1-003** |
| Python content validator (schemas, references, reachability, IDs, conditions, assets) | `python3 tools/validate_content.py content/examples/valid content/examples/support`; tests: `python3 -m unittest tests.python.test_validate_content -v` | **P1-004** |
| Active Markdown link and canon consistency report | `python3 tools/generate_active_docs_report.py --check` | **P0-031** |
| Speculative scene and NPC markdown archive headers | `python3 tools/archive_speculative_docs.py --dry-run` (no output when complete) | **P0-032** |
| Asset provenance manifest schema and coverage | `python3 tools/validate_asset_sources.py` | **P0-028** |
| Asset lint (dimensions, pivots, manifest rows) | **Not yet available** | **P1-029** |

Content schemas and the Python validator are now available. Add runtime JSON under `content/` only when it passes `tools/validate_content.py` as part of a complete corpus.

### Mandatory map-authoring workflow

Before creating, changing, reviewing, or migrating map content, agents **must read** [`docs/MAP_AUTHORING.md`](./docs/MAP_AUTHORING.md) and follow [ADR 0009](./docs/adr/0009-map-blueprint-authoring-architecture.md).

- Prefer `MapBlueprint` primitives and reviewed prefabs for new or migrated content. Until the compiler is implemented, do not invent a parallel source format or use the target API as if it already exists.
- Do not add direct giant `MapDefinition` dictionary factories. Existing direct factories are migration inputs and may receive narrow fixes only when the task requires them.
- Preserve map, transition, spawn, anchor, patrol, prop, structure, landmark, prefab-instance, and prefab-local stable IDs. Moving or reordering content, changing generated nodes, and runtime chunk assignment must not rename IDs.
- Use explicit typed primitive placement for one-off geometry and allowlisted prefab-child overrides for exceptions. Do not add raw runtime dictionaries as an escape hatch.
- Treat generated terrain, geometry, collision, navigation, marker, and view nodes as disposable output. Fix their blueprint/compiler input rather than hand-editing generated scene nodes.
- Keep large-map chunking in a separate runtime layer that consumes compiled `MapDefinition` data and preserves authored IDs.
- Run the validation and parity checks documented in `docs/MAP_AUTHORING.md`. Current map changes require the Godot suite plus map audit, activation, conversion-plan, and active-doc checks. A migration is incomplete until the compiler-specific deterministic, semantic snapshot, collision/navigation, scene, and visual parity checks exist and pass.

## Export

`export_presets.cfg` defines one runnable preset:

| Field | Value |
|-------|-------|
| Preset name | `rr` |
| Platform | macOS |
| Output | `./rr.dmg` |
| Architecture | universal |

| Action | Status | TODO dependency |
|--------|--------|-----------------|
| Documented headless export command | `mkdir -p build && godot --headless --export-release "rr" ./build/rr.dmg` | **P0-016** |
| CI export smoke test | `.github/workflows/ci.yml` macOS `desktop-export-smoke` job checks `build/rr.dmg` exists and is non-empty | **P1-001** |
| Codesigning / notarization procedure | Not configured in preset | Out of scope until export baseline lands |

P1-001 adds CI coverage for export smoke only. Full install, start, save, load, exit support remains **P3-012**.

## Scope constraints

Agents must treat [`README.md`](./README.md) as the product source of truth.

The product is a three-act faction RPG per [ADR 0008](./docs/adr/0008-three-act-campaign-and-faction-scope.md); delivery order is strict: demo → vertical-slice MVP → Act 1 → Act 2 → Act 3.

### In scope (act-gated per TODO.md tracks)

- Kalev as fixed protagonist; forge as hub
- Commission, investigation, modification, consequence, reflection loop
- One dense Lower Town district for the slice; further districts and world locations activate only through their P4+/P5+/P6 tasks and the parity/activation gates
- Seven core characters in slice scope, plus faction casts in act scope; authored offline dialogue
- Eight active factions with ledger-based standing (P4-016+); night mission templates (P5-004+)
- Small hammer combat and limited forge techniques
- Deterministic state; no runtime LLM

### Explicitly out of scope

- Open world or seamless full Reval; playable campaigns in other cities
- Runtime LLM, procedural quests, or free-text NPC chat
- Party control, army/fleet battle simulation, tower-capture loops, survival sims
- Activating any map before its TODO.md task and gates pass, regardless of ADR 0008
- Legacy systems called out in README: 21 elements, Living City meters and NPC-allegiance arithmetic, NATURAL aspects HUD, combinatorial magic, temperature or rhythm forging minigames

### Legacy and documentation rules

- Do not implement concepts from root or `scenes/` legacy markdown unless reconciled with README and added as a strict `TODO.md` entry
- Named historical claims require confidence labels once `docs/CANON.md` exists (**P0-008**)
- Do not add new major frameworks, event buses, or giant scene edits without a task that names allowed files and verification

### Scope-change rule

A new major system, mechanic, playable area, or content pillar may enter production only when all of the following hold:

1. **Equivalent scope removal** - an item from README "Explicitly excluded from the first campaign" or an approved slice task of comparable production cost is removed or deferred; the removed scope must be named in the approval artifact.
2. **Written approval artifact** - add a decision record before implementation begins. File it as the next numbered ADR in [`docs/adr/`](./docs/adr/) using the Status / Context / Decision / Alternatives / Consequences format (see ADR 0001). After **P0-005** lands `docs/DECISIONS/`, file new scope decisions there as `NNNN-short-slug.md` instead.
3. **TODO entry** - add or update a strict `TODO.md` entry with allowed files, dependencies, and verification before coding starts.

Agents must not implement scope expansions without the approval artifact merged or explicitly accepted by a human maintainer.

### Asset pipeline freeze

Until **P0-040** delivers `docs/ART_BIBLE.md` and the approved visual-style decision, **do not add or replace runtime assets** in the blocked classes below. Bug fixes to existing shipped assets are allowed only when a `TODO.md` task names the exact files.

Blocked asset classes (linked to **P0-040**):

- **Current isometric assets** - tiles, props, and characters authored for the legacy isometric projection or scale
- **Pixel-frame animation pipeline assets** - sprite sheets and animations produced for the superseded frame-by-frame pixel pipeline
- **Superseded HUD and system assets** - UI for NATURAL aspects, 21 elements, ruler/rebel balance, and other legacy HUD called out in README scope exclusions

New production art must wait for the art-bible baseline from **P0-040** unless a `TODO.md` task explicitly names allowed files and verification.

## Task contract

Every delegated task must be independently verifiable. Vague tasks such as "improve combat" or "make the city alive" are invalid.

Each task states:

1. **Player-facing goal** - what the player can do when done
2. **Allowed files** - exact paths that may change
3. **Dependencies** - `TODO.md` IDs and stable content IDs affected
4. **Constraints and non-goals** - what must not change
5. **Deliverable** - concrete artifact or behavior
6. **Verification** - exact command, test, or observable result; for visual work, screenshot or expected scene state
7. **Documentation updates** - canon, localization, `assets/SOURCES.csv`, or docs touched

`TODO.md` entry format:

```text
- [ ] ID | deps: ID,ID or none | deliverable: ... | verify: ...
```

When picking work, prefer tasks whose dependencies are already complete. Update stable IDs and active docs in the same change when behavior or canon changes.

## Definition of done

A production task is complete only when all of the following hold:

- Behavior is **player-visible** and satisfies the task's `verify` line in `TODO.md`
- **Automated tests or validators** cover state transitions and failure modes, once the relevant harness exists for that area
- A **clean clone** can exercise the behavior using documented commands, once **P0-015** through **P0-017** land
- **Keyboard/mouse and gamepad** paths are checked where the feature accepts input
- **Save/load** around the behavior is verified when the feature touches persistent state
- **Active documentation and stable IDs** are updated
- **New assets** include source, rights, and approval metadata in `assets/SOURCES.csv` once **P0-028** exists
- **Visual changes** include screenshots or captured states
- **No unrelated system or speculative abstraction** was added
- A **second reviewer** (human or agent) confirms correctness, simplicity, and scope

If verification commands are still marked **not yet available** above, the task may still close when its `verify` clause does not depend on those commands, or when it explicitly delivers the command or doc that unblocks them (for example **P0-016**).

## Map blueprint pre-commit validation

Every `MapBlueprint` factory must be listed explicitly in `scripts/map/map_blueprint_registry.gd`; add mandatory gameplay anchors to that entry. Do not discover blueprints by walking the filesystem. Treat `MapBlueprintDiagnostic.code` as an API for editor and AI automation: preserve stable codes, use `error` for rejected output and `warning` for reviewable compiled output.

Before committing any blueprint, prefab, map compiler/validator, transition registry, map audit requirement, or `MAP_AUTHORING.md` change, run exactly:

```bash
godot --headless --path . --script tools/validate_map_blueprints.gd
godot --headless --path . --script tools/run_godot_tests.gd
python3 tools/verify_map_audit.py
python3 tools/verify_map_activation.py
python3 tools/verify_map_conversion_plan.py
python3 tools/generate_active_docs_report.py --check
git diff --check
```

The first command validates all registered blueprints and fails CI on error diagnostics. Warnings such as `MAP_GEOMETRY_OVERLAP` and `MAP_CHUNK_BOUNDARY_AMBIGUOUS` do not fail CI, but must be reviewed rather than hidden. See [`docs/MAP_AUTHORING.md`](./docs/MAP_AUTHORING.md) for the complete code table and semantic rules.

## Copy-paste AI map workflow

Do not bulk-migrate maps. Scope one map and preserve its stable IDs and parity fixture.

```bash
# 1. Inspect existing visual vocabulary and reusable compositions before editing.
sed -n '1,240p' docs/MAP_AUTHORING.md
sed -n '1,240p' scripts/map/prefabs/urban_prefab_package.gd
grep -R "define_style\|\.style(" scripts/map/definitions scripts/map/prefabs

# 2. Author one MapBlueprint factory or safe content/maps/<map>.rrmap source.
# Register its source/factory and required anchors in scripts/map/map_blueprint_registry.gd.

# 3. Validate parser, compiler, semantics, and complete registry headlessly.
tools/run_map_pipeline_ci.sh parser
tools/run_map_pipeline_ci.sh compiler
tools/run_map_pipeline_ci.sh audit

# 4. Open the small host scene in Godot 4.7.1. Rebuild MapBlueprintEditorPreview,
# enable stable-ID/anchor/navigation/chunk overlays, and review Preview Status.

# 5. Prove canonical output, map parity, required routes, and save compatibility.
tools/run_map_pipeline_ci.sh persistence
tools/run_map_pipeline_ci.sh parity
tools/run_map_pipeline_ci.sh routes

# 6. Review every generated diagnostic and the benchmark report. Warnings need an
# explicit map decision; do not hide them or regenerate parity just to get green.
tools/run_map_pipeline_ci.sh benchmark-smoke
cat build/benchmarks/large-map-ci-smoke.json
```

Preview, runtime bootstrap, chunk indexing/rendering, navigation, and 3D must receive the same compiled `MapDefinition` fingerprint. Never edit generated preview/runtime nodes as map content. Never serialize chunk coordinates, node paths, or instance IDs as persistent identity. Before switching a runtime adapter, add map-specific parity and route tests and inspect the full fixture diff. See [`docs/MAP_AUTHORING.md`](./docs/MAP_AUTHORING.md) for budgets, limitations, and guarded fixture regeneration.
