# WB-07: Budgeted asynchronous location assembly and threaded navigation bake

Board row: **R-979**. Priority: high. Depends on: **R-977**.

## Player-facing goal

None visible yet, and that is the point: mounting a neighbouring location must never produce a
visible hitch. This row makes the cost payable in slices.

## Why this is needed

ADR 0019 is explicit that background-loading the `.tscn` is not enough, because the target scene
still builds synchronously after it enters the tree:

> `MapView3D._assemble()` still builds whole-location surroundings, terrain, height field, interior
> shell, decals, transition visuals, sky, and lighting synchronously

> `MapNavBuilder` bakes one navigation polygon for the complete location on the calling thread

The recorded split was about 20 ms for compilation, terrain, 2D assembly and navigation against
about 2.93 s for full production scene startup. The 3D construction is the cost, and it is on the
main thread. Until it is sliced, a seamless mount is a stall wearing a different name.

## Deliverable

1. **A frame-budgeted assembly scheduler.** `MapView3D._assemble()` is decomposed into resumable
   stages - surroundings, terrain mesh, height field, decals, buildings, props, scatter, detail,
   transition visuals - each yielding when a per-frame budget is spent. The budget is a project
   setting with a stated default. The final visible result must be **identical** to today's
   synchronous output.
2. **Threaded navigation bake.** `MapNavBuilder` bakes off the main thread and publishes the region
   atomically. Deterministic output is a hard requirement; the baked polygon must be identical to
   the synchronous one for every map.
3. **Threaded resource acquisition.** `DoorNavigator._get_scene_resource()` stops using blocking
   `load()` and uses `ResourceLoader.load_threaded_request()` with its existing LRU cache intact.
4. **Cancellation.** A mount in progress can be cancelled cleanly when the player turns back, with
   no leaked nodes, no partial navigation region and no orphaned stable handles.
5. **Instrumentation.** Per-stage timings exported to the performance report so R-980 has a budget
   to hold and a regression can be attributed to a stage.

## Allowed files

`scripts/map/view3d/map_view_3d.gd`, `scripts/map/view3d/map_view_runtime.gd`,
`scripts/map/view3d/map_view_runtime_bootstrap.gd`, `scripts/map/map_nav_builder.gd`,
`scripts/map/map_scene_bootstrap.gd`, `scripts/map/map_object_chunk_streamer.gd`,
`scripts/map/map_terrain_chunk_renderer.gd`, `scripts/global/door_navigator.gd`,
`scripts/world/world_host.gd`, matching `.uid` sidecars, `project.godot`,
`tests/godot/test_async_location_assembly.gd` and its `.uid`,
`tools/run_performance_report.sh`, `docs/PERFORMANCE_REPORT.md`,
`docs/SEAMLESS_STREAMING_PLAN.md`,
`docs/reports/async_assembly_2026-09-26.md`,
`docs/tasks/world/WB-07_async_location_assembly.md`, `TODO.md`.

## Constraints and non-goals

Visual output must be unchanged - this is a scheduling change, not an art change. No seam crossing
and no prefetch policy here; that is R-980. Do not change the `.rrmap` format, any stable ID, the
compiled `MapDefinition` fingerprint, or save identity. Godot 4.7 GL Compatibility is the target;
any stage that cannot leave the main thread in that renderer must be named in the report with the
reason rather than quietly left synchronous.

## Verification

- `godot --headless --path . --script tools/run_godot_tests.gd` with
  `test_async_location_assembly.gd` asserting: staged assembly produces a node tree equal to the
  synchronous one for at least `lower_town_slice`, `kalev_smithy` and one harbour map; the threaded
  nav bake produces a byte-identical polygon over 10 runs; cancellation mid-stage leaks nothing;
  no stage exceeds the budget.
- **Frame-time evidence**, not just totals: a captured frame-time trace of a full mount of
  `lower_town_slice` showing no frame over the stated budget, before and after.
- Re-run the R-977 startup baseline and publish the per-stage breakdown against it.
- Visual parity plates for the three test maps on GL Compatibility, before and after, pixel-equal
  or with every difference explained.
- `python3 tools/verify_map_audit.py`, `verify_map_activation.py`,
  `generate_active_docs_report.py --check`; full Godot suite.
- `tools/run_performance_report.sh` inside budget on minimum and recommended tiers.

## Doc updates

`docs/PERFORMANCE_REPORT.md` documents the new per-stage timing rows and the budget setting.
