# Runtime Architecture and File Ownership

Status: active baseline, audited 2026-07-21 for P0-065.

This document defines the current Godot runtime boundaries, dependency direction, and file ownership for Reval Rebel. It describes the architecture that exists in the repository. It does not authorize a second framework, a new map representation, or a broad rewrite.

Product scope remains in `README.md`. Executable work remains in `TODO.md`. Map-specific authoring and runtime rules remain in `docs/MAP_AUTHORING.md`, ADR 0009, and ADR 0010.

## Architectural constraints

1. The orthogonal 2D logic plane is authoritative for movement, collision, navigation, interactions, transitions, and stable world state.
2. The 3D layer is a derived presentation. It reads logic positions through `MapViewBridge` and must not write 3D transforms back into gameplay state.
3. Authored map semantics flow from `.rrmap` or a compact `MapBlueprint` factory through `MapBlueprintCompiler` into `MapDefinition`. Generated scene nodes are disposable output, not map source.
4. `GameState` is the session and save-game domain state. Scene nodes may present or request mutations, but they must not create competing campaign-state stores.
5. JSON under `content/` is the authored narrative and gameplay record source. `ContentDB` is the runtime lookup index; it is not a second mutable state store.
6. Autoloads are process-lifetime integration owners. New feature logic should prefer typed models and scene-local composition over adding another global service.
7. File length alone is not a refactor reason. Extract only when a file owns multiple change axes, duplicates a second implementation, or cannot be changed safely behind its existing tests.

## Runtime composition

```text
project.godot
  -> process-lifetime autoloads
     -> SessionState
        -> GameState
        -> ContentDB
        -> SaveService
     -> PhaseDirector -> SessionState + MusicDirector
     -> DoorNavigator -> transition manifest + SceneTree
     -> UserSettings -> user settings store
     -> MusicDirector -> scene theme + day/night presentation
     -> DisplayWindow -> platform window

playable scene script
  -> map source (.rrmap or compact factory)
  -> MapBlueprint
  -> MapBlueprintCompiler
  -> immutable MapDefinition
  -> MapBuilder -> MapTerrainGrid
  -> MapSceneBootstrap
     -> MapAssembler -> authoritative 2D terrain/object residency
     -> navigation, collision, doors, anchors, HUD
  -> MapViewRuntime
     -> MapView3D -> derived geometry, materials, lighting, streaming
     -> MapViewBridge -> one-way logic-to-view actor synchronization

content/*.json
  -> offline Python validation
  -> ContentDB
  -> dialogue, quest, forge, phase, encounter, inventory consumers
  -> explicit GameState mutations through domain APIs
```

The scene script is the normal composition root for map-local nodes. `SessionState` is the composition root for session-long models. Neither role should be moved into generated map data.

## Autoload ownership

`project.godot` registers exactly six autoloads. Adding another requires a TODO contract that explains why scene-local ownership or an existing composition root is insufficient.

| Autoload | Owner and lifetime | Allowed dependencies | Boundary |
| --- | --- | --- | --- |
| `DisplayWindow` | Platform window sizing for the process | `DisplayServer`, root `Window` | Must not own gameplay or UI layout state. |
| `DoorNavigator` | Active destination manifest, pending stable spawn IDs, bounded packed-scene cache, scene changes | `content/transitions/active_destinations.json`, `SceneTree`, authored `Door` nodes | The manifest owns scene and spawn identity. Callers must not add parallel hard-coded scene path tables. |
| `MusicDirector` | Scene theme playback and global day/night audio response | Current scene, audio resources, read-only phase date lookup | Must not mutate `GameState`. Story phase remains owned by `GameState` and `PhaseDirector`. |
| `PhaseDirector` | Binds to `GameState.phase_changed`, resolves phase profiles, performs boundary autosave, applies global presentation | `SessionState`, `ContentDB`, `MusicDirector` | It coordinates a phase transition but does not store phase independently. |
| `SessionState` | Session composition root and replacement point for loaded/debug state | `GameState`, `ContentDB`, `SaveService`, debug-only helpers | It exposes the canonical instances. Feature-specific logic belongs in typed domain classes, not in this autoload. |
| `UserSettings` | Player preferences that live outside save slots | Dialogue settings model and user settings store | Must remain separate from campaign/save state. |

### Autoload replacement rule

`SessionState.load_game()` and debug presets replace the live `GameState` object through the single `SessionState.replace_state()` entry point. It installs the canonical reference, binds the replacement bag to `ContentDB`, and then emits one ordered `state_replaced(previous, current, reason)` notification. Long-lived consumers must disconnect from the previous state and bind to the supplied current state; `PhaseDirector` receives an explicit post-signal rebind as a startup-order safeguard before phase presentation is synchronized. Direct assignment to `SessionState.state` is test scaffolding only and must not be used by production replacement flows.

## State, persistence, and content

### State ownership

| Concern | Canonical owner | Persistence | Consumers |
| --- | --- | --- | --- |
| Campaign phase, facts, flags, relationships, pressures, quest/location states, forged records | `scripts/state/game_state.gd` | `GameState.save_payload()` through `SaveEnvelope` and `SaveService` | Quest, dialogue, phase, debug, journal systems |
| Inventory placement, capacity, and equipment | `InventoryBag` plus `GameState` equipment APIs | Nested in `GameState` | Player encumbrance, inventory UI, combat profile, 3D equipment view |
| Player resources stored with the campaign | `PlayerState` under `GameState` | Nested in `GameState` | Runtime player adapters |
| Stable map object state | `MapStableStateStore` under `GameState` | Nested in `GameState` | Chunk lifecycle and persistent map objects |
| Placed/taken world items | `GameState` world-item APIs | Nested in `GameState` | `WorldItemController`, inventory |
| User dialogue preferences | `UserSettings` | Separate user settings file | Dialogue UI |
| Pending scene spawn and packed-scene cache | `DoorNavigator` | Process-only | Map scenes and doors |
| Day/night presentation progress | `MusicDirector` and map view runtime presentation | Process/scene-only unless derived from an authored phase profile | HUD, lighting, audio |

Rules:

- Domain mutations go through `GameState`, `InventoryBag`, `MapStableStateStore`, or another typed model API.
- UI labels, selected controls, hover state, camera state, caches, and loaded chunk sets are presentation/runtime state and do not belong in saves.
- Save I/O belongs to `SaveService`; envelope migration and validation belong to `SaveEnvelope`; payload shape belongs to `GameState` and `game_state_persistence.gd`.
- A failed load must not partially replace the live state. A failed content reload must not publish a partial `ContentDB` index.

### Content boundary

`content/**/*.json` is validated offline by the Python validators under `tools/` and loaded at runtime by `ContentDB`. Runtime records are addressed by stable IDs such as `dialogue.*`, `quest.*`, `item.*`, and `encounter.*`.

`ContentDB` owns discovery, runtime shape checks, global ID uniqueness, typed lookups, and defensive copies. It does not own quest progress, inventory ownership, dialogue history, or phase. Those values belong to `GameState`.

Expected dependency direction:

```text
content JSON -> validators -> ContentDB -> domain runner/model -> GameState API
```

Disallowed direction:

```text
GameState -> scene node or UI tree
ContentDB -> GameState mutation
content record -> executable GDScript or runtime LLM call
```

## Map pipeline ownership

### Authoring and compilation

| Stage | Owner | Contract |
| --- | --- | --- |
| Serialized source | `content/maps/*.rrmap` | Strict rrmap v1 text with no executable code. |
| Parser facade | `MapRrmapParser` | Tokenizes and parses through focused helpers, returns diagnostics, then invokes the compiler. |
| Semantic authoring model | `MapBlueprint` and prefab packages | Compact typed primitives, stable IDs, cell-space geometry, source references, narrow overrides. |
| Deterministic expansion | `MapBlueprintCompiler` and its focused helpers | Validates, expands prefabs, canonicalizes records, and produces one `MapDefinition`. |
| Runtime contract | `MapDefinition` | Canonical map semantics consumed by every runtime, audit, parity, and activation system. |
| Terrain logic | `MapBuilder` and `MapTerrainGrid` | Authoritative terrain cells, movement costs, chunk coordinates, and fingerprints. |

`MapDefinition` is the compatibility seam. Authoring code may change only if compiler fixtures preserve the runtime contract. View, collision, navigation, and scene code must not reach backward into parser tokens or blueprint internals.

### Scene assembly and runtime

`MapSceneBootstrap` composes a compiled definition into a playable scene. It calls `MapAssembler` for 2D terrain and stable-ID object residency, adds navigation and physical world bounds, creates transition doors and anchors, and configures the minimap. Small playable scene scripts call this API and then place the player through `DoorNavigator`.

Chunking is a derived runtime concern. `MapChunkRuntimeIndex`, `MapObjectChunkStreamer`, and terrain chunk residency consume `MapDefinition` and preserve stable IDs. Chunk coordinates are never authored gameplay identity.

### Map invariants

- `.rrmap` or a compact blueprint factory is source. Generated node trees are not source.
- `MapDefinition` and `MapTerrainGrid` must remain unchanged while a view renders them.
- Stable map IDs, transition scene/spawn IDs, anchor IDs, and object IDs must survive refactors.
- Logic collision and navigation remain active even when the 2D drawing is hidden by `MapViewRuntime`.
- Map changes run the exact gates in `docs/MAP_AUTHORING.md` before commit.

## Logic and 3D view boundary

`MapView3D` is the derived visual scene for one `MapDefinition` and `MapTerrainGrid`. `MapViewMeshBuilder` is its stable geometry facade; focused builder modules own terrain, buildings, props, landmarks, surroundings, and interiors. `MapViewMaterials` is the stable material facade over focused shader and pattern modules.

`MapViewRuntime` is intentionally an integration adapter rather than a pure view model. It hides flat drawing without disabling 2D collision, installs `MapView3D`, mirrors logic actors and equipment, maps camera-relative input back to logic axes, and connects day/night presentation. Because this adapter touches both scene and presentation APIs, its behavior must remain covered by integration tests.

Allowed data flow:

```text
MapDefinition + MapTerrainGrid + Node2D actor positions
  -> MapViewBridge
  -> MapView3D geometry and Node3D actor rigs
```

Forbidden data flow:

```text
Node3D transform -> Player.global_position
visible mesh/camera state -> collision, navigation, quest, or save state
mesh builder -> MapDefinition mutation
```

`MapViewBridge.world_to_logic()` is allowed for projection math such as click targeting. The resulting command is still executed on the 2D logic plane.

## UI and interaction ownership

UI follows a controller/presentation split where one already exists:

- `InventoryController`, `JournalController`, and `WorldMapController` own overlay lifetime, visible entry points, and cross-system effects.
- `WorldMapOverlay` preserves the map facade and emits `travel_requested`; its `WorldMapLocalView` and `WorldMapFastTravelView` children own mode-specific rendering/focus, while `WorldMapController` executes travel through `DoorNavigator`.
- `DialogueRunner` owns dialogue progression and state effects. `DialogueUI` presents lines/choices and emits user intent through `DialogueUiPresenter`.
- `QuickAccessMenu` is the persistent discovery surface. It coordinates existing controllers and does not become a second inventory, journal, map, or combat model.
- `MinimapHud` derives its image and marker from `MapDefinition`, `MapTerrainGrid`, and player position. The full-screen local map reuses that data rather than rebuilding a competing map model.
- `InteractionController` selects focused `Interactable` nodes. World-item logic uses the same interaction contract and persists ownership through `GameState`.

Current exception: `InventoryOverlay` performs bag move and equip/unequip commands while rendering their result. This is accepted behavior, not the desired direction for additional overlays. A future extraction should route those commands through the existing inventory controller boundary, keeping `InventoryBag` and `GameState` as the only domain owners.

Every player-visible action must have a visible quick-access or contextual entry point as required by `TODO.md`. Hotkeys are input bindings, not architecture or discoverability boundaries.

## Directory and dependency ownership

| Area | Owns | May depend on | Must not own |
| --- | --- | --- | --- |
| `scripts/state/`, `scripts/session/`, `scripts/save/` | Domain state, session composition, serialization | Typed domain models and content IDs | Scene nodes, rendering, input polling |
| `scripts/content/`, `content/`, `schemas/` | Authored records, runtime lookup, validation contracts | Filesystem/JSON at load time | Mutable campaign progress |
| `scripts/map/rrmap/`, blueprint/compiler/prefab files | Map source parsing and deterministic semantic compilation | Map primitives and `MapDefinition` | SceneTree, rendering, chunk residency |
| `scripts/map/` logic/runtime assembly | Terrain grid, collision/navigation assembly, stable object residency | Compiled `MapDefinition` | Authoring token details, campaign narrative logic |
| `scripts/map/view3d/` | Derived geometry, materials, camera, view actor mirroring | Read-only map contracts and logic positions | Gameplay authority or save data |
| `scripts/combat/`, `scripts/forge/`, `scripts/dialogue/`, `scripts/quest/` | Feature rules and orchestration | `ContentDB` records and explicit `GameState` APIs | Independent global state stores |
| `scripts/ui/`, inventory/journal overlays | Presentation, focus, visible intent | Configured models/controllers and signals | Duplicate content, map, quest, or save models |
| `scenes/**` scripts | Scene-local composition and authored integration | Stable public APIs from the areas above | Reimplemented global services or giant map dictionaries |
| `tools/` and `tests/` | Validation, generation, fixtures, regression proof | Public contracts and explicit test seams | Runtime-only hidden state required for release behavior |

## Refactor thresholds and procedure

### Extract when

An extraction is justified when at least one condition is true:

1. A file owns both a domain mutation policy and an independently changing presentation/input implementation.
2. A second caller needs the same behavior and would otherwise copy private methods or data tables.
3. A file has multiple unrelated reasons to change and repeatedly creates merge conflicts or broad test failures.
4. Tests must construct large scene trees only to verify pure calculations that can be isolated behind the same public API.
5. A process-lifetime autoload is accumulating feature-specific rules that belong in a typed model.
6. A parser/compiler/view module starts depending backward across the map pipeline boundary.

A line count over 400 is an audit trigger, not an automatic extraction trigger.

### Do not extract when

- The file is a cohesive vocabulary, facade, contract validator, or focused geometry catalog.
- The proposed helper only renames private methods without establishing a clearer owner.
- The change creates a second state store, map model, UI framework, renderer, or service locator.
- Callers would need to choose between old and new implementations.
- Existing behavior cannot first be characterized by a focused test.

### Safe extraction sequence

1. Add or identify the focused behavior test listed in the audit below.
2. Keep the current public class, stable IDs, signals, serialized shape, and scene node names unless the task explicitly migrates them.
3. Move one responsibility into a typed helper or existing controller. Prefer a pure `RefCounted` model when SceneTree access is unnecessary.
4. Make the old facade delegate to the extracted owner in the same change.
5. Remove the old implementation after all callers use the facade. Do not leave parallel paths.
6. Run the focused tests, the full Godot suite, and any map/content/docs validators affected by the boundary.

## Large runtime file audit

The P0-065 TODO text expected 11 runtime scripts over 400 lines and referenced a 681-line building mesh builder plus a 565-line statement parser. The 2026-07-21 inventory finds 18 files over 400 lines after earlier focused splits. The current house builder is 527 lines and the rrmap statement parser is 569 lines. Counts exclude `tests/`, `tools/`, `addons/`, `archive/`, `quarantine/`, and generated directories.

| File (audited lines) | Current responsibility | Decision and regression gate |
| --- | --- | --- |
| `scenes/comparison_room/comparison_room.gd` (459) | Developer-only P0-033 greybox construction, controls, HUD, and headless self-check | Mixed by design but not release runtime. Retain as one disposable verification scene. If changed, run its headless self-check and `scenes/comparison_room/verify_variants.gd`; do not copy it into production scenes. |
| `scripts/dialogue/dialogue_ui.gd` (401) | Dialogue presentation facade and transient UI state | Cohesive facade already delegating build, theme, input, choice, and reveal work. Keep. Protect with `test_dialogue_ui`, `test_dialogue_overflow`, and `test_dialogue_settings`. |
| `scripts/inventory/inventory_overlay.gd` (476) | Bag/equipment presentation, keyboard focus, drag/drop command handling | Mixed presentation and domain command orchestration. Target extraction only when inventory work resumes: route move/equip intents through the existing controller boundary. Protect with `test_inventory_overlay_view`, `test_inventory_keyboard`, `test_inventory_bag`, and `test_inventory_equipment`. |
| `scripts/map/map_blueprint.gd` (404) | Compact map-authoring vocabulary and primitive collection | Cohesive typed authoring model. Keep as the stable DSL. Protect with `test_map_blueprint_compiler`, `test_map_blueprint_semantic_validation`, and `test_map_prefabs`. |
| `scripts/map/map_definition.gd` (440) | Runtime map contract, validation, bounds, and fingerprint inputs | Cohesive compatibility seam. Keep validation beside the contract until a separately versioned rule family exists. Protect with `test_map_definition_contract`, map parity, audit, and route gates. |
| `scripts/map/rrmap/map_rrmap_parser_statements.gd` (569) | rrmap v1 statement dispatch and command-specific parsing | Large but one grammar responsibility. Token/value parsing and top-level orchestration are already split. Do not split by arbitrary line count. If a new command family introduces independent state, extract that family behind the parser facade. Protect with `test_map_rrmap_parser`, parser CI, canonical round-trip, and migration tests. |
| `scripts/map/view3d/map_view_3d.gd` (558) | Derived view assembly, lighting/environment state, visual object streaming, fog, and camera creation | Integration-heavy view owner. Existing weather, mesh, and camera helpers already reduce it. Extract another owner only when lighting or streaming changes independently. Protect with `test_map_view_3d_core`, `test_map_view_3d_lighting`, `test_map_camera_modes`, and object-streaming tests. |
| `scripts/map/view3d/map_view_materials.gd` (509) | Stable material API, role mapping, UV density, and material cache | Cohesive facade over `MapViewMaterialPatterns` and `MapViewMaterialShaders`. Keep. Protect with `test_map_view_material_resolution` and 3D mesh/lighting tests. |
| `scripts/map/view3d/map_view_mesh_builder_building_houses.gd` (527) | House style selection, materials, structural dressing, chimneys, windows, and historic details | Focused house visual catalog. This is the remaining large portion of the former building builder, while `MapViewMeshBuilderBuildings` is now a small facade/orchestrator. Keep until one new house-detail family needs independent reuse. Protect with `test_map_view_3d_mesh`, `test_map_view_3d_fortification`, and map visual captures. |
| `scripts/map/view3d/map_view_mesh_builder_landmarks.gd` (465) | Gate arches, interior windows, transition doors, and marker geometry | Cohesive landmark visual catalog. Keep; extract a kind-specific builder only if its own vocabulary grows. Protect with `test_direction_sign_3d`, `test_map_view_3d_fortification`, and `test_map_view_3d_core`. |
| `scripts/map/view3d/map_view_mesh_builder_primitives.gd` (510) | Low-level deterministic mesh primitives and immutable mesh cache | Cohesive shared geometry utility. Keep cache and constructors together so all builders reuse identical resources. Protect with `test_map_view_3d_mesh`, `test_map_view_3d_core`, and procedural mesh reuse assertions. |
| `scripts/map/view3d/map_view_mesh_builder_surroundings.gd` (439) | Exterior aprons, vegetation, and adjoining-district previews | One derived surroundings responsibility with two strategies. Keep while both consume the same map-side contract. If neighbor previews gain lifecycle/state, extract them behind `build_surroundings`. Protect with prototype-map tests, `test_map_view_3d_core`, and outdoor captures. |
| `scripts/map/view3d/map_view_mesh_builder_terrain.gd` (561) | Deterministic height-field/cache plus terrain mesh emission and water integration | Mixed calculation and rendering. Target extraction when terrain work resumes: isolate a pure height-field owner while preserving the `MapViewMeshBuilder` facade. Protect with `test_map_view_3d_core`, `test_riparian_banks`, `test_map_terrain_movement`, and map parity gates. |
| `scripts/map/view3d/map_view_runtime.gd` (450) | 2D-to-3D installation, actor/equipment mirroring, camera-relative input, click setup, and day/night bridge | Mixed by its adapter role. The camera is already extracted. Next extraction, only under measured change pressure, is actor/equipment synchronization behind the existing runtime facade. Protect with `test_map_view_3d_runtime`, `test_map_camera_modes`, `test_map_click_input_controller`, and `test_character_rig`. |
| `scripts/player.gd` (447) | CharacterBody movement, navigation, combat adapter, resources, terrain/encumbrance speed, and animation-facing facade | Multiple responsibilities remain behind one scene API. Target extraction when player controls or combat next change: isolate locomotion/resource coordination without replacing `Player`, `PlayerActionStateMachine`, or `CombatVitals`. Protect with `test_player_action_state_machine`, `test_player_resources`, `test_map_terrain_movement`, `test_inventory_encumbrance`, and combat tests. |
| `scripts/ui/minimap_hud.gd` (426) | Local map image/marker, location/date HUD, and procedural ornament/celestial controls | Cohesive HUD assembly with nested draw-only controls. Keep until either visual control is reused independently. Protect with `test_minimap`, `test_world_map_overlay`, and `test_map_scene_bootstrap`. |
| `scripts/ui/world_map_overlay.gd` (230) | Public full-screen map facade, tabs/mode state, and validated travel intent | Extracted under P1-034: `WorldMapLocalView` owns local image/marker rendering and `WorldMapFastTravelView` owns graph drawing/focus. Keep the facade and stable node names; `WorldMapController` remains the only travel side-effect owner. Protect with all `test_world_map_overlay` cases and `test_quick_access_menu`. |
| `scripts/world/world_item_controller.gd` (439) | Default placement seeding, state-to-node synchronization, hover/cursor/input, pickup/drop transactions, interactables, and 3D item views | Mixed state adapter, interaction controller, and presentation. Existing overlay, label, and view binder helpers should remain the extension points. Extract only one axis at a time, starting with default-placement/content resolution when authored placements move to validated content. Protect with `test_world_items`, `test_map_click_input_controller`, `test_demo_walkthrough`, and save round-trip tests. |

### Scheduled follow-up

P1-034 completed the first extraction identified by this audit: local-map and fast-travel presentation now live in focused child views behind the preserved `WorldMapOverlay` facade, with travel side effects still owned by `WorldMapController`. Other candidates remain thresholds, not scheduled rewrites. They require a new or updated TODO contract before implementation.

## Verification baseline

Documentation changes:

```bash
python3 tools/generate_active_docs_report.py
python3 tools/generate_active_docs_report.py --check
```

Architecture-sensitive runtime changes:

```bash
godot --headless --path . --script tools/run_godot_tests.gd
python3 -m unittest discover -s tests/python
```

Map boundary changes also require every pre-commit command listed in `docs/MAP_AUTHORING.md`. Content boundary changes require the Python content validators and runtime `test_content_db` coverage. A narrower focused command may be used during iteration, but the affected subsystem's complete gate must pass before commit.
