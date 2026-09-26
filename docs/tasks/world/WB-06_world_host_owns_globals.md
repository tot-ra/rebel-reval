# WB-06: WorldHost phase 3 owns the player, camera, environment, HUD and navigation

Board row: **R-978**. Priority: high. Depends on: **R-977**.

## Player-facing goal

None visible yet. After this row a location can be mounted and unmounted underneath a player who
never stops existing - the precondition for removing the loading screen.

## Why this is needed

`scripts/world/world_host.gd` says it "deliberately does not create players/cameras or perform
scene swaps" and instead holds references to owners created elsewhere. ADR 0019 section 2 requires
the opposite: one persistent host owning exactly one player rig, gameplay camera,
`WorldEnvironment` with sky, weather and day/night clock, HUD and minimap facade, input, music
director binding, save/session binding, streaming scheduler, stable-handle resolver, and **one**
authoritative 2D navigation map.

While the location scene owns those, every location change destroys and rebuilds them, which is
the seam.

## Deliverable

1. **`WorldHost` creates and owns the global singletons** listed above, with `LogicLocations` and
   `ViewLocations` holding only disposable location packages.
2. **Location packages stop creating globals.** `MapSceneBootstrap` and `MapView3D` must not create
   a player, camera, `WorldEnvironment`, sky, HUD, or day/night clock when mounted under a host.
   A package that does is a hard error with a named diagnostic, not a silent duplicate.
3. **One navigation map.** Per-location `NavigationRegion2D` regions attach to and detach from a
   single host-owned navigation map, so a path can cross a seam.
4. **Existing scenes become thin launch adapters.** `scenes/` entry points ask the host to enter a
   location instead of being the location's ownership boundary. Behaviour with the flag off must be
   byte-for-byte the current behaviour.
5. **Duplicate stable-handle detection** already stubbed in `WorldHost._duplicate_stable_handles`
   becomes a real, tested rejection path.
6. **Save and session binding** stay host-owned, and save identity stays `{location_id, object_id}`
   plus global cell/sub-cell exactly as `MapStableStateStore` defines it today.

## Allowed files

`scripts/world/world_host.gd`, `scripts/map/map_scene_bootstrap.gd`,
`scripts/map/view3d/map_view_3d.gd`, `scripts/map/view3d/map_view_runtime.gd`,
`scripts/map/view3d/map_view_runtime_bootstrap.gd`,
`scripts/map/view3d/map_view_runtime_environment.gd`,
`scripts/map/view3d/map_view_runtime_session.gd`, `scripts/map/map_nav_builder.gd`,
`scripts/map/map_stable_state_store.gd`, `scripts/global/door_navigator.gd`,
`scenes/` launch adapters named in the task claim, matching `.uid` sidecars, `project.godot`,
`tests/godot/test_world_host_residency.gd` and its `.uid`,
`docs/SEAMLESS_STREAMING_PLAN.md`, `docs/ARCHITECTURE.md`,
`docs/tasks/world/WB-06_world_host_owns_globals.md`, `TODO.md`.

## Constraints and non-goals

Ships behind `world_host/additive_residency_enabled`, default **false**. With the flag off the game
must behave exactly as today, including the existing loading transitions. No prefetch scheduler and
no seam crossing here - those are R-979 and R-980. Do not change the `.rrmap` format. Do not add an
event bus.

## Verification

- `godot --headless --path . --script tools/run_godot_tests.gd` with
  `test_world_host_residency.gd` asserting: mounting two locations yields exactly one player,
  camera, environment and HUD; unmounting a location leaves the globals alive; a package that
  creates a global is rejected with the named diagnostic; duplicate stable handles are rejected;
  navigation regions attach to and detach from one map and a path crosses between two mounted
  locations.
- Flag-off regression: the full Godot suite, `verify_map_audit.py`, `verify_map_activation.py`,
  `verify_map_conversion_plan.py`, `generate_active_docs_report.py --check`, and a main-menu to
  Lower Town to forge playthrough that is unchanged.
- Save/load verified in both flag states.
- Keyboard, mouse and gamepad input all routed through the host-owned input path.
- `tools/run_performance_report.sh --quick` inside budget with the flag off.

## Doc updates

`docs/ARCHITECTURE.md` gains the host ownership boundary and the list of globals a location package
may not create.
