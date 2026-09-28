# Seamless streaming plan

Status: accepted target, flag-off. Board: **R-977** (WB-05, membership census
accepted on **R-1016**), then **R-978**..**R-980**.
ADR: [0019](adr/0019-seamless-contiguous-location-streaming.md).

This file is the operational map for ADR 0019. It does not enable runtime streaming.
`world_host/additive_residency_enabled` and `world_host/async_location_assembly_enabled`
remain **false**.

## Player-facing goal

Walk between adjacent Reval districts and harbours without a loading screen. Keep an
explicit travel beat for interiors and for every `world.*` destination.

## Membership census

Every file in `content/maps/` (29 maps) has exactly one kind. Count check: 10 streamed +
9 interiors + 10 travel = 29.

### Streamed: `world_group_id = reval_outdoor`

Physically adjacent Reval districts and harbours. R-980 builds one world-layout
manifest for this group. Current `alignment=travel` marks on some district edges do
**not** override this list. R-980 must convert those edges to reciprocal physical
seams before they can stream.

| Map id | Source | Catalog `active` | Why it streams |
|---|---|---|---|
| `lower_town_slice` | `lower_town_slice.rrmap` | true | Playable Lower Town yard and streets |
| `market_civic_quarter` | `market_civic_quarter.rrmap` | false | Central forum, adjacent to Lower Town |
| `monastery_quarter` | `monastery_quarter.rrmap` | false | Pikk/Lai precinct between civic and north wards |
| `north_quarter` | `north_quarter.rrmap` | false | Merchant ward to the Coastal Gate |
| `south_quarter` | `south_quarter.rrmap` | false | Knights District / Karja approach |
| `toompea_quarter` | `toompea_quarter.rrmap` | false | Walled Upper Town plateau |
| `archbishops_garden` | `archbishops_garden.rrmap` | false | Western Toompea plateau, same hill |
| `viru_gate_foreland` | `viru_gate_foreland.rrmap` | false | Eastern gate and Pirita approach |
| `reval_harbor_north` | `reval_harbor_north.rrmap` | false | Coastal Gate landing |
| `reval_harbor_east` | `reval_harbor_east.rrmap` | false | Kalamaja shore, adjacent landing |

Pirita and other physically contiguous outskirts stay out of this first group, as
ADR 0019 phase 7 already said.

### Interiors: explicit door transitions

ADR 0019 already kept interiors on explicit transitions. This plan keeps that rule
even for the doors the player uses most often (the forge, town hall, churches, and
tower interiors).

Reason: an interior is not a contiguous outdoor cell. Crossing one changes camera
mode, rain shelter, interior-shell lighting, and navigation volume. Putting those
packages into `reval_outdoor` would force WorldHost to own enclosed scenes before
any outdoor seam works. The frequent forge door stays a door.

| Map id | Source | Why it stays explicit |
|---|---|---|
| `kalev_smithy` | `kalev_smithy.rrmap` | Enclosed forge. Most-used door on the playable route |
| `town_hall` | `town_hall.rrmap` | Civic interior |
| `holy_spirit_church` | `holy_spirit_church.rrmap` | Church interior |
| `oleviste_church` | `oleviste_church.rrmap` | Church interior |
| `st_olafs_guild_hall` | `st_olafs_guild_hall.rrmap` | Hall interior |
| `nunnatorn_interior` | `nunnatorn_interior.rrmap` | Tower interior |
| `kuldjala_interior` | `kuldjala_interior.rrmap` | Tower interior |
| `rentenitorn_interior` | `rentenitorn_interior.rrmap` | Tower interior |
| `toompea_small_castle` | `toompea_small_castle.rrmap` | Small Castle interior compound. Unregistered benchmark source (WB-10); still assigned here so the census is complete |

### Travel: `alignment=travel`, never in the physical layout

Every `world.*` map stays a travel destination. A validator in R-980 must reject a
travel transition that is authored as a physical seam.

| Map id | Source |
|---|---|
| `world.saaremaa` | `world_saaremaa.rrmap` |
| `world.padise` | `world_padise.rrmap` |
| `world.paide` | `world_paide.rrmap` |
| `world.parnu` | `world_parnu.rrmap` |
| `world.poide` | `world_poide.rrmap` |
| `world.kanavere` | `world_kanavere.rrmap` |
| `world.sojamae` | `world_sojamae.rrmap` |
| `world.harju` | `world_harju.rrmap` |
| `world.sacred_grove` | `world_sacred_grove.rrmap` |
| `world.rebel_kings` | `world_rebel_kings.rrmap` |

## Phases 3-5

| Phase | Row | Exit gate | Flag | Rollback |
|---|---|---|---|---|
| 3 Host owns globals | R-978 / WB-06 | `--filter=test_world_host_residency`: one player, camera, environment, HUD, and navigation map across two mounted locations; global-creating packages and duplicate handles rejected; a path crosses between the two. Flag-off suite and menu-to-forge playthrough stay identical | `world_host/additive_residency_enabled=false` | Leave the flag false. Scenes keep today's ownership |
| 4 Budgeted assembly | R-979 / WB-07 (R-1005, R-1006, R-1010 close the remaining over-budget units) | `--filter=test_async_location_assembly`; staged tree equals synchronous; nav bake is byte-identical; cancel leaks nothing; per-stage timings stay inside the 4 ms frame budget on the named maps | `world_host/async_location_assembly_enabled=false` | Leave the flag false. Play stays on synchronous `MapView3D.create()` |
| 5 Seam crossing | R-980 / WB-08 | See [R-980 release criteria](#r-980-release-criteria) | Both flags above. Defaults flip **on** only after those criteria pass | `world_host/scene_swap_fallback_enabled` remains a working path |

**Phase 3 status (2026-09-27).** R-978 landed the host side, flag off:
`WorldHost.create_globals()` owns the single player, rig, camera, environment, sun, sky,
clock, HUD, session/music binding, `MapStableStateStore`, and navigation map;
`enter_location()` mounts `MapSceneBootstrap.assemble_location_package()` plus
`MapView3D.create_hosted()`; packages that create a global are rejected with
`WORLD_HOST_PACKAGE_CREATES_GLOBAL` and repeated handles with
`WORLD_HOST_DUPLICATE_STABLE_HANDLE`.

**R-1038 / WB-06b (2026-09-27).** `reval_east` and `forge` are launch adapters. With
the flag on, `WorldHost.launch_scene_location()` adds a host under the scene root,
creates the globals, seeds the host clock once from `MusicDirector`, enters the
location (the `reval_outdoor` manifest layout when it lists the location, otherwise a
one-location `<id>_solo` group, which is how the forge interior gets host globals) and
retires the Player baked into the `.tscn`. `hosted_bootstrap()` returns the same
dictionary shape scene scripts already read, built from the mounted logic package.
`MapViewRuntime.install_hosted()` binds the host Player, PlayerRig, camera, hosted
view and minimap instead of instantiating them, and the host clock replaces the
per-runtime `MusicDirector` restore (the runtime still writes `MusicDirector` so music
and flag-off scenes keep the day). `DoorNavigator.place_player` is unchanged: it walks
the scene root, which now contains the host's doors. Flag off, the scenes call exactly
today's `MapSceneBootstrap.assemble()` and `MapViewRuntime.install()`.
`--filter=test_world_host_launch` covers the host census, hosted runtime binding,
host clock (tick, pinned time, save snapshot restore), DoorNavigator pending and
default spawns, keyboard, gamepad and click routing, and both real scenes with the
flag on. Limits kept for later rows: the host lives under the scene, so a door still
swaps scenes and builds a new host (persistent host and seam-driven streaming are
**R-1043**). Quest NPCs and the other outdoor entry points are **R-1049**.
Rendered flag-on playthrough plates are **R-1050**.

**R-1049 / WB-06d (2026-09-27).** Every remaining `reval_outdoor` scene
(`reval_center`, `reval_monastery`, `reval_north`, `reval_south`,
`reval_toompea`, `reval_archbishops_garden`, `harbor_east`, `harbor_north`,
`viru_gate_foreland`) is a launch adapter behind the same flag. Scene `Actors`
nodes stay under the scene so existing `scene_root/Actors` lookups still work,
but launch offsets them to the mounted package origin so an NPC at a local
cell matches the package anchor.
Flag off is unchanged. `--filter=test_world_host_launch`.

**R-1039 (2026-09-27).** Baked `NavigationRegion2D`s keep the flag-off
`agent_radius = 16` inset, so two real packages leave a 32 px gap at a shared
edge. `WorldHost` attaches those regions to one map and installs a deterministic
`NavigationLink2D` per active `MapWorldLayout` seam. The bake itself is
unchanged (R-979 nav parity). `--filter=test_world_host_residency`.

**R-1041 (2026-09-27).** The seam-link helpers live on `mount_location()`, so they
already run after `create_globals()` / `enter_location()`. The residency suite now
proves a click path across two `MapSceneBootstrap.assemble_location_package()`
mounts on that phase-3 host (phase-2 `configure()` stays as a regression).
`--filter=test_world_host_residency`; `--filter=test_async_location_assembly`
nav byte-identity is unchanged.

**Phase 5 status (2026-09-27, R-980 slice 1).** Host side landed, flags off:

- Manifest: `content/world/reval_outdoor_layout.json`, built by
  `godot --headless --path . --script tools/build_world_layout.gd` (`-- --check` fails
  when stale) and verified by `python3 tools/verify_world_layout.py`. All ten members
  place from `lower_town_slice`; 14 seams, **14 streamable**. R-1045 matched the
  three former `MAP_WORLD_SEAM_SPAN_MISMATCH` apertures without moving their
  centers, so world origins stay put: Karja keeps the Lower Town 14-cell opening
  (`south_quarter/to_reval_east` 12 -> 14), Vene/Lai stays the 3-cell lane
  (`monastery_quarter/to_reval_east` 11 -> 3), and the Pikk/Puhavaimu civic seam
  keeps the forum 10-cell throat (`monastery_quarter/to_reval_center` 12 -> 10).
  Four `world_*` exits (`reval_harbor_north/to_world_saaremaa`,
  `south_quarter/to_world_sacred_grove`, `toompea_quarter/to_world_padise`,
  `viru_gate_foreland/to_world_harju`) are authored `alignment=travel` so they
  stay explicit hops (R-1046). `find_transition_pairs` and neighbour previews
  skip travel pairs. CI and path-aware pre-commit run
  `tools/build_world_layout.gd -- --check`, `tools/verify_world_layout.py`, and
  `tests.python.test_verify_world_layout`.
- Scheduler: `WorldHost.update_streaming()` / `WorldHostResidencyPolicy.plan()` with the defaults below.
- Handover, travel boundary, fallback, staged mounts and seam saves:
  `--filter=test_world_seam_crossing` (21 tests).

| Setting | Default | Derivation |
|---|---|---|
| `world_host/streaming_prefetch_band_cells` | 48 | slowest staged mount ~4.7 s (R-1005 `lower_town_slice`, 4 ms budget) x run speed 7.5 cells/s (240 px/s) x ~1.35 safety |
| `world_host/streaming_eviction_band_cells` | 64 | prefetch + 16 cells (~2 s of running) of hysteresis |
| `world_host/streaming_residency_cap` | 3 | owner + two neighbours at a seam corner; Lower Town alone already exceeds the node/memory caps |

**R-1043 (2026-09-27, flag on only).** `WorldHostStreamingDriver` drives the host
from live play. `WorldHost.launch_scene_location()` attaches it, so every hosted
launch adapter streams.
It attaches only to a host whose layout has seams, so the forge solo group never
streams. The driver:

- defaults `definition_provider` to the registry-compiled definition
  (`WorldHostStreamingDriver.registry_definition()`);
- calls `update_streaming(player_owner.global_position)` every physics frame;
- sets `transition_enabled = false` on every door for which
  `is_transition_streamed()` is true, so a streamed seam never runs a
  DoorNavigator scene swap while residency is active;
- no longer pins the launch location. R-1054 rebinds owner-scoped consumers
  on `owning_location_changed`, so the residency cap can evict the entry map.

Each package's boundary walls sit just outside its rect, inside the neighbour's
first column. `MapSceneBootstrap.assemble_location_package()` therefore splits
every wall around its edge transitions into `SeamGate_<transition_id>` shapes.
The gates start sealed, so collision is unchanged. The driver opens both gates of a
seam only while the seam is active (both sides resident). A failed neighbour keeps
its gates sealed. When the player touches that seam door, the driver calls
`WorldHost.request_scene_swap_fallback()`, and
`DoorNavigator.answer_seam_fallback()` swaps scenes through the door's authored
destination (found by its `transition:<id>` stable handle). Blocked-seam crossings
reach DoorNavigator the same way.

`owning_location_changed` writes the new location's `scene_id` and arrival-door
spawn to `SessionState.state.player`. A save taken after a crossing therefore
reloads at that seam through today's scene path.

The seam `NavigationLink2D` now sits at the base transition door's centre
(`MapWorldLayout.seam_navigation_link_points(..., aperture_center)`). Before this
change it sat at the middle of the shared edge, which on real districts lands on
buildings, so click paths never crossed. `assemble()` (flag off) is untouched.

Evidence:

- `--filter=test_world_host_streaming`: synchronous. It covers the sealed package
  walls, the prefetch, open gates, owner handover, session scope and pinning on a
  real `reval_east` launch, and the forced loader failure, which reaches
  DoorNavigator with `vana_turg_boundary -> reval_center/from_reval_east`.
- `godot --headless --path . res://tools/verify_world_seam_walk.tscn` (29 checks,
  exit 0): the physical walk over real physics frames. It stays out of the
  harness because it synchronously mounts whole districts mid-walk.
  - Keyboard: `ui_left + ui_up` is logic west.
  - Gamepad: left stick right + down.
  - Mouse: a `MapClickInput` logic click on a market point, after movement is
    released and the body is clamped onto the host nav mesh (R-1074).
  - Fallback: walking into the sealed door.
  - Every walk keeps one Player and camera and makes no `go_to_scene`.
- `--filter=test_world_host_residency`: the three seam-path tests that R-1053
  skipped (they failed once the harness really awaited them) run again. The cause
  was the wait, not the links. Godot 4.7 iterates navigation maps asynchronously,
  and region polygons land on a later iteration than four physics frames, so
  `_sync_navigation()` now waits 30 frames.

The trace in `build/world_seam_walk.json` has a p50 of 18 ms and a p95 of 29 ms.
It also shows 4.3-6.6 s frames: synchronous mounts of `market_civic_quarter`
inside the prefetch tick. Those frames are why staged mounts (R-1044) gate any
flag flip.

**R-1054 (2026-09-27).** On `owning_location_changed` the driver rebinds
owner-scoped consumers to the new location in location space:

- `Player.configure_map_movement` gets the owning definition, grid and origin
  so terrain speed samples `global - origin`.
- `MapViewRuntime.bind_owning_location` retargets the hosted view, camera
  ground/occlusion (view-local XZ), ambient, and a minimap tracker that
  reports local logic.
- The driver retargets the scene `MapPhaseBinder` to `loc.<id>` via
  `hosted_bootstrap` (no launch-scene method; that file already fails gdlint).
- Quest controllers stay scene-scoped on Lower Town (ADR phase 6).
- Off-mesh click starts clamp to the host navigation map. The destination is
  left alone so a cross-seam click is not snapped back onto the current mesh.
- `pinned_location_ids` is cleared; far past the eviction band the launch
  location unmounts.

**R-1044 / WB-08c (2026-09-28, both flags on only).** Neighbour mounts are
staged. With `world_host/async_location_assembly_enabled` on and no injected
`location_loader`, `WorldHost.update_streaming()` hands every prefetch to
`WorldHostMountQueue` instead of calling `enter_location()`:

| Phase | Where | Work |
|---|---|---|
| `PREPARING` | WorkerThreadPool task | compile definition, `MapBuilder.build`, detached logic package (collision, navigation bake, doors) |
| `ASSEMBLING` | main thread, shared 4 ms budget | `MapView3D.create_hosted_staged()` units |
| `VERIFYING` | WorkerThreadPool task | `WorldHostPackageInspector.inspect()` of both detached packages (host-global nodes, stable handles), then `split_for_entry()` of the view (R-1069) |
| `ENTERING` | main thread, shared budget | the view enters a hidden host staging root in slices (R-1069) |
| `READY` | main thread, its own tick | `mount_location(..., inspection, staging_root)`: registry check, logic package into the tree, reveal the view |

- The active (owning) map is never staged. A player who teleports into an
  unresident location still loads it synchronously.
- A pending mount counts against `streaming_residency_cap`
  (`WorldHostResidencyPolicy.plan()` gets mounted plus in-flight ids) and gets the
  eviction hysteresis. It is never mounted, so no seam is active toward it and its
  gates stay sealed.
- Eviction cancels. `PREPARING` / `VERIFYING` results drain without blocking the
  frame and are freed when their task ends. An assembling view cancels and joins
  its worker jobs. `test_evicting_an_in_flight_mount_cancels_and_leaks_nothing`
  checks orphans and the object count.
- Failed mounts back off: 30 ticks, doubling to 480 (was: retried every frame).
- `MapViewAssembly.step()` no longer starts a unit whose stage mean cost does not
  fit the rest of the budget. The first unit of a step always runs.
- Unmount rebuilds the stable-handle registry from the entries stored at mount,
  without walking every resident package.

**Decision: crossing into an in-flight neighbour waits at the seam edge.** A
healthy mount is not a failure, so no scene swap is requested. The driver holds
the player at the sealed gate (a streamed-door touch toward a pending neighbour
does not request the fallback). `update_streaming()` returns `waiting` and the
owner does not change. Each edge visit records one readiness miss
(`mount_queue.misses()`: phase, logic-package readiness, next stage, pending
units, ticks waited). This follows ADR 0019's fallback order: when only
decoration stages remain (`scatter` onwards), the package mounts at once. Its
collision truth is complete and ground and buildings exist. The remaining view
units keep running in the tree (`REFINING`), and the miss records
`early_mounted` plus the deferred stage. A failed mount (prepare returned
nothing, or still in backoff) takes today's scene-swap fallback.

**Save/load across a seam.** `WorldHostSeamSave` keeps the save identity at
`{location_id, object_id}` plus global cell / sub-cell. The driver writes the
player as entity `char.kalev` under the owning location on every tick, together
with the owner's `scene_id`. The owner is always mounted and never in flight, so
a save taken mid-mount has no pending state, chunk, or node path. The first
driver tick of a hosted launch applies a loaded record flagged `resume` after
DoorNavigator has placed the player at the spawn. A seam crossing, or a host
leaving the tree, clears `resume` for that location. A later door entry therefore
uses its spawn. Covered by
`test_save_on_either_side_of_a_seam_and_mid_mount_round_trips` (SaveService on
disk, both sides, mid-mount, object delta, quest state).

Two-seam trace:
`godot --headless --path . res://tools/trace_world_two_seam_walk.tscn [-- --px-per-frame=2]`.
It walks Lower Town -> market -> south over real physics frames and writes
`build/world_two_seam_trace.json`. Six runs on the development Mac, driver tick =
all main-thread streaming work:

| Walk | tick p50 | tick p95 | max | over 4 ms | misses |
|---|---|---|---|---|---|
| 2 px/frame (walking) | 0.05 ms | 3.8 ms | 70-75 ms | 163-172 of 3,879 | none; mounts 7.8-8.0 / 3.4 ms |
| 4 px/frame (running) | 0.06 ms | 4.8 ms | 91-95 ms | 163-167 of ~2,250 | both, early-mounted; ~5 s held at the seams |

The R-1043 synchronous trace had 4.3-6.6 s frames. The 4 ms gate is **not met
yet**. The remaining causes:

- Atomic view units over 4 ms account for most over-budget ticks while a mount is
  pending: `surroundings` neighbour orchards and towers up to 67 ms, the Karja
  gate arch, and some `buildings_props` houses. Splitting them is R-1006.
- The owner-change rebind (R-1054 consumers) takes 24-70 ms (**R-1071**).
- Tree entry of a finished view takes ~8 ms on market. Tree exit on eviction
  takes ~14 ms (**R-1069**, done below).
- An early mount must inspect the incomplete view on the main thread (~9 ms)
  (**R-1069**, done below).
- A staged mount takes ~6.5 s from prefetch to ready on market and south. That
  is longer than the 48-cell band gives a running player (6.4 s), so running
  crossings miss (**R-1072** re-derives the band).
- One of eleven trace runs crashed (SIGSEGV) inside a worker pattern bake
  (`map_view_material_patterns.gd` `_pattern_image_at_size`) while mounts were
  staged. **R-1070** serializes compute workers (pattern / mesh bakes) against
  scene-kind workers (prepare Door instantiate, package inspect) and stops
  roof-tile paints writing the shared pattern `_cache` from a worker.
  **R-1076** (2026-09-28): 30 consecutive headless two-seam traces at
  `--px-per-frame=2 --stability` on `78205b94` (R-1070) in an isolated
  worktree. 30/30 exit 0. `signal 11` / `SIGSEGV` grep empty across every log.
  Every walk visited Lower Town -> market -> south with no scene swap. Over-budget
  ticks stayed 160-194 (median 169) and `tick_ms_max` 101-110 ms; those remain
  R-1006 / R-1069 / R-1071. Default `world_host/async_location_assembly_enabled`
  stays false. The default trace still exits 1 on the 4 ms gate; `--stability`
  is the crash-only leftover. After rebasing onto `9d1f7eb6` (R-1069), one
  confirmation run crashed at startup in a worker `ground_color_tint` /
  `propagate_notification` call; the next run on the same tip exited 0. That
  leftover is **R-1079**, not a reopen of this 30-run verify.

**R-1079** (2026-09-28): worker terrain/vegetation colour reads stay off the
SceneTree Node API. `TerrainVegetation.ground_color_tint` warms a tint cache on
the main thread and, on a compute worker, only reads that cache or a hardcoded
style table (no plant/bush/tree catalog first-load). `MapViewWorkerJob` primes
`Image.create` on the main thread before `add_task`. `pattern_bake_units` paints
one 32 px plate per distinct pattern on the main thread before the group task
(4 px hits `posmod(0)` in lattice painters).

Crash stacks that motivated the warmup:

- After R-1069: `terrain_vegetation.gd:163 ground_color_tint` <-
  `cell_tone` / `ground_band` <- `map_view_worker_job.gd:105`. Engine:
  `/root: The caller thread can't call propagate_notification()`. Intermittent.
- During the first 10-run probe on this change: same engine error, but the
  stack was `_pattern_image_at_size` / `_paint_rock` <- `bake_image` <-
  `pattern_bake_units` worker lambda. A leftover `world_two_seam_trace.json`
  from the previous successful run must not be scored when exit is nonzero.

Ledger (isolated worktree at `8eab04c9` plus this change): 30/30
`--px-per-frame=2 --stability` exit 0. `signal 11` / `SIGSEGV` /
`propagate_notification` grep empty across every log. Every walk visited
Lower Town -> market -> south with no scene swap. `tick_ms_max` 103-114 ms
and over-budget ticks 146-233; those remain R-1006 / R-1069 / R-1071.
`--filter=test_async_location_assembly` 20/20. Streaming flag defaults stay
false.

**R-1069 / WB-08e (2026-09-28, both flags on only).** Tree entry, tree exit
and the early-mount walk are sliced:

- **Sliced entry.** The verify worker splits the detached view
  (`WorldHostPackageInspector.split_for_entry()`, at most 64 nodes per slice).
  Only plain `Node`/`Node3D` containers and the `MapView3D` root give up their
  children. Scripted and other native subtrees enter whole, so no `_ready()`
  sees a partial subtree. `ENTERING` adds the slices back in pre-order into a
  hidden staging root under the host's view layer. Nothing registers, activates a
  seam or is drawn until the host mounts. The staging root then becomes the view
  root and is revealed. The final tree is node-for-node the synchronous tree
  (`test_sliced_entry_stays_hidden_and_mounts_the_synchronous_tree`).
- **Mount ticks do nothing else.** Finished entries hand over at the start of
  the next tick (`handovers()`). In a tick that mounts, no view unit or
  teardown slice runs: the first unit of a step always runs, and a heavy
  decoration unit would stack on the mount. The step keeps 0.4 ms of the budget
  for the rest of the streaming tick (`STREAMING_TICK_RESERVE_USEC`).
- **Early mount without a main-thread walk.** When the player reaches a
  neighbour whose remaining units are all decoration, the view pauses. A worker
  inspects and splits the part already built (`VERIFYING_EARLY`), it enters in
  slices, and it mounts as `REFINING`. The player waits at the sealed seam for
  those few ticks. A `VERIFYING` mount at the deadline is no longer joined on the
  main thread.
- **Sliced teardown.** `unmount_location()` detaches the logic package at once,
  so navigation and collision leave in the evicting tick. The view root is
  hidden, renamed (`<id>__evicting_<n>`, so the location can mount again at once)
  and freed one leaf or atomic subtree at a time
  (`WorldHostPackageInspector.next_removal()`), children before their container.
  The detached logic package is freed the same way. Teardown gets at most half
  the budget. A cancelled `ENTERING` or unmounted `READY` package uses the same
  path. Flag off, unmount is unchanged.
- Trace breakdown: `queue_ms`, `evict_ms` and `slice_ms` per frame, and
  `slice_ms_max` / `slice_max_label` in the summary.

Same trace, three runs each on the development Mac, against `origin/main` at
`392754b3` on the same machine:

| Tick | Before (R-1044) | After (R-1069) |
|---|---|---|
| Ordinary mount (walking) | 8.7 ms | 1.8-2.7 ms |
| Early mount (running), streaming step only | ~17 ms (inspect ~9 + entry ~8) | 1.6-2.1 ms |
| Early mount (running), whole tick | 49-100 ms | 26-72 ms (owner rebind, R-1071) |
| Eviction tick | 14.3-15.7 ms | 1.2-1.3 ms |
| Entry ticks | - | 4 per run, max 3.67 ms |
| Teardown ticks | - | 27-28 per run; all but one at most 2.1 ms |
| Ticks over 4 ms (walking / running) | 193 / 167-192 | 149-150 / 144-151 |
| tick p95 (walking / running) | 4.00 / 4.62-4.83 ms | 3.63-3.65 / 4.44-4.50 ms |

Residual, not met: in every run exactly one teardown slice takes 4.5-6.4 ms, and
its tick 5.0-7.9 ms. It is not tied to a node or a resource. A different
ordinary `MeshInstance3D` or `Node3D` is hit each run. Inside the slice the
stall moves between `remove_child`, the geometry strip and `free()`. No worker
mount is in flight at that moment. It looks like a process-wide stall (allocator
or server lock) and is filed as **R-1077**. Every other over-budget tick is an
atomic view unit (R-1006) or the owner rebind (R-1071).

Limits kept for later rows are the items above, plus two more:

- Logic packages still build Door scenes on a worker, which relies on off-tree
  node creation being thread-safe.
- The R-1043 walk tool's mouse leg is deterministic after R-1074: leftover
  `ui_right`/`ui_down` from the gamepad stick is `action_release`d, and the
  click starts from the closest host-nav point to `(24, current Y)` instead of
  the off-mesh `(8, original spawn Y)` inset. Ten consecutive headless runs
  on `origin/main` plus this change exited 0 with 29/29 checks; every mouse
  start was `(24.0, 1649.181)` with a zero axis and velocity.

Still open before the release criteria can pass: the 4 ms per-frame gate
(follow-ups above); a rendered clip of a two-seam walk; relief continuity
(R-976); performance report with the cap at its default.

ADR phase 6 (NPC, quest, fauna, audio, persistence residency beyond the two-seam walk)
is follow-up work after R-980, not a fourth pack row.

## R-980 release criteria

These are the ADR 0019 acceptance gates, restated as the only conditions that may
flip the streaming flags to on. All gates apply in both directions across at least
one real district seam, then across a route with at least three seams.

### Functional continuity

- No `SceneTree.change_scene_to_packed()` on a seamless edge.
- The same player, camera, session, day/night clock, and weather instance survive.
- Player global logic position and velocity stay continuous within 0.01 logic units.
- Cross-seam keyboard movement and click navigation work after repeated load/unload.
- A stable object or dynamic entity exists at most once across owner and consumer packages.
- Saving on either side of a seam restores location, global cell/sub-cell, object deltas, and quest state.
- `alignment=travel` destinations never enter the physical layout. Every map outside
  `reval_outdoor` in this file stays on an explicit transition.

### Visual and audio continuity

- The camera never reveals missing terrain, an internal surroundings skirt, a duplicate
  wall, a lighting or sky reset, or a one-frame location flash.
- Terrain, water, roads, walls, and the transition aperture meet at the authored seam
  within the agreed geometric tolerance. After R-976, there is no vertical step.
- Location ambience and music crossfade without duplicate world-global emitters.
- Lower-detail visuals may refine after activation. No placeholder may change collision
  or interaction truth.

### Performance and residency

Use `tools/benchmarks/large_map_benchmark_config.json` unless a later measured ADR
changes the numbers:

- main-thread streaming work <= 4 ms per frame
- steady frame p95 <= 16.67 ms and p99 <= 25 ms
- resident nodes <= 7,500
- resident collision shapes <= 900
- resident static memory delta <= 280 MiB
- one 32 x 32 chunk activation <= 50 ms p95
- one overlapped navigation tile bake <= 25 ms p95
- a 30-minute seam-crossing soak returns node/RID counts to the documented cache
  baseline and shows no monotonic memory growth

An artificial delayed-I/O test must prove that low-priority visuals defer first,
authoritative unloaded space is never exposed, and the readiness miss is recorded.

The 2026-09-27 Lower Town production scene is already over the node and memory
caps (15088 nodes, 602 MiB static delta). Streaming cannot flip on until residency
is inside those caps. See the [startup baseline](reports/seamless_startup_baseline_2026-09-26.md).

## Map-activation prerequisites

This row activates no map. Only `kalev_smithy` and `lower_town_slice` are
`active=true`. The forge is an interior, so today there is **no pair of active
outdoor maps** that can demonstrate a seamless edge.

R-980 may still land the host, manifest, and tests against inactive prototypes.
A player-visible two-seam walk cannot ship until all of the following land:

1. **At least one outdoor neighbour of `lower_town_slice` is activated.** The
   activation ledger today names `market_civic_quarter` (P4-022 / P4-019),
   `north_quarter` (P4-020 / P4-023f), `south_quarter` (P4-024), and
   `toompea_quarter` (P4-025). `monastery_quarter`, `archbishops_garden`,
   `viru_gate_foreland`, `reval_harbor_north`, and `reval_harbor_east` are in
   the stream group but have no row in
   [`docs/data/location_activation_manifest.json`](data/location_activation_manifest.json)
   yet. They need a named activation owner before promotion.
2. **R-976 relief seam continuity** for every seam the demo walk crosses. WB-08
   already forbids a vertical step once that heightfield exists.
3. **R-716 / world-building visual gate** remains the promotion gate. A green
   host test does not activate a map.
4. **R-978 and R-979 exit gates**, including the remaining over-budget assembly
   units owned by R-1006 and R-1010.

## Startup baseline

Re-measured 2026-09-27. Command and tables:
[`docs/reports/seamless_startup_baseline_2026-09-26.md`](reports/seamless_startup_baseline_2026-09-26.md).
Budget streaming against those numbers, not the 2026-07-17 20 ms / 2.93 s pair.

## R-1016 census (accepted 2026-09-27)

Second-reviewer check of the three membership tables against every
`content/maps/*.rrmap` `map <id>` header:

- 29 source maps, 29 plan rows (10 streamed + 9 interiors + 10 travel)
- no map missing from the plan, no plan id absent from `content/maps/`
- no double assignment
- streamed `active` column matches the source headers (`kalev_smithy` and
  `lower_town_slice` are the only `active=true` maps; the forge stays interior)
- every table `Source` filename resolves to the same map id

Re-run:

```bash
python3 - <<'PY'
from pathlib import Path
import re
root = Path('.')
ids = [re.search(r'^map\s+(\S+)', p.read_text(), re.M).group(1)
       for p in sorted((root / 'content/maps').glob('*.rrmap'))]
plan = (root / 'docs/SEAMLESS_STREAMING_PLAN.md').read_text()
sections = {
    'streamed': re.search(r'### Streamed:.*?### Interiors:', plan, re.S).group(0),
    'interiors': re.search(r'### Interiors:.*?### Travel:', plan, re.S).group(0),
    'travel': re.search(r'### Travel:.*?## Phases', plan, re.S).group(0),
}
assigned = []
for body in sections.values():
    assigned.extend(re.findall(r'^\|\s*`([^`]+)`\s*\|', body, re.M))
assert len(ids) == 29 and ids == sorted(set(ids))
assert len(assigned) == 29 and len(assigned) == len(set(assigned))
assert set(ids) == set(assigned), set(ids) ^ set(assigned)
print('ok', len(ids))
PY
```

Accept. R-977 membership verify is closed. No interiors or travel rewrite.
