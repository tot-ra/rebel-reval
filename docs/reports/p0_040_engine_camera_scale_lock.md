# P0-040 engine, camera, and world-scale technical lock

Recorded: 2026-08-17
Task: `R-567 / P0-040`

## Lock status

**Contract reconciled; final P0-040 freeze remains BLOCKED.** The implementation and approved ADRs provide one unambiguous engine, viewport, camera, projection, and world-scale contract. This report documents that contract without changing runtime settings, camera code, map data, or assets.

The remaining blockers are acceptance evidence and current camera integration evidence, not unresolved technical choices:

1. GPU texture-memory evidence is still missing. The P0-038 headless renderer reports zero texture/video memory and cannot establish GPU usage.
2. Minimum-supported-hardware frame-time evidence is still missing. The existing P0-038 measurement is a development-baseline M5 Pro run, not the declared minimum-hardware profile.
3. The focused `test_map_camera_modes.gd` integration suite is currently red in this checkout: 11 tests ran with 6 assertion failures covering building collision clearance, first-person eye height, third-person boom distance, and scroll-zoom return positions. A current checked rerun also records 2 shader diagnostics because pre-existing `# gdlint` comments are embedded in the GLSL source in `scripts/map/view3d/map_view_material_shaders.gd`; consequently, `test_map_view_runtime_camera.gd` did not complete its 1 test in this dirty checkout. Earlier baseline evidence recorded that separate suite as 1/1 before this diagnostic was surfaced. This report records the failure as a blocker and does not change camera or shader code.
4. Maintainer sign-off remains required by ADR 0013. This report does not make that approval decision.

## Authority and historical boundary

- [Godot project settings](../../project.godot) and [ART_BIBLE v2](../ART_BIBLE.md) define the current engine and presentation contract.
- [ADR 0007](../adr/0007-ai-generated-isometric-presentation.md) established the programmatic 3D view and its historical fixed orthographic dimetric camera.
- [ADR 0015](../adr/0015-default-third-person-camera.md) is the later accepted camera decision. It supersedes the fixed orthographic default, retains orthographic top-down as an alternate mode, and defines the three-mode gameplay cycle.
- `MapView3D` still constructs an orthographic camera because it is the pure view-layer owner and top-down baseline. [MapViewRuntimeCamera](../../scripts/map/view3d/map_view_runtime_camera.gd) applies the active gameplay mode after runtime installation. Therefore, the `MapView3D` orthographic construction values must not be read as the current exterior gameplay default.

## Technical lock matrix

| Lock field | Frozen value | Authority and acceptance state |
|---|---|---|
| Engine | Godot `4.7` | `project.godot` `config/features`; also recorded by `docs/ART_BIBLE.md`. Pass: source contract. |
| Renderer | `GL Compatibility` for desktop and mobile | `project.godot` `rendering/renderer/rendering_method = "gl_compatibility"` and `.mobile`. Pass: selected source value; GPU acceptance blocked by missing non-headless evidence. |
| Design/internal viewport | `1920 x 1080` design viewport; `window/stretch/mode = "viewport"` | `project.godot` `[display]` and `scripts/display/display_window.gd` `DESIGN_SIZE`. No separate lower internal-resolution target is declared. Pass: source contract. |
| Window sizing | Screen-relative window preserves the `16:9` design aspect ratio and scales the design viewport to the usable display area | `scripts/display/display_window.gd` `target_window_size_for_screen()`. Pass: source contract. |
| Logic authority | Flat orthogonal 2D logic plane remains authoritative for movement, collision, navigation, interactions, transitions, and fingerprints | `docs/ARCHITECTURE.md`, `docs/ART_BIBLE.md`, `scripts/map/view3d/map_view_bridge.gd`. Pass: architectural invariant. |
| Current exterior default projection | Perspective over-the-shoulder third person | Accepted ADR 0015; `MapViewRuntimeCamera.camera_mode` initializes to `THIRD_PERSON` unless the definition suppresses exterior surroundings. Pass: source contract. The focused camera-mode integration suite is currently blocked by the failures listed in Lock status. |
| Current exterior third-person camera | FOV `65°`; near `0.05`; default boom distance `6.0`; target height `1.15`; pitch `-12°`; pitch clamp `-55°..35°`; rig visible | `scripts/map/view3d/map_view_runtime_camera.gd` constants and `_follow_target()` / `_apply_camera_mode()`. Pass: source contract. |
| First-person alternate | Perspective; FOV `75°`; near `0.05`; eye height `1.65`; pitch `-10°`; pitch clamp `-80°..80°`; rig hidden | ADR 0015 and `MapViewRuntimeCamera`. Pass: source and focused camera-test contract. |
| Top-down alternate | Orthographic; initial gameplay size `33.75`; near `0.05`; authored pitch `-30°`; initial view yaw `45°`; rig visible; screen-relative movement and independent character facing | `CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE`, `MapView3D.CAMERA_PITCH_DEGREES`, `MapView3D.CAMERA_YAW_DEGREES`, `MapViewRuntimeCamera._apply_camera_mode()`, ADR 0015. Pass: source and focused camera-test contract. The current yaw may be rotated during play; the pitch remains authored. |
| Top-down zoom band | `10.125..50.625` orthographic size, calculated as `33.75 * 0.3..1.5` | `MapViewRuntimeCamera.ZOOM_MIN_FACTOR`, `ZOOM_MAX_FACTOR`, and derived size constants. Pass: source contract. |
| Orthographic construction baseline | `MapView3D` creates the view camera at pitch `-30°`, yaw `45°`, distance `90`, far plane `800`, with map-derived size and `CAMERA_MARGIN = 1.15`, `CAMERA_HEADROOM = 5.0` | `scripts/map/view3d/map_view_3d.gd::_create_camera()`. This is the historical/alternate top-down construction baseline, not the current exterior gameplay default. Pass: source reconciliation. |
| Interior default | Enclosed definitions that return `suppresses_exterior_surroundings()` start in top-down to avoid perimeter-wall boom clips; players can cycle through third person and first person | `MapViewRuntimeCamera.configure()` and `test_map_camera_modes.gd`. Pass: explicit exception, not an unresolved choice. |
| Gameplay cell scale | One authored gameplay grid cell equals `1.0` world unit. Logic coordinates are converted by `1.0 / cell_size`; the default authored pixel cell size is `32` | `MapViewBridge.WORLD_UNITS_PER_CELL = 1.0`, `world_scale()`, `MapTypes.DEFAULT_CELL_SIZE = 32`. Pass: source contract. |
| Coordinate bridge | Logic `(x, y)` maps to world `(x * scale, height, y * scale)` on XZ; view reads logic positions and never writes gameplay coordinates back | `scripts/map/view3d/map_view_bridge.gd` `logic_to_world()`, `world_to_logic()`, `sync_actor()`. Pass: source contract. |
| Character scale | Visible character height `2.0` world units; target reference height `64 px` at a `1080 px` viewport | `assets/characters/shared/character_scale.gd` `VISIBLE_HEIGHT_WORLD`, `TARGET_VISIBLE_HEIGHT_PX`, and `REFERENCE_VIEWPORT_HEIGHT_PX`. Pass: source contract and character test coverage. |
| Gameplay orthographic character framing | `33.75` world-unit orthographic size, derived from `2.0 * 1080 / 64`; a 2.0-unit character projects to the frozen `64 px` target at the reference viewport | `assets/characters/shared/character_scale.gd` `GAMEPLAY_ORTHOGRAPHIC_SIZE` and `projected_height_px()`. Pass: deterministic formula. |
| Building footprint and root pivot | Footprints are scaled by `1.0 / cell_size`; building root is at the footprint center on ground level (`y = 0`) before terrain grounding | `MapViewMeshBuilderBuildings.build_building()` and `build_exceptional_building()`. Pass: source contract. |
| Wall mesh pivot | Ordinary wall boxes are vertically centered at `height / 2`; round tower drums use the same ground-to-top convention. Roofs are placed at the resolved wall top | `scripts/map/view3d/map_view_mesh_builder_buildings.gd`. Pass: source contract. |
| Wall height rule | Authored `wall_height` is in logic pixels and converts through `world_scale(cell_size)`. `wall` buildings at or above `128 px` use `1.5x` height unless `wall_height_scale` is explicitly authored. Lower fences and enclosure walls remain at authored scale | `MapTypes.FORTIFICATION_MIN_HEIGHT_PX`, `FORTIFICATION_HEIGHT_SCALE`, `resolved_wall_height_px()`, and `MapViewMeshBuilderBuildings`. Pass: source contract. |
| Terrain and actor vertical grounding | Terrain relief is a derived view height. Buildings, landmarks, props, and signs snap to `ground_height`; actors retain logic XZ and receive `ground_height + max(wall-walk elevation, climbable-prop elevation)`. Enclosed interiors use a flat floor | `MapViewMeshBuilderTerrain`, `MapView3D._build_streamed_object()`, and `MapView3D.sync_actor()`. Pass: source contract. |
| Mesh-builder gameplay boundary | `MapViewMeshBuilder` emits view meshes only. It creates no collision shapes, physics bodies, or navigation; the logic plane owns those systems | `scripts/map/view3d/map_view_mesh_builder.gd` and `docs/ARCHITECTURE.md`. Pass: architectural invariant. |

## Non-mutation invariant

The renderer is a derived presentation layer and must not alter gameplay semantics:

- map definitions and fingerprints remain unchanged;
- terrain/grid fingerprints remain unchanged;
- 2D collision and navigation remain owned by the logic map;
- interactions, transitions, and actor logic continue to consume logic-plane coordinates;
- the view bridge is one-directional from logic to world presentation;
- generated 3D meshes do not become a second collision or navigation authority.

The invariant is explicitly stated in [ADR 0007](../adr/0007-ai-generated-isometric-presentation.md), [docs/ARCHITECTURE.md](../ARCHITECTURE.md), and [docs/ART_BIBLE.md](../ART_BIBLE.md). Focused tests exercising this boundary include `tests/godot/test_map_view_3d_core.gd`, `tests/godot/test_environment_kit_integration.gd`, and the map collision/fingerprint suites. This report records the contract; it does not claim a new visual capture.

## Evidence status

### Passing development evidence

- `docs/reports/p0_038_3d_view_comparison.md` records a headless Lower Town frame-time p95 of `7.346 ms` against the `16.67 ms` steady-state reference.
- The P0-038 generator check is required and repeatable: `python3 tools/generate_p038_comparison_report.py --check`.
- The P0-038 report records the renderer readings as headless dummy-renderer values, not GPU acceptance evidence.

### Explicit blockers before technical freeze

1. Run a non-headless benchmark on the declared minimum-supported-hardware profile and retain GPU texture-memory evidence.
2. Record minimum-hardware frame-time evidence against the release budget.
3. Obtain the maintainer decision required by ADR 0013.

Until those items are completed, this document is an implementation lock and reconciliation artifact, not a completed P0-040 approval.

## Verification sources

- [`project.godot`](../../project.godot)
- [`scripts/display/display_window.gd`](../../scripts/display/display_window.gd)
- [`scripts/map/view3d/map_view_3d.gd`](../../scripts/map/view3d/map_view_3d.gd)
- [`scripts/map/view3d/map_view_runtime.gd`](../../scripts/map/view3d/map_view_runtime.gd)
- [`scripts/map/view3d/map_view_runtime_camera.gd`](../../scripts/map/view3d/map_view_runtime_camera.gd)
- [`scripts/map/view3d/map_view_bridge.gd`](../../scripts/map/view3d/map_view_bridge.gd)
- [`assets/characters/shared/character_scale.gd`](../../assets/characters/shared/character_scale.gd)
- [`scripts/map/map_types.gd`](../../scripts/map/map_types.gd)
- [`scripts/map/view3d/map_view_mesh_builder.gd`](../../scripts/map/view3d/map_view_mesh_builder.gd)
- [`scripts/map/view3d/map_view_mesh_builder_buildings.gd`](../../scripts/map/view3d/map_view_mesh_builder_buildings.gd)
- [`scripts/map/view3d/map_view_mesh_builder_terrain.gd`](../../scripts/map/view3d/map_view_mesh_builder_terrain.gd)
- [`tests/godot/test_map_camera_modes.gd`](../../tests/godot/test_map_camera_modes.gd)
- [`tests/godot/test_map_view_runtime_camera.gd`](../../tests/godot/test_map_view_runtime_camera.gd)
- [`tests/godot/test_map_view_3d_core.gd`](../../tests/godot/test_map_view_3d_core.gd)
- [`docs/reports/p0_038_3d_view_comparison.md`](p0_038_3d_view_comparison.md)
- [`docs/reports/p0_040_baseline_reconciliation.md`](p0_040_baseline_reconciliation.md)
- [`docs/adr/0007-ai-generated-isometric-presentation.md`](../adr/0007-ai-generated-isometric-presentation.md)
- [`docs/adr/0015-default-third-person-camera.md`](../adr/0015-default-third-person-camera.md)
- [`docs/adr/0013-authorial-visual-direction-without-blind-ux-panels.md`](../adr/0013-authorial-visual-direction-without-blind-ux-panels.md)
