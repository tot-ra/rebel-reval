# WB-03: Relief drives player height, slope, navigation and camera

Board row: **R-975**. Priority: high. Depends on: **R-974**.

## Player-facing goal

Kalev walks up a hill and down into a hollow. He slows on a steep bank, cannot walk up a cliff face,
and the camera keeps him framed as the ground rises. NPCs, carts and the crowd stand on the same
ground he does instead of floating at a fixed height.

## Why this is needed

`MapNavBuilder.create_navigation_region()` bakes a flat `NavigationRegion2D` from the world rect
minus building footprints, excluded areas and water. Nothing in `scripts/map/` or the player path
reads a height field; the only consumers of `MapViewMeshBuilder.ensure_height_field` are
`boat_float_3d.gd`, `map_view_penned_fauna.gd`, `map_view_urban_fauna.gd` and the scatter and
terrain-detail builders. So fauna and boats already sit on the terrain and **the player does not**.
After R-974 the height exists and is authoritative; this row consumes it.

## Deliverable

1. **Player and actor height.** The 3D player rig and every actor placed by
   `map_view_runtime_actors.gd` and `map_view_crowd_renderer.gd` take Y from
   `MapDefinition.height_at_world()`, smoothed over a stated window so a cell boundary does not
   produce a visible step. Logic position stays 2D; height is derived, never stored.
2. **Slope limits and cost.** A maximum walkable slope from ADR 0023. Above it the cell is
   impassable. Below it, movement speed scales with uphill slope by a stated curve.
   `map_terrain_movement.gd` owns the cost; it must stay deterministic.
3. **Navigation.** `MapNavBuilder` adds obstructions for every cell whose slope exceeds the walkable
   maximum and for every `relief_cliff` face, so pathfinding routes around banks rather than through
   them. Ramps and terrace edges stay traversable.
4. **Collision.** Ground collision follows the compiled field rather than a plane, at a stated
   resolution. Map-edge walls and water collision built by `MapSceneBootstrap` keep their behaviour.
5. **Camera.** `map_view_runtime_camera_*` keeps the existing framing contract over sloped ground;
   `map_view_runtime_camera_safety.gd` must not clip into a rising bank.
6. **Transitions and anchors.** Every existing transition, spawn and gameplay anchor cell stays
   reachable. A transition whose cell became unwalkable is a failure, not a re-author prompt.

## Allowed files

`scripts/map/map_nav_builder.gd`, `scripts/map/map_terrain_movement.gd`,
`scripts/map/map_scene_bootstrap.gd`, `scripts/map/map_verification.gd`,
`scripts/map/view3d/map_view_runtime_actors.gd`, `scripts/map/view3d/map_view_crowd_renderer.gd`,
`scripts/map/view3d/map_view_runtime_camera.gd`,
`scripts/map/view3d/map_view_runtime_camera_safety.gd`, `scripts/map/view3d/map_view_3d.gd`,
matching `.uid` sidecars, `tests/godot/test_relief_traversal.gd` and its `.uid`,
`tests/godot/test_map_nav_builder.gd`, `docs/MAP_AUTHORING.md`,
`docs/reports/relief_traversal_2026-09-26.md`, `docs/reports/images/relief/`,
`docs/tasks/world/WB-03_relief_drives_gameplay.md`, `TODO.md`.

## Constraints and non-goals

No map re-authoring - that is R-976. No swimming or climbing changes; ADR 0021 and
`map_climbable_props.gd` keep their current scope. No new event bus. Save format must not gain a
height field. Keyboard, mouse and gamepad movement must all be checked.

## Verification

- `godot --headless --path . --script tools/run_godot_tests.gd` with a new
  `test_relief_traversal.gd` asserting: derived Y matches `height_at_world` within tolerance;
  uphill cost is monotonic in slope; a cell above the slope maximum is not walkable; a `relief_cliff`
  produces navigation obstruction; a `relief_terrace` edge stays walkable; determinism over two runs.
- **Walkable-cell census unchanged on every flat map.** All 29 maps compile; for every map whose
  authored relief span is under the slope threshold, the walkable-cell count and the largest
  walkable region must equal the pre-change baseline exactly. Record the numbers in the report.
- Every transition and anchor cell on every map is still walkable and still reachable from the map's
  primary spawn by flood fill.
- `python3 tools/verify_map_audit.py`, `verify_map_activation.py`, `verify_map_composition.py`,
  `python3 tools/generate_active_docs_report.py --check`
- Save/load round trip across a slope: position restores to the same logic cell and the same derived
  height.
- Captures: a walk up and down an authored test ramp on keyboard and on gamepad, plus a camera plate
  at the top and bottom of the slope showing no clipping.
- `tools/run_performance_report.sh --quick` inside the existing budget.

## Doc updates

`docs/MAP_AUTHORING.md`: the slope maximum, the movement-cost curve, and the fact that relief is now
authoritative for navigation. `docs/reports/relief_traversal_2026-09-26.md` carries the census table.
