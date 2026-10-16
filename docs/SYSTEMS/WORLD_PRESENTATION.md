# World presentation: the 3D view

Status: implemented. Scope: everything `MapView3D` draws on top of the authoritative 2D logic plane: camera, sky and weather, lighting, water and swimming, terrain and buildings, vegetation, fauna, crowds, and effects. This page is an index: it names the subsystems and links the page that owns each one. Put new detail on the owning page, not here. Map data and authoring are in [`MAP_AUTHORING.md`](../MAP_AUTHORING.md); the logic/view boundary is in [`ARCHITECTURE.md`](../ARCHITECTURE.md#logic-and-3d-view-boundary).

## Principle

Gameplay runs on a flat orthogonal 2D logic plane ([ADR 0002](../adr/0002-orthogonal-three-quarter-perspective.md), [ADR 0007](../adr/0007-ai-generated-isometric-presentation.md)). The 3D view is derived, view-only output. `MapViewBridge` maps logic coordinates to 3D one way. View code never writes `GameState`, and ambient actors (animals, crowds) have no collision.

## Runtime and assembly

| Piece | File | Role |
|---|---|---|
| `MapViewRuntime` (+ `map_view_runtime_*.gd`) | `scripts/map/view3d/map_view_runtime.gd` | Hosts the view, time controls, environment binding, actors, ambient audio |
| `MapView3D` | `scripts/map/view3d/map_view_3d.gd` | Builds geometry, materials, lighting from the compiled `MapDefinition` |
| `MapViewAssembly`, `MapViewWorkerJob` | `scripts/map/view3d/` | Resumable, budgeted assembly queue with worker-thread jobs (WB-07) |
| `MapViewStaticBatcher` | `scripts/map/view3d/map_view_static_batcher.gd` | Batches never-animated geometry into fewer draw calls |
| `WorldHost`, `WorldHostStreamingDriver`, `WorldHostResidency` (pure residency policy), `WorldHostHandles` (stable-handle discovery) | `scripts/world/` | Seamless additive streaming of contiguous outdoor locations ([ADR 0019](../adr/0019-seamless-contiguous-location-streaming.md), [`SEAMLESS_STREAMING_PLAN.md`](../SEAMLESS_STREAMING_PLAN.md)) |
| Chunking | — | [ADR 0010](../adr/0010-large-map-runtime-chunking.md), [`LARGE_MAP_CHUNKING_PLAN.md`](../LARGE_MAP_CHUNKING_PLAN.md) |

## Camera

Third-person by default ([ADR 0015](../adr/0015-default-third-person-camera.md)), optional first-person with mouse free-look ([ADR 0011](../adr/0011-optional-first-person-camera.md), [ADR 0012](../adr/0012-first-person-mouse-free-look.md)), and top-down. Cycle with **Camera [C]**. Modules: `map_view_runtime_camera*.gd` (modes, follow, orbit, zoom, perspective, safety against clipping, shake). Screen shake honors the accessibility setting. Controls: [`CONTROLS.md`](../CONTROLS.md#camera).

Anti-clipping (`map_view_runtime_camera_follow.gd`, `map_view_runtime_camera_safety.gd`): the follow lerp runs on an unconstrained boom position, and the wall pull-out, ground clamp, and line-of-sight pull-in are judged on that position every frame, then applied on top of it. A push toward Kalev applies at once; a shrinking push eases out (`SAFETY_RELAX_WEIGHT`), and the ground clamp is re-applied after easing. Lerping from the corrected lens, or judging contact on last frame's corrected lens, made the camera fight its own correction and shake near walls and slopes. Verify: `test_map_view_runtime_camera.gd::test_third_person_lens_does_not_reenter_a_wall_while_gliding_out`. Limits: the occluders are box AABBs, so a lens grazing a box corner can still pop to the nearest face.

## Sky, weather, and light

- **Weather**: `cloudless` (R-1495), `clear` (fair cumulus), `cloudy`, `overcast`, `rain`, `storm`, with blended transitions and odds tuned to Tallinn in spring (see [`SKY_ATMOSPHERE.md`](SKY_ATMOSPHERE.md#weather-and-the-look-of-the-sky)) and an automatic deterministic cycle. `SkyWeatherState` is the scene-tree-free state saved with the game; `SkyWeather3D` renders it. Contract: [`SKY_WEATHER_STATE_CONTRACT.md`](../SKY_WEATHER_STATE_CONTRACT.md). Rain on roofs is `sky_weather_roof_audio.gd`.
- **Astronomy**: `SkyAstronomy` computes sun, moon, sidereal time, and tides for medieval Reval. Real stars come from `EstoniaStarCatalog`.
- **Atmosphere**: physically based sky-view LUT (`SkyAtmosphereLut`, `AtmosphereCpu`), screen-space cloud shadows (`cloud_shadow_pass.gd`), and volumetric-style god rays from sun or moon occluded by architecture and shaded by the cloud deck and cells, with crepuscular rays in the sky dome (`god_ray_pass.gd`, R-1444).
- **No pillar over a low sun** (R-1607): the horizon colour the dome reuses for a whole vertical column (cloud ambient, overcast tint, cloud haze, below-horizon fade) is looked up at least ~25 degrees off the sun's azimuth (`sky_lut_horizon_radiance` in `sky_weather_3d.gdshader`). Sampled at the sun's azimuth it carried the Mie aureole, which stretched into a narrow vertical beam converging at the zenith. Guarded by `test_sky_horizon_pillar`.
- **No white dome under a low sun** (R-1608): with the sun 10-16 degrees up the clear sky around and below the sun blew out to white over a third of the frame (Mobile renderer, any HDR gain). No single term explodes. The sky-view LUT's sun-side horizon grows from 7.6x the zenith at noon to 28x at 16 degrees and 60x at 7 degrees (Mie forward scatter along the long horizon path, physically right), and two lifts keyed to other things multiply it: the zenith-keyed `sky_adaptation` gain (1.13 at noon, 1.55 at 16 degrees, 1.93 at 7 degrees) and `MapViewLighting.low_sun_exposure_factor` (1.0, 1.23, 1.30). Bisected with `tools/probe_hdr_output.gd --sun-map=smithy_courtyard`: zeroing adaptation, the low-sun lift, the flare, fog or glow alone leaves the dome; zeroing the LUT removes it. The fix is `sky_highlight_shoulder()` in `atmosphere_common.gdshaderinc`: the exposed LUT background (art exposure x adaptation) keeps its luminance up to `SKY_HIGHLIGHT_KNEE` (0.7, about the brightest noon sky) and rolls off towards `SKY_HIGHLIGHT_CAP` (1.0) above it, hue kept. The dome and the water's sky reflection both use it, so the water does not mirror a brighter horizon. The sun disk, corona and halo are added afterwards and keep their EDR range (R-1537). Result on an SDR screen: at progress 0.73 only the disk exceeds UI white, at 0.76 a small warm glow hugs the sun instead of a dome; noon is unchanged. Before/after: [`r1608_low_sun_sky_dome.png`](../reports/images/r1608_low_sun_sky_dome.png). Guarded by `test_sky_low_sun_shoulder`. Limit: the zenith adaptation and the low-sun tonemap lift still double-count at a low sun; the shoulder bounds only the bright band.
- **Cloud cells**: individual world-space cumulus and cumulonimbus (`CloudCells`) that the dome ray-marches, that cast their own ground shadows and cut god rays, and that are the only source of lightning. See [`SKY_ATMOSPHERE.md`](./SKY_ATMOSPHERE.md).
- **Local atmosphere**: patchy ground fog near water with its own lighting, perspective-only distance haze and a midsummer heat mirage, all driven by the same presentation snapshot. See [`SKY_ATMOSPHERE.md`](./SKY_ATMOSPHERE.md).
- **Lighting**: `MapViewLighting` owns the day/night response. Practical lights: forge fire, candles, domestic hearths, interior and building window glow (evening fade), chimney smoke driven by weather wind.
- **Forge fire** on the smithy hearth: [`OBJECT_CATALOG.md`](./OBJECT_CATALOG.md#forge-fire-objhearth_smithy).
- Day/night clock and calendar: [`TIME_AND_PHASES.md`](./TIME_AND_PHASES.md#clock-and-calendar). Task specs: [`docs/tasks/water_sky/`](../tasks/water_sky/README.md).

## Water and swimming

Sea, rivers, moats and ponds, rain on water, floating and solid boats, swimming and diving: [`CITY_SEA.md`](./CITY_SEA.md#district-map-water-boats-and-swimming) (district maps) and the rest of that page (seamless city). Swimming rules: [ADR 0021](../adr/0021-swimming-and-diving.md). The cog: [`SHIPS.md`](./SHIPS.md).

## Terrain, streets, and buildings

- Continuous terrain mesh with relief ([ADR 0023](../adr/0023-terrain-relief-as-gameplay.md)), baked paving and stone patterns (`map_view_material_patterns.gd`, `map_view_terrain_materials.gd`), living ground cover (`map_view_terrain_details.gd`), wear and grime decals (`map_view_decals.gd`), and rain-soft mud footprints (`mud_footprints_3d.gd`).
- Streets are an authored network ([ADR 0026](../adr/0026-streets-as-authored-network.md); [`docs/tasks/urban_form/`](../tasks/urban_form/README.md)).
- Buildings come from `map_view_mesh_builder_*.gd` (houses, churches, fortifications, landmarks, interiors) and hand-built landmark models such as the 1343 Town Hall (`map_view_town_hall_model.gd`). Pipeline: [ADR 0025](../adr/0025-architectural-asset-pipeline.md), [`docs/tasks/architecture/`](../tasks/architecture/README.md), [`ASSET_INVENTORY.md`](../ASSET_INVENTORY.md). Materials: [`MATERIAL_STYLE_LOCK_KIT.md`](../MATERIAL_STYLE_LOCK_KIT.md), [`TEXTURE_AI_GENERATION.md`](../TEXTURE_AI_GENERATION.md).
- Fog of war: `map_fog_of_war.gd` remembers explored areas in the orthographic view.
- **Props** (barrels, wells, tools, furniture, forge fire and every other placeable object): one card file, [`OBJECT_CATALOG.md`](./OBJECT_CATALOG.md#model-notes). Kitchen gardens and farm dressing: [`FARMLAND.md`](./FARMLAND.md).

### Shared landmark weathering (R-1123)

Status: implemented (task **R-1123**). The legacy Town Hall builder
(`scripts/map/view3d/map_view_town_hall_model.gd`) and St Olaf builder
(`scripts/map/view3d/map_view_st_olaf_model.gd`) use
`scripts/map/view3d/map_view_landmark_weathering.gd` for age-toned library
surfaces, real-world-density triplanar projection, rising damp, seeded eave/sill
runoff, alpha-mask materials and opaque step abrasion. Callers keep their stable
building IDs, node names and seeded RNG order. Town Hall-specific lengths and
world-X sill sampling are explicit options; St Olaf retains the defaults.

This is derived presentation only: no input, `ContentDB` content, `GameState`,
save/load, collision or navigation change. The cached projection must not be
darkened in place: the Town Hall plinth duplicates it so gables retain the wall
tone. Scalar sill coordinates/ranges are kept until final vector construction
to preserve exact geometry, not only visually indistinguishable pixels.

Verify with `tests/godot/test_landmark_weathering.gd` and:

```bash
godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_landmark_weathering,test_city_sites,test_map_view_material_resolution
tools/godot_render.sh --script tools/capture_landmark_weathering.gd -- before
# Apply the refactor between the baseline and comparison captures.
tools/godot_render.sh --script tools/capture_landmark_weathering.gd -- after
```

The capture writes `build/landmark_weathering/{before,after}.{json,png}`. Compare
both numeric mesh/material/mask snapshots and decoded PNG pixels. The tool rejects
uniform frames and freezes shader `TIME` on capture-only materials. Recorded
[evidence and limits](../reports/town_hall_1343_remodel.md#shared-kit-parity-r-1123)
cover the isolated legacy hall, not acceptance of the newer seamless-city site's
full exterior. No textures, maps or landmark design are changed by this migration.

## Vegetation

Estonian trees, bushes, and plants by species (`map_view_tree_species.gd`, `map_view_bush_species.gd`, `map_view_plant_species.gd`) with fractal growth profiles and wind materials. Species reference: [`FLORA_FAUNA.md`](../FLORA_FAUNA.md). Seasonal crowns, rain and wind response, and leaf fall on weapon hits: [`LIVING_VEGETATION.md`](./LIVING_VEGETATION.md).

District maps draw no bushes since the legacy shrub mesh was removed ([`LIVING_VEGETATION.md`](./LIVING_VEGETATION.md#legacy-shrub-mesh-removed)).

Ground scatter (grass, plants, scatter trees) never grows under solid props: [`MAP_AUTHORING.md`](../MAP_AUTHORING.md#prop-orientation-and-surface-placement).

## Fauna and crowds

- **Birds**: species catalog (corvid, gull, owl, raptor, songbird, swallow, tern, wader, waterfowl, woodpecker), flapping flight with V-formation flocks ([Bird flight](../FLORA_FAUNA.md#bird-flight)), and ambient song (`map_view_bird_*.gd`).
- **Mammals**: urban cats and dogs with hunt/play/groom cycles (`map_view_urban_fauna.gd`, `map_view_companion_intent.gd`), penned livestock and wild-margin mammals (`map_view_penned_fauna.gd`), shared waypoint walking (`map_view_ground_wander.gd`).
- **Insects**: grasshopper and cricket stridulation ambience (`map_view_insect_*.gd`).
- **Crowds**: `map_view_crowd_renderer.gd` draws the urban population ([`WORLD_LIFE.md`](./WORLD_LIFE.md#urban-population)).
- Species reference and sourcing: [`FLORA_FAUNA.md`](../FLORA_FAUNA.md); asset rows in `assets/SOURCES.csv`.

## Characters

Human rigs, wardrobe, the crowd shader and close-up review captures: [`CHARACTER_GENERATION.md`](../CHARACTER_GENERATION.md) ([ADR 0022](../adr/0022-realistic-human-characters.md), [ADR 0016](../adr/0016-tiered-character-fidelity.md)). Fidelity backlog: [`VISUAL_FIDELITY_PLAN.md`](../VISUAL_FIDELITY_PLAN.md), [`CHARACTER_REALISM_BACKLOG.md`](../CHARACTER_REALISM_BACKLOG.md).

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
