# ADR 0019: Stream contiguous outdoor locations through a persistent world host

**Reference:** seamless traversal feasibility follow-up to ADR 0009 and ADR 0010
**Recorded:** 2026-07-30
**Engine:** Godot 4.7, GL Compatibility
**Primary evidence:** [`large_map_chunking_baseline.md`](../reports/large_map_chunking_baseline.md), [`LARGE_MAP_CHUNKING_PLAN.md`](../LARGE_MAP_CHUNKING_PLAN.md), and the current map runtime

## Status

Proposed target architecture for contiguous outdoor Reval locations. This ADR records the completed feasibility study and recommended implementation direction; it does not enable runtime behavior. Adoption requires maintainer approval, and implementation must ship behind a disabled feature flag until the acceptance gates below pass. Interiors, long-distance travel locations, scripted battles, and teleports retain explicit transitions.

## Question and answer

Can independently authored map files load gradually while the player keeps moving, without a visible location-change wait?

**Yes, with an architectural change.** The existing `.rrmap` files can remain separate authoring and packaging units. The game must stop treating each outdoor location as the complete `SceneTree.current_scene` and instead keep one persistent world host alive while it attaches and evicts location and chunk packages around the player.

Calling `ResourceLoader.load_threaded_request()` before the current door transition is useful but insufficient. It can hide resource I/O, but the current transition still synchronously builds the target `MapDefinition`, complete terrain grid, whole-location navigation, collisions, and much of the 3D presentation after the scene enters the tree.

This decision targets a seamless **contiguous outdoor world group**, initially the physically adjacent Reval districts and harbours. It does not turn the campaign's distant Estonia travel graph into a continuous open world. Transitions marked `alignment=travel` stay non-physical and continue to use authored travel flow.

## Current state

The project already contains most of the low-level foundations, but not the cross-location lifecycle.

| Existing component | Useful foundation | Gap that still creates a seam |
|---|---|---|
| `.rrmap` -> `MapBlueprint` -> `MapDefinition` | Separate semantic map files, stable IDs, deterministic fingerprints | Each definition uses location-local coordinates starting at `(0, 0)` and has no persistent world origin |
| `MapTerrainRenderer` | Loads and unloads 32 x 32 terrain draw chunks around a focus | It consumes a terrain grid built for the complete current location; 2D presentation is later hidden by the 3D runtime |
| `MapObjectChunkStreamer` | Stable-ID owner/consumer lifecycle for buildings and props | Its index and chunk coordinates are scoped to one `MapDefinition`; persistent records load for that whole location |
| `MapView3D` | Streams building, prop, scatter, and detail chunks | `_assemble()` still builds whole-location surroundings, terrain, height field, interior shell, decals, transition visuals, sky, and lighting synchronously |
| `MapNavBuilder` | Deterministic authoritative 2D navigation | It bakes one navigation polygon for the complete location on the calling thread |
| `MapSceneBootstrap` | Central assembly point for terrain, objects, doors, navigation, bounds, water collision, and HUD | It creates complete map-edge walls and whole-location water collision, then installs map-local gameplay systems |
| `DoorNavigator` | Stable scene/spawn manifest and an LRU `PackedScene` cache | `_get_scene_resource()` uses blocking `load()`, then `change_scene_to_packed()` destroys the old scene; caching does not avoid target `_ready()` assembly |
| `MapStableStateStore` | Save identity is already `{location_id, object_id}` plus global cell/sub-cell data, independent of chunk IDs | Runtime hydration and dehydration are not yet connected to cross-location residency |
| `MapAlignmentMath` | Computes deterministic offsets from reciprocal edge transitions, rejects `alignment=travel`, checks cycles and seam spans | Offsets are temporary editor workspace state, not an authored or built runtime world-layout contract |

The recorded Lower Town baseline measured about **20 ms** for compact compilation, terrain, 2D assembly, and navigation together, but about **2.93 seconds** for full production scene startup under the headless dummy renderer. The report identifies synchronous 3D construction as the dominant startup cost. Therefore background-loading only the `.tscn` cannot provide the requested result.

## Decision

### 1. Keep maps separate, add a world-layout contract

`.rrmap` remains the authoritative location source. Do not merge district files and do not author chunk IDs.

Add a small built world-layout manifest for each physically contiguous world group. Each location record must contain at least:

- stable `world_group_id` and `location_id`;
- source/package path and fingerprint;
- signed `origin_cell` in the group's canonical global cell space;
- local size, cell size, and global half-open bounds;
- reciprocal physical seam records and transition spans;
- whether the location is outdoor-streamed, interior, or long-distance travel;
- coarse LOD/proxy and dependency metadata when available.

`origin_cell` is world layout, not location content and not chunk identity. It may be generated from reciprocal transitions using the existing alignment math, but the generated artifact must be deterministic, reviewable, checked for cycle conflicts, and fingerprinted. Runtime must not invent a new layout depending on load order.

All locations in one seamless group must use the same cell size. Physical seams must be reciprocal, on opposite edges, width-compatible, and free of overlapping solid boundaries. `alignment=travel` transitions are excluded.

### 2. Introduce one persistent `WorldHost`

The seamless world group runs under one long-lived host that owns exactly one instance of each global concern:

- player logic body and 3D player rig;
- gameplay camera and camera controller;
- `WorldEnvironment`, sky, weather, sun, and day/night clock;
- HUD, minimap facade, input, music director binding, and save/session binding;
- global world-streaming scheduler and stable-handle resolver;
- one authoritative 2D navigation map.

Loaded locations become disposable children under `LogicLocations` and `ViewLocations`. A location package must not create another player, camera, environment, HUD, or copy of world-global controllers.

The existing playable location scenes remain compatibility entry points during migration. They should eventually become thin launch adapters that ask `WorldHost` to enter a location instead of being the location's runtime ownership boundary.

### 3. Preserve global authority, apply location transforms only at package boundaries

Authored coordinates remain local to each `.rrmap`. At compilation/package extraction, convert them with:

```text
global_cell = origin_cell + local_cell
global_logic_position = global_cell * cell_size + sub_cell_offset
```

Stable save handles remain `{location_id, object_id}`. Chunk coordinates remain derived cache hints from signed global cells and never enter authored IDs or save authority.

The first Reval implementation does not need floating-origin rebasing. If a later seamless group becomes large enough to lose rendering precision, rebasing may occur only at the view boundary as already allowed by ADR 0010. Logic coordinates, routing, saves, and stable IDs remain global and unchanged.

### 4. Use a staged, priority-driven streaming lifecycle

Each package or chunk moves through explicit states:

```text
UNLOADED -> REQUESTED -> DATA_READY -> ATTACHING
         -> PHYSICS_READY -> VISUAL_READY -> ACTIVE
         -> EVICTING -> UNLOADED
```

Priorities are based on predicted player motion, distance, camera visibility, route intent, and seam proximity. The scheduler must request content ahead of the current resident ring, not only after the player crosses a map boundary.

Activation order is safety-first:

1. metadata and global index;
2. core terrain semantics and stable state hydration;
3. collision, seam aperture, and local navigation region;
4. interaction/gameplay owners and nearby dynamic actors;
5. terrain and structure LOD needed to cover the camera;
6. decorative props, scatter, decals, fauna, audio emitters, and high-detail LOD.

Eviction reverses this order after hysteresis. The current 32-cell chunk size, one-chunk simulation radius, two-chunk resident radius, and three-chunk 3D view radius remain starting values, but the scheduler operates in global chunk coordinates across location boundaries.

### 5. Split background preparation from main-thread activation

Use Godot's threading within its documented constraints:

- `ResourceLoader.load_threaded_request()` may prefetch imported textures, meshes, audio, and packaged resources.
- A single worker pipeline may parse/compile pure map data or prepare immutable arrays, provided it does not touch the active scene tree or mutate shared resources.
- Runtime `.rrmap` parsing cannot depend on the current `RrmapResourceFormatLoader`, because that loader is registered by an editor plugin. Prefer an offline-generated, fingerprinted runtime package resource or cache. Direct parser fallback may remain for editor/developer builds.
- Navigation source data and tile baking should use background work supported by Godot, then publish regions to the common navigation map.
- Node attachment, physics registration, render-resource creation that requires the active servers, and final visibility changes stay on the main thread.
- Main-thread activation must be sliced by measured work units and stop when the per-frame streaming budget is exhausted.

Do not enable Godot's separate render-thread model merely to make this feature possible. The official documentation notes known issues, and the project should not depend on off-thread `MeshInstance3D` or texture creation being safe. Prefer prebuilt resources, immutable data preparation, and bounded main-thread attachment.

### 6. Stream navigation, collision, and boundaries by global chunk

Replace whole-location navigation bakes with `NavigationRegion2D` tiles covering a 32 x 32 core plus the ADR 0010 two-cell overlap. All active regions contribute to the same navigation map. Reciprocal border portals or links must be deterministic and width/clearance validated.

Replace complete map-edge walls with boundary segments. Physical seams omit the matching wall segment once the destination's collision and navigation are ready. Non-connected edges remain blocked.

Water and static collision must be generated per resident chunk, not for the complete location. Owner/consumer rules remain authoritative so a structure crossing a chunk or location seam has one collision owner and no duplicate gameplay instance.

The player must never enter a chunk before its authoritative collision and navigation state is ready. Visual decoration may arrive later without blocking movement.

### 7. Keep simulation and presentation residency distinct

Only the near simulation ring runs NPC AI, encounters, physics, and interactive state. A wider visual ring may show terrain, landmarks, and simplified static structures. Outside both rings, the stable state store and coarse world index represent the location without scene nodes.

Quest and phase controllers must be split into session-level state and location-resident presenters. Unloading a location must not reset quests, schedules, market state, time, weather, or consequences. Dynamic entities dehydrate into `MapStableStateStore` before their owner chunk leaves simulation residency and hydrate exactly once when it returns.

Audio, fauna, crowd, fog, minimap, and music systems currently configured from one `MapDefinition` need world-aware inputs. Crossfades must be driven by global zones. Only nearby location presenters may emit sound or simulation actors.

### 8. Preserve explicit transitions where they improve the product

The following remain explicit or masked transitions:

- building interiors such as Kalev's smithy, unless a later interior-specific streaming decision replaces them;
- distant campaign locations connected by travel time and authored travel events;
- scripted battles or cutscenes that intentionally reset staging;
- fast travel and teleport to a destination outside the resident/prefetch envelope.

An interior door can still prefetch while its opening animation plays, but that is latency hiding rather than an outdoor seamless seam.

## What "no waiting" means

No streaming system can mathematically guarantee zero waiting on every storage device, mod set, or unsupported machine. The shippable contract is:

- normal traversal on supported minimum hardware has no loading screen, scene swap, player teleport, or visible empty seam;
- collision/navigation needed for the next reachable area is ready before the player can enter it;
- lower-priority visuals degrade to LOD or arrive progressively rather than stopping gameplay;
- a missed hard-readiness deadline is a measured defect, not a reason to expose unloaded space.

The fallback order is: retain coarse proxy visuals, postpone decoration, retain the current resident ring longer, then hold the closed seam aperture only as a last-resort safety fallback. Release acceptance requires that the last fallback not occur during normal traversal on supported minimum hardware.

## Migration plan

### Phase 0 - Measure the current seam

Instrument `DoorNavigator`, source scene exit, target resource load, target `_ready()`, terrain/grid build, navigation bake, first physics-ready frame, and first fully covered rendered frame. Capture Workers' District <-> Central District in both directions on the development and minimum-hardware targets.

### Phase 1 - Freeze and validate global layout

Extract the pure alignment math from the editor addon into a runtime-neutral module reused by the editor. Generate a Reval layout manifest with explicit global origins. Add validation for reciprocal seams, opposite sides, equal cell size, width and clearance, cycle consistency, non-travel exclusion, global bounds, and duplicate stable handles.

### Phase 2 - Prove additive residency with two locations

Create a feature-flagged `WorldHost` prototype for Workers' District and Central District. Keep one player/camera/environment and mount two data-only location roots at their global offsets. Cross the seam without `change_scene_to_packed()` and without teleporting the player. This phase may keep both locations fully resident and exists to prove ownership boundaries first.

### Phase 3 - Add package lifecycle and background prefetch

Create a runtime package catalog and staged loader. Start prefetch from distance and movement direction. Add cancellation, priority changes, hysteresis, memory accounting, and deterministic state transitions. Keep main-thread work below the existing 4 ms per-frame streaming budget.

### Phase 4 - Make authoritative geometry chunk-resident

Move terrain build, water/static collision, map bounds, navigation regions, transitions, and interaction owners to global chunks. Connect cross-seam navigation and ensure unloaded edges remain physically safe.

### Phase 5 - Finish 3D chunking

Replace whole-location terrain, height-field, surroundings, decals, transition visuals, and other remaining `_assemble()` work with chunk or world-group owners. Reuse materials/resources and add LOD0/LOD1/coarse proxies. Eliminate visible duplicate surroundings at internal district seams.

### Phase 6 - Migrate location systems and persistence

Make NPCs, quests, phases, fauna, crowd, audio, fog, minimap, and music respond to simulation/view residency. Prove unload/save/load/reload identity and no duplicate dynamic entity after repeated crossings.

### Phase 7 - Roll out one outdoor world group

Enable seamless mode for the connected Reval outdoor graph after performance, soak, save, and visual gates pass. Keep the old scene transition path as a feature-flag fallback for at least one save-version cycle. Evaluate Pirita and other physically contiguous outskirts separately. Do not silently include long-distance world travel.

## Acceptance gates

All gates apply in both directions across at least one real district seam and then across a route containing at least three seams.

### Functional continuity

- No call to `SceneTree.change_scene_to_packed()` occurs for a seamless edge transition.
- The same player instance, camera, session state, day/night clock, and weather instance survive the crossing.
- Player global logic position and velocity are continuous within 0.01 logic units; there is no spawn relocation.
- Cross-seam keyboard movement and click navigation both work before and after repeated load/unload.
- A stable object or dynamic entity exists at most once across owner and consumer packages.
- Saving on either side of a seam and reloading restores the same location, global cell/sub-cell position, object deltas, and quest state.
- `alignment=travel` destinations never enter the physical seamless layout.

### Visual and audio continuity

- The camera never reveals missing terrain, an internal surroundings skirt, duplicate wall, lighting reset, sky reset, or one-frame location flash.
- Terrain elevation, water contour, roads, walls, and transition aperture meet at the authored seam within the agreed geometric tolerance.
- Location ambience and music crossfade without duplicate world-global emitters.
- Lower-detail visuals may refine after activation, but no placeholder may alter collision or interaction truth.

### Performance and residency

Use the executable budgets in `tools/benchmarks/large_map_benchmark_config.json` unless a later measured ADR changes them:

- main-thread streaming work <= 4 ms per frame;
- steady frame p95 <= 16.67 ms and p99 <= 25 ms;
- resident nodes <= 7,500;
- resident collision shapes <= 900;
- resident static memory delta <= 280 MiB;
- one 32 x 32 chunk activation <= 50 ms p95 in its full staged pipeline;
- one overlapped navigation tile bake <= 25 ms p95;
- a 30-minute seam-crossing soak returns node/RID counts to the documented cache baseline and shows no monotonic memory growth.

Add an artificial delayed-I/O test. It must prove that low-priority visuals defer first, authoritative unloaded space is never exposed, and the readiness miss is recorded with package/chunk diagnostics.

## Rejected alternatives

### Keep full scene swaps but load the target `PackedScene` in a thread

Rejected as the final design. It reduces resource I/O stalls but still replaces the scene and synchronously executes target assembly. It cannot provide continuous player, camera, physics, navigation, or world coordinates.

### Add two existing playable scenes to the tree at once

Rejected. Current scenes each own a player, map-local runtime, camera/environment-related setup, HUD, bounds, controllers, and `_ready()` assembly. Additive loading them unchanged would duplicate authority and still build too much content.

### Merge all Reval `.rrmap` files into one giant map

Rejected. It worsens authoring, review, merge conflicts, fingerprints, package invalidation, and whole-map preprocessing. Separate semantic locations plus a global runtime layout provide the requested traversal without sacrificing modular files.

### Parse and instantiate all content on arbitrary worker threads

Rejected. The active scene tree is not thread-safe, rendering-node creation is not thread-safe by default, and shared resources can race. Use one controlled data-preparation pipeline and budgeted main-thread publication.

### Make all campaign travel a seamless overworld

Rejected for this decision. It conflicts with the authored travel-event layer, current campaign scope, and the explicit `alignment=travel` contract. A future product decision may revisit world scale, but it must not be smuggled into district streaming.

## Consequences

### Positive

- Outdoor traversal can become continuous while maps remain independent files.
- Existing stable IDs, fingerprints, chunk math, persistence envelope, alignment tooling, and much of object/scatter streaming remain useful.
- The same world host removes repeated camera, weather, clock, HUD, and player initialization.
- Runtime work scales with the resident envelope rather than total world-group size.

### Costs and risks

- This is a runtime ownership refactor, not a one-line asynchronous loading change.
- Existing location scripts mix world-global, location-global, and chunk-local responsibilities and must be separated incrementally.
- Terrain height generation, navigation, collision, surroundings, minimap, audio, and quest presenters all need chunk/world-aware contracts.
- Poor prefetch distance or unbounded main-thread attachment can reintroduce hitches even after background I/O works.
- Seam geometry that only looks aligned in the editor may still fail collision, elevation, water, or navigation continuity and needs automated validation.

## Godot documentation references

- [Background loading](https://docs.godotengine.org/en/latest/tutorials/io/background_loading.html) - threaded resource requests, status polling, and the warning that `load_threaded_get()` blocks if called before completion.
- [Thread-safe APIs](https://docs.godotengine.org/en/latest/tutorials/performance/thread_safe_apis.html) - the active scene tree is not thread-safe; off-tree preparation is limited and rendering-resource work needs care.
- [Using NavigationRegions](https://docs.godotengine.org/en/latest/tutorials/navigation/navigation_using_navigationregions.html) - multiple regions contribute to a combined navigation map and may be enabled or disabled.
- [Optimizing Navigation Performance](https://docs.godotengine.org/en/latest/tutorials/navigation/navigation_optimizing_performance.html) - runtime navigation baking should use background work and simple source geometry.
