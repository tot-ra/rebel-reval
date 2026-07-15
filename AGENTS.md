# AGENTS.md

Operational guide for AI agents and contributors working on **Reval Rebel**. Product vision, story, and scope live in [`README.md`](./README.md). Executable work lives in [`TODO.md`](./TODO.md). Until the planned `docs/` tree exists, this README and `AGENTS.md` override conflicting legacy documents.

## Repository map

| Path | Role | Notes |
|------|------|-------|
| `project.godot` | Godot project entry | Godot **4.4**, GL Compatibility renderer, main scene `res://scenes/menu/main_menu.tscn` |
| `export_presets.cfg` | Desktop export metadata | One macOS preset named `rr` targeting `./rr.dmg` |
| `scripts/` | Runtime GDScript | Player, NPC, doors, level base; autoload `DoorNavigator` in `scripts/global/` |
| `scenes/` | Godot scenes and location design notes | 37 `.tscn` files; large markdown index under district folders |
| `assets/` | Sprites, tiles, UI, props | Prototype art; no `SOURCES.csv` yet |
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
- `assets/SOURCES.csv` - asset provenance manifest - see **P0-028**

### Current runtime surface (evidence-based)

- **Autoload:** `DoorNavigator` (`scripts/global/doorNavigator.gd`) - scene cache and transitions via hard-coded `scene_paths` and `Doors/door_<tag>` spawn tags
- **Main scene:** `scenes/menu/main_menu.tscn`
- **Playable prototype areas:** forge, `reval_east`, `reval_north`, `reval_center`, plus additional placeholder world and event scenes
- **Implemented today:** movement, scene transitions, simple NPC navigation, placeholder UI
- **Not implemented today:** dialogue, quests, combat, inventory, forging, phases, consequence state, save/load, content validation, automated import/test/export checks (see README "Current repository state")

### Coding conventions observed in the repository

- GDScript with `class_name` where used (`Player` in `scripts/player.gd`)
- Scene resources use Godot 4 `uid://` references
- Godot import sidecars (`*.import`) are tracked; local editor cache `.godot/` is gitignored
- New production work should use **typed GDScript**, small reusable scenes, and composition as described in README; do not hand-edit giant city `.tscn` files unless the task includes visual verification
- Stable content IDs should follow forms such as `quest.bitter_brew`, `char.aita`, `flag.aita_detained` once `content/` exists
- Task tracking format in `TODO.md`: `ID | deps | deliverable | verify`

## Setup

### Prerequisites

| Requirement | Status |
|-------------|--------|
| Git | Required to clone the repository |
| Godot 4.x editor matching project features | Pinned to **4.4** in [`.godot-version`](./.godot-version) and `project.godot` `config/features` |
| Pinned install instructions and CI alignment | [`docs/SETUP.md`](./docs/SETUP.md) (version pin and editor install; headless commands remain **P0-016**) |

### Clone

```bash
git clone <repository-url> rebel-reval
cd rebel-reval
```

### Install Godot

Pinned version: **4.4** ([`.godot-version`](./.godot-version), confirmed by `project.godot` `config/features`).

Follow [`docs/SETUP.md`](./docs/SETUP.md) for platform install steps, version verification, and opening `project.godot` in the editor. No CI workflow overrides this pin yet.

## Import

Godot generates import metadata for binary assets. The repository tracks `*.import` sidecars for images, audio, and other resources.

| Action | Command or procedure | Status |
|--------|----------------------|--------|
| Import via editor | Open `project.godot` in Godot 4.4; the editor imports resources on load | Supported (manual) |
| Headless import on clean clone | Documented copy-paste shell command | **Not yet available** - dependency **P0-016**, baseline **P0-017** |
| Import cache policy | Documented `.godot/` regeneration rules | **Not yet available** - dependency **P0-023** |
| Large binary sources | Follow [`docs/ASSET_STORAGE_POLICY.md`](./docs/ASSET_STORAGE_POLICY.md) | **Supported** - **P0-025** |

## Startup

| Action | Command or procedure | Status |
|--------|----------------------|--------|
| Run from editor | Open project in Godot, press **F5** or use **Project -> Run** | Supported (manual); starts `scenes/menu/main_menu.tscn` |
| Headless parser or startup check | Documented shell command that reaches a playable room without errors | **Not yet available** - dependency **P0-016**, baseline **P0-017** |
| Known-defect reproduction list | `docs/` or report with repro steps | **Not yet available** - dependency **P0-019** |

Expected manual path today: main menu -> game flow into city or forge scenes using existing `DoorNavigator` transitions. Do not assume dialogue, combat, or save systems work.

## Tests

| Action | Status | TODO dependency |
|--------|--------|-----------------|
| Unit or integration test command | **Not yet available** | **P1-002** (harness), **P1-001** (CI) |
| Scene transition automated test | **Not yet available** | **P0-022**, **P1-002** |
| Combat or input state-machine tests | **Not yet available** | **P1-023**, **P1-024** |
| Save round-trip tests | **Not yet available** | **P1-007**, **P1-008** |

No Godot test scenes, GUT configuration, or shell test runner exists in the repository today.

## Validation

| Action | Status | TODO dependency |
|--------|--------|-----------------|
| JSON schema validation for `content/` | **Not yet available** | **P1-003** |
| Python content validator (references, IDs, assets) | **Not yet available** | **P1-004** |
| Active Markdown link and canon consistency report | `python3 tools/generate_active_docs_report.py --check` | **P0-031** |
| Asset lint (dimensions, pivots, manifest rows) | **Not yet available** | **P1-029** |

Do not add runtime JSON under `content/` until schemas and validators from **P1-003** and **P1-004** exist.

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
| Documented headless export command | **Not yet available** | **P0-016** |
| CI export smoke test | **Not yet available** | **P1-001**, **P3-012** |
| Codesigning / notarization procedure | Not configured in preset | Out of scope until export baseline lands |

Do not assume `godot --export-release` works in CI until **P1-001** adds the pipeline. See `docs/SETUP.md` for the exact local invocation.

## Scope constraints

Agents must treat [`README.md`](./README.md) as the product source of truth.

### In scope for the first campaign and vertical slice

- Kalev as fixed protagonist; forge as hub
- One dense Lower Town district for the slice
- Commission, investigation, modification, consequence, reflection loop
- Seven core characters in slice scope; authored offline dialogue
- Small hammer combat and limited forge techniques
- Deterministic state; no runtime LLM

### Explicitly out of scope

- Open world or seamless full Reval
- Runtime LLM, procedural quests, or free-text NPC chat
- Party control, army battles, tower-capture loops, survival sims
- Playable maps outside the approved slice district
- Legacy systems called out in README: 21 elements, 15+ factions, NATURAL aspects HUD, temperature or rhythm forging minigames

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
le **P0-016**).
