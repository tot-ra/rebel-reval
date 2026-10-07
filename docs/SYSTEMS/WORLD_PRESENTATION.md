# World presentation: the 3D view

Status: implemented. Scope: everything `MapView3D` draws on top of the authoritative 2D logic plane: camera, sky and weather, lighting, water and swimming, terrain and buildings, vegetation, fauna, crowds, and effects. This page indexes the subsystems and points to their contracts. Map data and authoring are in [`MAP_AUTHORING.md`](../MAP_AUTHORING.md); the logic/view boundary is in [`ARCHITECTURE.md`](../ARCHITECTURE.md#logic-and-3d-view-boundary).

## Principle

Gameplay runs on a flat orthogonal 2D logic plane ([ADR 0002](../adr/0002-orthogonal-three-quarter-perspective.md), [ADR 0007](../adr/0007-ai-generated-isometric-presentation.md)). The 3D view is derived, view-only output. `MapViewBridge` maps logic coordinates to 3D one way. View code never writes `GameState`, and ambient actors (animals, crowds) have no collision.

## Runtime and assembly

| Piece | File | Role |
|---|---|---|
| `MapViewRuntime` (+ `map_view_runtime_*.gd`) | `scripts/map/view3d/map_view_runtime.gd` | Hosts the view, time controls, environment binding, actors, ambient audio |
| `MapView3D` | `scripts/map/view3d/map_view_3d.gd` | Builds geometry, materials, lighting from the compiled `MapDefinition` |
| `MapViewAssembly`, `MapViewWorkerJob` | `scripts/map/view3d/` | Resumable, budgeted assembly queue with worker-thread jobs (WB-07) |
| `MapViewStaticBatcher` | `scripts/map/view3d/map_view_static_batcher.gd` | Batches never-animated geometry into fewer draw calls |
| `WorldHost`, `WorldHostStreamingDriver` | `scripts/world/` | Seamless additive streaming of contiguous outdoor locations ([ADR 0019](../adr/0019-seamless-contiguous-location-streaming.md), [`SEAMLESS_STREAMING_PLAN.md`](../SEAMLESS_STREAMING_PLAN.md)) |
| Chunking | — | [ADR 0010](../adr/0010-large-map-runtime-chunking.md), [`LARGE_MAP_CHUNKING_PLAN.md`](../LARGE_MAP_CHUNKING_PLAN.md) |

## Camera

Third-person by default ([ADR 0015](../adr/0015-default-third-person-camera.md)), optional first-person with mouse free-look ([ADR 0011](../adr/0011-optional-first-person-camera.md), [ADR 0012](../adr/0012-first-person-mouse-free-look.md)), and top-down. Cycle with **Camera [C]**. Modules: `map_view_runtime_camera*.gd` (modes, follow, orbit, zoom, perspective, safety against clipping, shake). Screen shake honors the accessibility setting. Controls: [`CONTROLS.md`](../CONTROLS.md#camera).

## Sky, weather, and light

- **Weather**: `clear`, `cloudy`, `overcast`, `rain`, `storm`, with blended transitions and an automatic deterministic cycle. `SkyWeatherState` is the scene-tree-free state saved with the game; `SkyWeather3D` renders it. Contract: [`SKY_WEATHER_STATE_CONTRACT.md`](../SKY_WEATHER_STATE_CONTRACT.md). Rain on roofs is `sky_weather_roof_audio.gd`.
- **Astronomy**: `SkyAstronomy` computes sun, moon, sidereal time, and tides for medieval Reval. Real stars come from `EstoniaStarCatalog`.
- **Atmosphere**: physically based sky-view LUT (`SkyAtmosphereLut`, `AtmosphereCpu`), screen-space cloud shadows (`cloud_shadow_pass.gd`), and volumetric-style god rays from sun or moon occluded by architecture (`god_ray_pass.gd`).
- **Lighting**: `MapViewLighting` owns the day/night response. Practical lights: forge fire, candles, domestic hearths, interior and building window glow (evening fade), chimney smoke driven by weather wind.
- Day/night clock and calendar: [`TIME_AND_PHASES.md`](./TIME_AND_PHASES.md#clock-and-calendar). Task specs: [`docs/tasks/water_sky/`](../tasks/water_sky/README.md).

## Water and swimming

- Sea: baked FFT ocean (`ocean_fft_sampler.gd` mirrors the shader on the CPU), whitecaps, caustics, shore swash, refraction, and GGX sun glint (`map_view_water_materials.gd`). Rivers follow an authored channel current that slows at the banks (`map_view_river_flow.gd`). Interactive ripples come from `water_ripple_sim.gd`.
- Sea depth is gradual. The WS-13b rendered basin shelves deep water down from the shallow-water depth over `SEA_BASIN_DEEP_RAMP_CELLS` (9) cells instead of stepping 1.0 → 3.6 units at the authored `shallow_water`/`deep_water` line (`_ramp_deep_basin_targets` in `map_view_mesh_builder_terrain.gd`). `MapView3D.sea_depth_image()` bakes that depth (one texel per cell) and `MapViewWaterMaterials.apply_sea_depth_map()` binds it to both sea materials, which then blend colour, absorption and wave parameters (`sea_wave_shallow`/`sea_wave_deep`) by depth. The depth is sampled in `vertex()`, because the fragment stage already uses all 16 GL Compatibility sampler units. The shared wave parameters also keep the two sea meshes' border vertices together, so no crack opens on the seam. Ground scatter (grass, plants, bushes) never grows on water cells. Gameplay is unchanged: the gameplay bed stays flat (ADR 0021).
- Moats and ponds (`TERRAIN_WATER`) are stagnant: `map_view_water_materials.gd` sets `pond_murk`/`pond_scum` and silty bed colours, and `map_view_water.gdshader` tints the column olive-brown, greens the mirrored sky, lays a drifting duckweed and leaf film, and fades a muddy shelf in at the bank. Banks need dry cells: `south_quarter` ditches stop two cells short of the map edge with a `south_wall.outer_bank` mud strip, because water cut by the map edge has no shore ramp. The ditches are also real cuts: `relief_ditch south_wall.cut.*` / `east_wall.cut` (width 10, depth 1.2) sink the water below the surrounding ground and slope the banks, which carry `south_wall.bank_grass` turf instead of bare mud. Plate: `tools/godot_render.sh --script tools/capture_moat_water.gd -- --label after` ([gameplay](../reports/images/moat_water_gameplay_after.png), [close](../reports/images/moat_water_close_after.png)).
- Rain on water is drawn by `map_view_water.gdshader` as centimetre-scale procedural rings (`rain_ring_intensity`, set by `apply_sea_weather`). The rings fade out before their cells shrink to a few pixels, so they do not alias into moire. The ripple sim no longer takes rain, because its 25 cm texels turned drops into metre-wide rings that stopped at the 64-unit window edge. The underwater wet-lens drops are small and sparse (16 rows, about 40% of cells).
- Visual wind is slewed: `SkyWeather3D` follows the weather/gust wind target at <=1.5 deg/s for heading and an 8 s low-pass for cloud-drift strength (`_advance_wind_smoothing`). The sea rotates its whole wave field with the wind heading, so an unbounded heading swing during a weather transition made the water and cirrus visibly race.
- Boats and cogs float on the same wave field and heel into the wind (`boat_float_3d.gd`).
- Boats are solid (task **R-1214**). The inshore fishing boat (`map_view_fishing_boat_builder.gd`) is a ~5.2 m four-oared clinker hull scaled against the 2-unit actor, with bottom boards above the waterline and an inner shell so the sea never shows inside, and oars shipped fore-and-aft on the thwarts. Because ADR 0021 lets Kalev wade and swim, `MapSceneBootstrap._create_boat_blocks` adds one `CapsuleShape2D` per `fishing_boat` / `merchant_boat` prop on `CollisionLayers.WORLD` (body `BoatBlocks`, group `map_boat_collision`), sized from each builder's `HULL_HALF_LENGTH` / `HULL_HALF_BEAM` and turned like the 3D hull. Navigation is unchanged. `BoatFloat3D.configure` takes the same hull extents so wave sampling spans the real bow and stern. Verify with `--filter=test_boat_collision,test_map_view_fishing_boat,test_boat_float_3d` and `tools/godot_render.sh --rendering-method mobile --rendering-driver metal --script tools/capture_ws05_boat_waterline.gd -- --boat=kalamaja` ([plate](../reports/images/ws05_metal_clear_kalamaja_clip.png)). Limits: the capsule is static at the rest pose (float heave and surge are view-only), and boats cannot be boarded.
- Swimming and diving ([ADR 0021](../adr/0021-swimming-and-diving.md)): walk → wade → swim → dive is a pure function of water depth plus the dive input (`PlayerSwimState`, `PlayerWaterTraversal`). `MapViewSwimmerPresenter` poses the rig; `underwater_pass.gd` renders the underwater view. While diving, the third-person boom shortens to `CAMERA_DIVE_BOOM_SCALE` (0.5), so the diver stays visible through underwater extinction. Over open sea, camera safety (`MapViewRuntimeCameraSafety.rendered_floor_height`) clamps the lens to the rendered basin bed, not the flat gameplay bed, so the camera can follow a diver below the surface. Verify with `--filter=test_ws13b_sea_basin_depth` and `tools/godot_render.sh --script tools/capture_swim.gd -- --out=build/swim --weather=rain`.
- Coast work: [`docs/tasks/coast/`](../tasks/coast/README.md).

## Terrain, streets, and buildings

- Continuous terrain mesh with relief ([ADR 0023](../adr/0023-terrain-relief-as-gameplay.md)), baked paving and stone patterns (`map_view_material_patterns.gd`, `map_view_terrain_materials.gd`), living ground cover (`map_view_terrain_details.gd`), wear and grime decals (`map_view_decals.gd`), and rain-soft mud footprints (`mud_footprints_3d.gd`).
- Streets are an authored network ([ADR 0026](../adr/0026-streets-as-authored-network.md); [`docs/tasks/urban_form/`](../tasks/urban_form/README.md)).
- Buildings come from `map_view_mesh_builder_*.gd` (houses, churches, fortifications, landmarks, interiors) and hand-built landmark models such as the 1343 Town Hall (`map_view_town_hall_model.gd`). Pipeline: [ADR 0025](../adr/0025-architectural-asset-pipeline.md), [`docs/tasks/architecture/`](../tasks/architecture/README.md), [`ASSET_INVENTORY.md`](../ASSET_INVENTORY.md). Materials: [`MATERIAL_STYLE_LOCK_KIT.md`](../MATERIAL_STYLE_LOCK_KIT.md), [`TEXTURE_AI_GENERATION.md`](../TEXTURE_AI_GENERATION.md).
- Fog of war: `map_fog_of_war.gd` remembers explored areas in the orthographic view.
- Public draw-well (`well` prop kind): `map_view_well_models.gd` builds coursed limestone slabs with recessed mortar, a ring of curb slabs, a log windlass on an iron axle and crank, hemp rope wound on the drum and slack to a tinned-iron bucket on the curb, and an old-board gable roof. The shaft mouth is a disc drawn by `map_view_well_shaft.gdshader`: it ray-traces a virtual 3 m shaft that darkens with depth and ends in still water, because the opaque terrain hides real geometry below ground. View-only: the map definition still owns the footprint. Check with `godot --headless --path . --script tools/smoke_well_model.gd` and the captures from `tools/godot_render.sh --script tools/capture_well_preview.gd` (`build/previews/well_preview*.png`).

## Vegetation

Estonian trees, bushes, and plants by species (`map_view_tree_species.gd`, `map_view_bush_species.gd`, `map_view_plant_species.gd`) with fractal growth profiles and wind materials. Species reference: [`FLORA_FAUNA.md`](../FLORA_FAUNA.md). Seasonal crowns, rain and wind response, and leaf fall on weapon hits: [`LIVING_VEGETATION.md`](./LIVING_VEGETATION.md).

**Scatter exclusions.** Ground scatter (grass tufts, plants, bushes, scatter trees) is view-only: `map_view_mesh_builder_scatter.gd` walks the terrain cells of a `MapDefinition` and skips any cell that `MapViewMeshBuilderPrimitives.cell_blocked` reports. Blocked cells come from building footprints (`building_cell_rects`) plus solid props (`prop_cell_rects`): wash tubs, wells, barrels, stalls, carts, crates, trade goods and pallets, splitting tables, bales, sack and keg piles, staves, firewood, hay, tables, forge-yard anvils, charcoal and iron scrap piles, harbour salt piles, rope coils and boat timber stacks, and farm hay wagons, farm carts, root cellar mounds, privies and well sweeps, listed in `SCATTER_BLOCKING_PROP_KINDS`. Flat or soft props (fences, fields, plots, animals) and open-legged frames (fish, smoke and herb drying racks, tanning frames) stay out of the list so verges keep their planting under them. Interior-only kinds (bed, shelf, hearth, chest) need no entry: `begin_scatter` returns early and ground cover is skipped when `suppresses_exterior_surroundings()` is true. Prop footprints and positions are authored in logic units; a prop with no rect claims the single cell around its position. The same exclusion runs for the dense first-person ground cover in `map_view_terrain_details.gd`, so the eye-level layer that produced the original tuft-through-basin defect is covered too. Verify with `--filter=test_vegetation_prop_exclusion` (the exclusion contract, both layers, a red/green meadow run per added forge/harbour/farm kind, the open-frame soft list, and a map-level guard on `market_civic_quarter`) plus `--filter=test_market_prototype_maps` (`test_market_civic_quarter_tufts_avoid_prop_footprints`) and the eye-level plates from `tools/godot_render.sh --script tools/capture_forum_prop_vegetation.gd` (`docs/reports/images/forum_prop_vegetation_*.png` for the forum, `yard_prop_vegetation_*.png` for the `world_padise` forge yard).

## Fauna and crowds

- **Birds**: species catalog (corvid, gull, owl, raptor, songbird, swallow, tern, wader, waterfowl, woodpecker), flapping flight with V-formation flocks ([Bird flight](../FLORA_FAUNA.md#bird-flight)), and ambient song (`map_view_bird_*.gd`).
- **Mammals**: urban cats and dogs with hunt/play/groom cycles (`map_view_urban_fauna.gd`, `map_view_companion_intent.gd`), penned livestock and wild-margin mammals (`map_view_penned_fauna.gd`), shared waypoint walking (`map_view_ground_wander.gd`).
- **Insects**: grasshopper and cricket stridulation ambience (`map_view_insect_*.gd`).
- **Crowds**: `map_view_crowd_renderer.gd` draws the urban population ([`WORLD_LIFE.md`](./WORLD_LIFE.md#urban-population)).
- Species reference and sourcing: [`FLORA_FAUNA.md`](../FLORA_FAUNA.md); asset rows in `assets/SOURCES.csv`.

## Characters

Human rigs, wardrobe, and the crowd shader: [`CHARACTER_GENERATION.md`](../CHARACTER_GENERATION.md) ([ADR 0022](../adr/0022-realistic-human-characters.md), [ADR 0016](../adr/0016-tiered-character-fidelity.md)). Fidelity backlog: [`VISUAL_FIDELITY_PLAN.md`](../VISUAL_FIDELITY_PLAN.md), [`CHARACTER_REALISM_BACKLOG.md`](../CHARACTER_REALISM_BACKLOG.md).

## Effects

Magic VFX (`map_view_magic_vfx.gd`, [`MAGIC.md`](./MAGIC.md)), forge flame, candle flame, chimney smoke, transition markers, climbable props, and wall-walk access.

Wooden direction signs do not exist: the `direction_sign` primitive and the rrmap `sign` statement were retired ([ADR 0030](../adr/0030-retire-direction-sign-primitive.md)) so the town reads without game-UI waymarks.

## Verify

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_map_view
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_sky_weather
tools/run_performance_report.sh build/benchmarks/performance-smoke.json --quick
```

Visual changes need captures through `tools/godot_render.sh` and the gate in [`WORLD_BUILDING_VISUAL_GATE.md`](../WORLD_BUILDING_VISUAL_GATE.md).

## Limits

- `ProceduralChickenModel`, `MapViewEnvironmentKit`, and `MapViewNunnatornInterior` are referenced only by tests and tools. See the [code-health audit](../reports/code_health_audit_2026-10-07.md).
