# Runtime Architecture and File Ownership

Status: active baseline, audited 2026-07-21 for P0-065; large-runtime inventory refreshed 2026-08-19 for P0-184.

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
- `WorldMapOverlay` preserves the map facade and emits `travel_requested`; its `WorldMapLocalView`, `WorldMapFastTravelView`, and `WorldMapGlobalView` children own mode-specific rendering/focus (local position, Reval district graph, Estonia distant roads), while `WorldMapController` executes travel through `DoorNavigator`. `GlobalMapCatalog` keeps distant placeholders off the district graph.
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

Inventory date: **2026-09-02** (P0-185 refresh). Counts use `wc -l` on tracked `scripts/**/*.gd` and exclude `tests/`, `tools/`, `addons/`, `archive/`, `quarantine/`, `generated/`, and `scenes/`.

| Band | Count | How to treat it |
| --- | ---: | --- |
| >= 800 lines | 7 | Must have an explicit keep/extract decision (table below). Primary EE-agent pain. |
| 600-799 lines | 16 | Audit + prefer extraction only when responsibilities already mix. |
| 400-599 lines | 40 | Audit trigger only; do not split by line count alone. |
| Total >= 400 | 63 | Current tracked runtime inventory; line count alone is not an extraction mandate. |

Soft readability target for new or extracted runtime helpers: **under 600 lines**, ideally under 400, unless the file is a pure data catalog or one grammar/facade. EE-agent split plan with ordered steps: [`docs/reports/agent_file_readability_split_plan_2026-08-13.md`](./reports/agent_file_readability_split_plan_2026-08-13.md). Justified extractions for the 800+ band are **P0-185**.

### Files over 800 lines (required decisions)

| File | Lines | Decision and regression gate |
| --- | ---: | --- |
| `scripts/map/view3d/map_view_tree_meshes.gd` | 1143 | **Extract (P0-185).** Split species profile tables from procedural wood/canopy/fruit mesh emitters behind the existing `wood_mesh` / `canopy_mesh` / `fruit_mesh` facade. Protect with `test_map_view_3d_mesh`, `test_map_view_tree_species`, foliage filters, and outdoor captures. |
| `scripts/map/view3d/sky_weather_3d.gd` | 1049 | **Keep.** This is the cohesive sky/weather presentation owner after the `SkyWeatherResources` extraction; do not split by LOC until a separate weather concern changes independently. Protect with `test_sky_weather_3d`, `test_sky_weather_state`, `test_r713_sky_weather_continuity`, lighting, and boat-float filters. |
| `scripts/map/view3d/map_view_mesh_builder_prop_models.gd` | 1018 | **Extract (P0-185).** Keep the `build_prop` facade; peel smithy-kit builders and outdoor/boat/fauna branches into typed helpers. Protect with `test_map_view_3d_mesh`, `test_forge_prop_meshes`, `test_boat_float_3d`, and authored prop/fauna filters. |
| `scripts/state/game_state.gd` | 906 | **Keep.** Preserve the canonical campaign-state owner and public persistence API; extract only an independently changing state concern behind a typed boundary and focused tests, never a second state store. Protect with `test_game_state`, session-state replacement, save-envelope, and vertical-slice save-matrix suites. |
| `scripts/map/view3d/map_view_runtime.gd` | 883 | **Extract (P0-185).** Actors and camera are already separate; next peel ambient installers (birds/fauna/insects/crowd/music) and/or time-flow controls behind the same `MapViewRuntime` facade. Protect with `test_map_view_3d_runtime`, runtime-camera, click, crowd, fauna, and session-state replacement filters. |
| `scripts/map/view3d/map_view_3d.gd` | 878 | **Keep.** Retain this as the integration owner; extract lighting or streaming only when that axis changes independently behind a stable facade. Protect with `test_map_view_3d_core`, `test_map_view_3d_lighting`, camera, object-streaming, and capture filters. |
| `scripts/map/view3d/map_view_materials.gd` | 822 | **Keep.** Retain the material-resolution facade over focused patterns/shaders modules; do not split the cohesive resolver for LOC alone. Protect with `test_map_view_material_resolution`, `test_map_view_3d_lighting`, decal, water, and terrain-material filters. |

### 600-799 line band (keep unless a second reason appears)

| File (lines) | Decision and regression gate |
| --- | --- |
| `scripts/map/view3d/map_view_material_shaders.gd` (791) | **Extract or relocate (P0-185, partial).** Keep the shader cache facade and move remaining large inline shader sources only when each resource has a focused owner. Gate: `test_map_view_decals`, `test_map_view_material_resolution`, `test_map_view_3d_lighting`, water/terrain mesh filters. |
| `scripts/map/view3d/map_view_mesh_builder_scatter.gd` (741) | **Keep** species-batched scatter catalog until a second caller needs pure tables. Gate: mesh/core outdoor tests. |
| `scripts/map/view3d/map_view_material_patterns.gd` (730) | **Keep** deterministic surface-pattern generator beside the materials facade. Gate: `test_map_view_material_resolution`, building-surface-weathering, and terrain-material filters. |
| `scripts/map/view3d/map_view_bird_meshes.gd` (712) | **Keep** mesh catalog beside bird species data. Gate: `test_map_view_bird_meshes`, bird species, and bird-flight filters. |
| `scripts/map/rrmap/map_rrmap_parser_statements.gd` (703) | **Keep** one grammar dispatcher. Extract a command family only when it gains independent state. Gate: `test_map_rrmap_parser`, parser CI, canonical round-trip. |
| `scripts/map/view3d/map_view_mesh_builder_building_houses.gd` (701) | **Keep** house visual catalog. Gate: `test_map_view_3d_mesh`, burgher-house typology/tier, fortification, and capture filters. |
| `scripts/state/game_state_persistence.gd` (696) | **Keep** persistence-shape adapter beside `GameState`; split only if serialization and migration acquire independent owners without changing the envelope contract. Gate: `test_save_service`, `test_save_envelope`, and vertical-slice save-matrix suites. |
| `scripts/map/view3d/map_view_mammal_meshes.gd` (697) | **Keep** mesh catalog beside mammal species data. Gate: mammal mesh/species and fauna filters. |
| `scripts/map/map_types.gd` (691) | **Keep** shared typed vocabulary; do not split for LOC. Gate: map compiler, definition, and rrmap suites. |
| `scripts/map/view3d/map_view_mesh_builder_primitives.gd` (685) | **Keep** shared geometry and cache owner. Gate: mesh/core reuse assertions. |
| `scripts/map/view3d/map_view_runtime_camera.gd` (678) | **Keep** camera owner beside the runtime facade. Gate: `test_map_view_3d_runtime`, `test_map_view_runtime_camera`, and camera/click filters. |
| `scripts/map/view3d/map_view_mesh_builder_terrain.gd` (658) | **Target later:** pure height-field owner when terrain work resumes. Gate: core, riparian, terrain movement, and parity suites. |
| `scripts/inventory/equipment_silhouette.gd` (662) | **Keep** until a second silhouette consumer appears. Gate: inventory, equipment, and character-rig suites. |
| `scripts/map/view3d/map_view_mesh_builder_landmarks.gd` (653) | **Keep** landmark catalog. Gate: direction-sign, fortification, core, and landmark capture filters. |
| `scripts/map/map_definition.gd` (633) | **Keep** runtime contract and validation owner. Gate: definition contract, parity, audit, and route suites. |
| `scripts/map/view3d/map_view_foliage_meshes.gd` (604) | **Keep** beside tree meshes until foliage gains a second owner. Gate: mesh, tree-species, and outdoor suites. |

### 400-599 line band (audit list only)

These remain over the audit trigger but are not scheduled rewrites: `quick_access_menu.gd` (425), `minimap_hud.gd` (486), `game_settings_overlay.gd` (431), `input_binding_settings.gd` (443), `smithy_routine_controller.gd` (512), `world_item_controller.gd` (445), `state_rule_evaluator.gd` (500), `bitter_brew_night_consequence.gd` (433), `dialogue_ui.gd` (426), `dialogue_runner.gd` (438), `faction_heraldry.gd` (505), `map_prop_renderer_industrial.gd` (528), `map_blueprint_compiler_expand.gd` (571), `map_blueprint_compiler.gd` (472), `map_prop_renderer_life.gd` (467), `map_blueprint.gd` (565), `map_composition_audit.gd` (573), `map_view_mesh_builder_building_fortification.gd` (528), `map_view_plant_species.gd` (460), `map_view_bird_species.gd` (577), `map_view_penned_fauna.gd` (433), `map_view_merchant_boat_builder.gd` (406), `map_view_mammal_species.gd` (564), `map_view_mesh_builder_house_roof_dressing.gd` (573), `map_view_mesh_builder_config.gd` (418), `map_view_monastic_models.gd` (532), `estonia_star_catalog_ra_270_360.gd` (408), `map_view_mesh_builder_surroundings.gd` (469), `estonia_star_catalog_ra_090_180.gd` (409), `map_view_bird_flight.gd` (465), `estonia_star_catalog_ra_000_090.gd` (404), `estonia_star_catalog_ra_180_270.gd` (430), `map_view_mesh_builder_buildings.gd` (566), `map_view_mesh_builder_district_life_props.gd` (499), `map_view_bush_species.gd` (504), `map_view_plant_meshes.gd` (453), `map_rrmap_parser_tokens.gd` (419), `forge_prologue_controller.gd` (471), `act1_aftermath_model.gd` (409), `inventory_overlay.gd` (481). Star catalog shards are already the preferred data-split pattern; keep them.

Non-`scripts/` files over 400 lines (scenes/tests/debug) are outside this runtime audit. Treat `scenes/comparison_room/comparison_room.gd` and debug showcases as disposable verification hosts, not production split targets.

### Completed extractions (still valid)

- P1-034: `WorldMapOverlay` facade with local/fast-travel child views.
- P0-079: `SkyWeatherResources` beside `SkyWeather3D`.
- Runtime actors: `MapViewRuntimeActors` beside `MapViewRuntime` / `MapViewRuntimeCamera`.
- P0-185 (partial): `MapViewBirdSpecies` and `MapViewMammalSpecies` profile tables moved into per-group shard modules; facades now 577 and 564 lines. Gate: `test_map_view_bird_species`, `test_map_view_mammal_species`, bird mesh/audio/flight, urban/penned fauna filters.
- P0-185 (partial): `map_view_wear_decal.gdshader` extracted from `MapViewMaterialShaders`; cache API gained `shader_resource()`. Gate: `test_map_view_decals`.
- P0-185 (partial): `map_view_puddle.gdshader` and `map_view_cloth.gdshader` relocated; the shader facade remains in the 600-799 audit band. Gate: `test_map_view_3d_core` puddle optics, `test_boat_float_3d`, `test_faction_heraldry`, `test_merchant_boat_model`.
- P0-185 (partial): `map_view_hanging_banner_cloth.gdshader` relocated; the shader facade remains in the 600-799 audit band. Gate: `test_faction_heraldry`, `test_map_view_material_resolution`.

### Scheduled follow-up

**P0-185** performs justified extractions only for the four current extraction targets in the 800+ table (`map_view_tree_meshes`, `map_view_mesh_builder_prop_models`, `map_view_runtime`, and any independently justified concern in `map_view_materials`/`game_state` after review). `sky_weather_3d` and `map_view_3d` remain cohesive integration owners; the bird and mammal species catalog shards are closed. Do not open broad LOC-driven rewrites of the 400-799 bands. Documentation/agent readability slim-downs for `docs/MAP_AUTHORING.md`, `docs/ROADMAP.md`, and offline `tools/` generators are tracked beside storage work in [`docs/STORAGE_SIZE_BACKLOG.md`](./STORAGE_SIZE_BACKLOG.md) and the 2026-08-13 readability report; they are not runtime architecture extractions.

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
