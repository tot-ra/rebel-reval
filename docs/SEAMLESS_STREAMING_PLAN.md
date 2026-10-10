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

Every file in `content/maps/` (29 maps) has exactly one kind. Target census after
[ADR 0027](adr/0027-reval-hinterland-streaming-group.md) and
[ADR 0028](adr/0028-seamless-building-interiors.md): 10 `reval_outdoor` + 2 `reval_hinterland`
+ 9 interiors + 8 travel = 29. Five planned hinterland connectors bring the total to 34 once
authored. Runtime membership (`REVAL_OUTDOOR_MEMBERS`, the checked-in layout manifest) still
matches the ADR 0019 census until UF-15 (R-1133) authors the hinterland seams; all streaming
flags stay off.

### Streamed: `world_group_id = reval_outdoor`

Physically adjacent Reval districts and harbours. R-980 builds one world-layout
manifest for this group. Current `alignment=travel` marks on some district edges do
**not** override this list. R-980 must convert those edges to reciprocal physical
seams before they can stream.

**Retired ([ADR 0031](adr/0031-continuous-reval-city-plan.md)).** The ten district maps
(`lower_town_slice`, `market_civic_quarter`, `monastery_quarter`, `north_quarter`,
`south_quarter`, `toompea_quarter`, `archbishops_garden`, `viru_gate_foreland`,
`reval_harbor_north`, `reval_harbor_east`) were replaced by the one seamless
`reval_city` scene and their `.rrmap` sources were removed. `REVAL_OUTDOOR_MEMBERS` is
empty, `content/world/reval_outdoor_layout.json` is not built, the seam-continuity grace
list is empty, and `CityTravel.REDIRECTS` routes the old district scene ids into the
city. The group id stays declared so its diagnostics remain a stable API. The table
below is intentionally empty: `tools/verify_world_layout.py` reads it as the expected
membership.

| Map id | Source | Catalog `active` | Why it streams |
|---|---|---|---|

Planned addition ([ADR 0029](adr/0029-natural-reval-maps-and-larger-coast.md), no source file
yet, outside the 29-map count): planned: `reval_harbor_sand_gate`, a shore map adjacent to
`reval_harbor_north` toward the Sand Gate. ADR 0029 also grows `reval_harbor_east`,
`reval_harbor_north` and `viru_gate_foreland` (no location above 32,768 cells).

Pirita and other physically contiguous outskirts are not in this group. They form the
second group below.

### Streamed: `world_group_id = reval_hinterland` (ADR 0027)

Physically contiguous outskirts, joined to `reval_outdoor` only through allowlisted gate
bridges. The two existing maps stay on their travel exits until UF-15 authors their physical
seams; their map IDs do not change.

| Map id | Source | Catalog `active` | Why it streams |
|---|---|---|---|
| `world.harju` | `world_harju.rrmap` | false | Nearby Harju village, reached by the Harju gate approach road |
| `world.sojamae` | `world_sojamae.rrmap` | false | Sõjamäe, reached from the Viru road junction |

Planned connectors (no source file yet, so they are outside the 29-map count):

| Planned map | Joins |
|---|---|
| planned: `kalamaja_hinterland` | `reval_harbor_east` landward edge |
| planned: `viru_approach_road` | `viru_gate_foreland` east edge to `pirita_road` and `sojamae_approach_road` |
| planned: `pirita_road` | Pirita valley |
| planned: `sojamae_approach_road` | Viru road junction to `world.sojamae` |
| planned: `harju_approach_road` | a Harju Gate on `south_quarter` (not yet authored) to `world.harju` |

### Interiors: in-place target (ADR 0028), door transition until migrated

[ADR 0028](adr/0028-seamless-building-interiors.md) makes walking into buildings
seamless: each interior becomes a building sub-package mounted inside its exterior
footprint, owned by the outdoor location, not a group member and not a seam. Until a
building passes its own migration (size reconciled, gates passed,
`world_host/inplace_interiors_enabled` on), it keeps today's door scene swap. No
interior code may merge before the maintainer names the ADR 0028 scope removal.

Every interior is currently 2.8-5.3 times larger in area than its exterior building,
so each migration starts by shrinking the interior or growing the exterior. Migration
order: `kalev_smithy` first, then `town_hall`.

| Map id | Source | Current behaviour and migration note |
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

Distant regions keep an explicit journey with a loading transition (maintainer,
2026-10-07). Membership, not the `world.` prefix, decides eligibility. A validator in
R-980 must reject a travel transition that is authored as a physical seam.

| Map id | Source |
|---|---|
| `world.saaremaa` | `world_saaremaa.rrmap` |
| `world.padise` | `world_padise.rrmap` |
| `world.paide` | `world_paide.rrmap` |
| `world.parnu` | `world_parnu.rrmap` |
| `world.poide` | `world_poide.rrmap` |
| `world.kanavere` | `world_kanavere.rrmap` |
| `world.sacred_grove` | `world_sacred_grove.rrmap` (retired, R-1529; regional site `scenes/world/sites/sacred_grove.tscn`) |
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
| `VERIFYING` | WorkerThreadPool task | `WorldHostPackageInspector.inspect()` of both detached packages (host-global nodes, stable handles) |
| `READY` | main thread | `mount_location(..., inspection)`: registry check, add to tree |

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
  takes ~14 ms (**R-1069**).
- An early mount must inspect the incomplete view on the main thread (~9 ms)
  (**R-1069**).
- A staged mount takes ~6.5 s from prefetch to ready on market and south. That
  is longer than the 48-cell band gives a running player (6.4 s), so running
  crossings miss (**R-1072** re-derives the band).
- One of eleven trace runs crashed (SIGSEGV) inside a worker pattern bake
  (`map_view_material_patterns.gd` `_pattern_image_at_size`) while mounts were
  staged. It did not reproduce in the next ten runs (**R-1070**; keep the flag
  off until it closes).

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

## Seam form continuity (UF-08 / R-1117)

Two different questions are gated separately:

| Gate | Question | Reads |
|------|----------|-------|
| `MapAlignmentMath` / `build_world_layout.gd` / `verify_world_layout.py` | Do the apertures have the same span and a consistent origin? (`MAP_WORLD_SEAM_SPAN_MISMATCH`, `MAP_WORLD_SEAM_ORIGIN_CONFLICT`) | Manifest and transitions |
| `tools/verify_seam_continuity.gd` | Does what is authored on either side of the aperture match? | Compiled `MapDefinition` of every group member |

The form gate compares, cell by cell along the shared edge: ground height (budget `height_delta`), road-surface runs (width, axis offset, surface, orphan ends), the nearest non-wall frontage face, and wall and ditch runs. It is a Godot tool rather than a Python verifier because heights and semantic records exist only in compiled `MapDefinition`; a Python reader would need a second export contract that could drift from the compiler. Until a compiled `StreetNetwork` exists (UF-03 / UF-05), a "street" is a run of cells whose terrain is listed in `street_terrains`.

Thresholds and the measured baseline live in `docs/data/seam_continuity_budget.json`. Each baseline failure has a `grace` entry naming its remediation row (R-1166). The gate is fail-closed: an unexplained violation fails, and a grace entry that no longer fires fails too, so fixes must delete their entry. It runs from `tools/run_pre_commit_checks.sh` (staged maps, manifest, `scripts/map`), `tools/run_map_pipeline_ci.sh seams`, and CI. Tests: `--filter=test_seam_continuity`.
