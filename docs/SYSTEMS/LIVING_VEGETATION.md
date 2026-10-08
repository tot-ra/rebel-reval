# Living vegetation

Status: implemented (tasks **R-1187**, **R-1194**, **R-1329** procedural leaf atlas, **R-1321** shared wind field, seamless-city pass of **R-712** covering **R-1101**, **R-1102**, **R-1103**, **R-1105**; visual/reviewer acceptance pending). Scope: tree crowns in the 3D view follow the campaign calendar, react to rain and wind, and respond to melee swings. Presentation only: nothing here changes combat, collision, navigation, or saved state. Out of scope: felling or damaging trees, persistent leaf litter on the ground, snow on branches, seasonal bushes, grass, and crops, and blossom.

Reference bar: trees that feel alive in the way Witcher 3 and RDR2 trees do. The crown changes with the month, and a blow to the trunk knocks leaves loose.

## What the player sees

- **Seasons.** Deciduous crowns follow northern Estonian (Tallinn) phenology as a function of the in-game date: bare in winter. Bud-burst starts in late April with sparse, small, light yellow-green leaves. Crowns are full from June to August. Autumn colouring runs from mid September, with per-species palettes (birch and aspen gold, maple and rowan red, oak brown), several hues per crown, and the oldest leaves turning brown. The crowns are bare by early November. Early leafers (birch, willow, aspen, alder, orchard trees) open before late leafers (oak, ash, linden, elm, maple). Conifers keep their needles and turn duller and bluer in deep winter. On the slice's opening date, 21 April 1343, birches show about 28% of their leaves, small and fresh, and oaks show only their first buds.
- **Fruit** appears only in season: cherries in July, plums in August and September, apples and pears from August to October, rowan and hawthorn berries from August to November, and sloes from September to November.
- **Rain** darkens leaves and bark and makes them glossy. Leaves get wet from active rain at once, not only when puddles form.
- **Wind** moves crowns at two frequencies: whole limbs heave in gusts, rigid from the petiole, while leaf tips flutter. Since R-1321 a gust is one event in the world: it rolls across a meadow as a visible front, reaches the trees, then the flags, ropes and nets (see [Shared wind field](#shared-wind-field-r-1321)).
- **Melee swings.** When a landed swing (hit or miss) reaches a tree in front of Kalev, that crown shakes away from the blow and rings down over about 1.8 s, and a burst of leaves in the current season's colours tumbles to the ground. Heavy blows shake harder and drop more. Autumn crowns are the loosest. Conifers drop a few needles, and bare trees drop nothing.
- **Ambient leaf fall.** Leaves drift down around the player where trees stand nearby: heavily in October, a few during storms in any season with leaves, and none in open streets or bare winter woods. The wind carries them sideways.

## Runtime entry points

| Piece | File |
|---|---|
| Seasonal model (pure, deterministic) | [`vegetation_phenology.gd`](../../scripts/map/view3d/vegetation_phenology.gd) (`VegetationPhenology.state_for`, `falling_leaf_colors`, `hit_leaf_count`) |
| Crown shader (season, autumn hue, crown AO, wetness, two-frequency wind, hit shake) | [`map_view_canopy.gdshader`](../../scripts/map/view3d/map_view_canopy.gdshader) |
| Shared wind field (weather mapping, globals, CPU mirror) | [`wind_field.gd`](../../scripts/map/view3d/wind_field.gd) (`WindField`), shader side [`wind_field.gdshaderinc`](../../scripts/map/view3d/wind_field.gdshaderinc) |
| Per-species crown materials, season and wetness fan-out | [`map_view_wind_materials.gd`](../../scripts/map/view3d/map_view_wind_materials.gd) (`canopy_for_species`, `apply_vegetation_season`, `apply_vegetation_wetness`) |
| Seasonal fruit, wet bark | [`map_view_prop_materials.gd`](../../scripts/map/view3d/map_view_prop_materials.gd) (`tree_fruit_for_species`, `apply_fruit_season`, `apply_bark_wetness`) |
| Leaf mesh contract | [`map_view_leaf_geometry.gd`](../../scripts/map/view3d/map_view_leaf_geometry.gd), [`map_view_tree_meshes.gd`](../../scripts/map/view3d/map_view_tree_meshes.gd) |
| Strike query, crown shake, leaf bursts, ambient leaves | [`tree_leaf_fall_3d.gd`](../../scripts/map/view3d/tree_leaf_fall_3d.gd) (`TreeLeafFall3D`, child `TreeLeafFall` of every `MapView3D`) |
| Wiring | `MapView3D.set_calendar_date` pushes the season, `MapView3D.strike_vegetation` resolves a swing, and `MapView3D._process` drives ambient leaves. `MapViewMaterials.apply_weather_presentation` pushes wetness. `MapViewRuntimeActors._on_player_melee_attack_resolved` calls `strike_vegetation` with `Player.facing_direction()` and the `AttackProfile` reach, cone, and `is_heavy` flag |

## Data contracts

- **Leaf vertices** (tree canopy meshes only): `UV2.x = 1` tags a leaf. `CUSTOM0 = (petiole xyz, seed)` with seed in 0..1. `COLOR.a` holds the baked crown self-occlusion (0.48 inside the crown, 1 at the outer shell). The shader collapses a leaf to its petiole when `seed > leaf_density` and scales it by `leaf_scale`. Leaves with high seeds colour first and fall first, so the last leaves on an autumn tree are the greenest. Bushes and legacy canopies have no tag and keep the old height-weighted sway and summer look.
- **Season uniforms** live on one material per species (`canopy_species:<species>`), so trees still draw as one MultiMesh per species and add no draw calls. Streamed chunks and materials created after a cache reset pick up the last pushed date.
- **Hit shake**: scatter tree crowns are MultiMeshes with `use_custom_data`. `INSTANCE_CUSTOM.xy` holds the crown-top offset in world metres and `.z` the extra leaf flutter. `TreeLeafFall3D` writes these only for struck trees and zeroes them after the shake.
- **Strikeable trees**: `TreeLeafFall3D.tag_canopy` puts the canopy MultiMesh in group `tree_canopy_multimesh` and stores its species and instance transforms as node meta. MultiMesh buffers are GPU-side, so they are not read back. Authored single trees (`MeshInstance3D` "Canopy" in group `tree_canopy_mesh`) drop leaves but do not shake.
- **Determinism**: the season is a pure function of `GameCalendar.day_of_year` (Julian leap years included). There is no RNG and no persisted state, so save/load, phase changes, and seam crossings always agree with the HUD date.

## Verify

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_vegetation_phenology,test_tree_leaf_fall,test_vegetation_realism,test_map_view_tree_species
```

- [`test_vegetation_phenology.gd`](../../tests/godot/test_vegetation_phenology.gd) checks winter bareness, the 21 April bud-burst range, full summer crowns, October colouring and shedding, evergreen conifers, continuity and determinism, Julian leap years, and hit strength.
- [`test_tree_leaf_fall.gd`](../../tests/godot/test_tree_leaf_fall.gd) checks the strike query (nearest tree in front, ignoring trees behind or out of reach), shake ring-down, bursts only from leafed trees, ambient rate against season, wind, and tree count, season delivery to materials and fruit, and the leaf `CUSTOM0` and occlusion contract.

## Shared wind field (R-1321)

Status: implemented (task **R-1321**, VEGR-2). Scope: one deterministic wind for grass, tree crowns, sails, pennants and flags, wall banners, hoist ropes and fishing nets, plus the sideways drift of falling leaves. Out of scope: the sea (water keeps its own wind uniforms fed by `apply_sea_weather`), smoke and rain particles, the seamless city's own water shader, wind-driven gameplay (sailing, fire spread), grass geometry and placement (VEGR-4, VEGR-3).

**What the player sees.** A gust crosses an open meadow as a front: the tufts lay over and turn their paler flanks up, so a lighter band rolls downwind; a few seconds later the same front heaves the tree line and lifts the flags beyond it. Calm air nearly stops the wave; a storm makes fronts taller, longer, faster and more turbulent (more flutter). The heading and strength come from the weather and veer with it.

**Contract.** `MapViewWindMaterials.apply_world_wind(direction, strength)` is the single writer. It calls `WindField.publish(WindField.params_for(direction, strength))`, which writes six global shader parameters once through `RenderingServer.global_shader_parameter_set`; no material carries a per-material `wind_direction` / `wind_strength` uniform any more, so streamed chunks and materials created later are in the current wind without a fan-out. Callers are unchanged: `MapViewMaterials.apply_weather_presentation` (every `MapView3D` frame) and `CityWorld3D.apply_time`.

| Global (declared in `project.godot` `[shader_globals]`) | Meaning | Mapping from weather strength `s` (0..1) |
|---|---|---|
| `wind_dir_g` | Unit heading on the XZ ground plane | weather heading (`SkyWeather3D.wind_direction_xz`), zero falls back to the historical harbour bearing |
| `wind_strength_g` | Sustained strength | `s` (profile wind plus live rain-front gust, as `SkyWeather3D.wind_strength`) |
| `wind_gust_amp_g` | Gust height above the steady push | `0.12 + 0.88 * sqrt(s)` |
| `wind_gust_wavelength_g` | Metres between fronts | `lerp(14, 34, s)` |
| `wind_speed_g` | Front speed, m/s along the heading | `lerp(2, 11, s)` |
| `wind_turbulence_g` | Flutter and cross-wind chaos | `0.15 + 0.85 * s^2` |

Project defaults equal `params_for(default heading, 0.22)`, so a map that never publishes keeps the previous breeze. The shader include samples the front at `dot(xz, dir) - TIME * speed` at two scales (broad front, narrow ripple) with low-frequency value noise along the front so it never reads as a ruled line. Consumers call `wind_pressure(xz, TIME)` (downwind push, about 0.48 in a lull and 0.8 on average), `wind_gust_signed` (cloth and ropes that used a sine gust), and `wind_flutter_scale()`. Grass samples once per tuft, crowns once per tree at the trunk (`wind_pressure_coarse`: the same front without the patch noise, three `sin` like the old sway, because crown vertices are drawn again in every shadow cascade), cloth, ropes and nets once per staff or rack, so a whole plant moves together and the cost per vertex did not grow. Grass also brightens with the bend (`v_sheen`), which is what makes the front readable from across a field. Banners keep a sheltered share of the world wind (`wind_scale` 0.36, the old fixed 0.08 at the default breeze); flags and ropes expose `wind_scale` (default 1) so capture plates can show several strengths at once.

No texture is sampled: an analytic noise avoids a sampler slot (the Compatibility renderer links at most 16) and the unbound-sampler hazard on GLES, and lets `WindField.gust` / `pressure` / `local_strength` mirror the shader on the CPU. `TreeLeafFall3D` uses that mirror (at `WindField.clock()`, the wall clock that tracks shader `TIME`) so drifting leaves and strike bursts speed up while a front passes.

**Spike result.** Global shader parameters and a per-frame `global_shader_parameter_set` work under GL Compatibility at the Godot 4.7.1 pin: the cloud shadow pass (`cloud_offset_g`) and the sea clock (`ocean_time`) already depended on them, and the R-1321 capture shows the front moving between frames rendered through `tools/godot_render.sh`. Globals must be declared in `project.godot`: the wind shaders are preloaded constants and compile before any runtime `global_shader_parameter_add` could run.

**Determinism and saves.** The field is a pure function of world XZ, time and the weather snapshot: no RNG, no stored state, nothing persisted. Shader `TIME` wraps at Godot's 3600 s rollover, so once an hour every front jumps; this was already true of every animated shader.

**Verify.**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_wind_field,test_vegetation_realism,test_tree_leaf_fall,test_map_view_3d_mesh
tools/godot_render.sh --script tools/capture_wind_front.gd
tools/run_performance_report.sh build/perf_wind.json --vegetation
```

[`test_wind_field.gd`](../../tests/godot/test_wind_field.gd) checks determinism (same time and weather give the same bend, publishing other weather changes nothing), that the state at one point reaches a downwind point `distance / speed` seconds later (a travelling front), coherence across the wind, calm versus storm mapping, the zero-heading fallback, that `project.godot` defaults equal the default breeze, the single writer, and that all seven wind shaders include the field, keep no per-material wind uniform and still compile. `test_boat_float_3d`, `test_fishing_nets` and `test_hoist_rope` check the published state instead of material uniforms.

**Evidence.** [`r1321_wind_front_sheet.png`](../reports/images/vegetation/r1321_wind_front_sheet.png): six frames about 0.45 s apart over one meadow at strength 0.6, each beside its front map (luminance minus the mean of all frames, blurred to front scale; warm means blades laid over by a gust crest). The warm band moves left to right across the meadow, and in the first frame the previous front is at the birches. [`r1321_wind_calm_storm.png`](../reports/images/vegetation/r1321_wind_calm_storm.png): the same meadow at strength 0.04 and 0.92. The tool fails if two frames are byte-identical (a minimized window that stopped redrawing). Benchmark: see the R-1321 row in [`VEGETATION_REALISM.md`](./VEGETATION_REALISM.md#1-one-wind-field-for-everything).

**Limits.** Shader `TIME` cannot be pinned, so the capture uses real-time intervals and the CPU mirror only tracks the GPU field approximately (`WindField.clock()` vs the renderer's frame time). Turbulence comes from strength alone; rain and storm profile `chaos` are not mapped separately. The sea, smoke and rain particles still use their own wind inputs; only their heading is shared through `SkyWeather3D.wind_direction_xz`. The three-level tree wind (trunk sway) arrives with VEGR-6 (R-1324).

## Dense cluster crowns (R-1194)

Trees now combine the existing folded silhouette leaves with four-triangle folded
cluster cards. Every skeleton tip gets three cards (two for conifers); spruce,
pine and juniper also carry cards along branches and rings around the crown bole.
Conifers retain two opaque needle shoots per spray. Geometry is cached once per
species, with one canopy surface and the existing MultiMesh batching, no per-card
nodes or new material surfaces. Stable species IDs and save data are unchanged.
There are no new controls; the existing calendar, wind, rain and melee interactions
apply to the cards too. No input or save-format changes are involved.

- Cards tag `UV2 = (1, 1)`; folded leaves retain `(1, 0)`. All twelve card vertices
  share `CUSTOM0 = (petiole xyz, seed)`, but separate cards have separate seeds.
  `COLOR.a` remains crown AO. A whole cluster scales/collapses together, so spring
  growth, autumn colour order and winter shedding remain coherent.
- `leaf_atlas` is a 2048x1024 RGBA atlas: 4x2 tiles of 512 pixels. Row 0: birch,
  oak, maple, linden. Row 1: apple, spruce, pine, unused. `atlas_tile` selects a
  family via `map_view_leaf_geometry.gd::CARD_TILES`. Other species borrow the
  closest available family, not a botanically exact plate (notably compound and
  narrow-leaf species). Species tint still comes from the mesh/material.
- Alpha scissor at 0.5 cuts leaf silhouettes without alpha-blend sorting. RGB is
  approximately neutral relative brightness, not sRGB albedo; the shader samples
  it as data and multiplies by two. `card_gain` tunes card brightness. UV inset
  reduces tile-edge bleed, but does not guarantee isolation at coarse mip levels.
- Since R-1329 the atlas is drawn in code, not keyed from image-generator plates:
  `python3 tools/assets/generate_vegetation_atlases.py` (NumPy and Pillow; the old
  `build_leaf_card_atlas.py` entry point now calls it). Each tile is a twig with
  parametric leaves or needles (outline, serration, lobes, veins, wear) whose size
  was tuned so card coverage stays near the R-1194 tile it replaced. The output is
  byte-identical on every run; details and limits are in
  [`VEGETATION_REALISM.md`](./VEGETATION_REALISM.md) section 7. The Leonardo
  `leaf_cards_v1` and OpenAI needle sources are retired; the atlas row in
  `assets/SOURCES.csv` records the replacement.

### Verification and evidence

Run the four-file test command above. `test_vegetation_realism.gd` additionally
checks every species' single surface, triangle budget, card count, coherent
petiole/seed per card, seed diversity, AO, atlas binding/dimensions/alpha, and
non-sRGB sampling. Existing leaf-fall and phenology tests cover the unchanged
calendar, rain and strike paths.

Measured canopy geometry: 5,732-14,324 triangles per species (24,000 cap),
170,188 total across the 20 cached species. Spruce has 911 cards / 7,676 triangles;
pine has 878 cards / 7,320 triangles. Geometry counts do not measure alpha overdraw.

Capture commands (minimized GPU renderer):

```bash
tools/godot_render.sh --script tools/capture_living_vegetation.gd
tools/godot_render.sh --script tools/capture_tree_reference_sheet.gd
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot BENCHMARK_HEADLESS=0 \
  tools/run_performance_report.sh build/r1194/perf_after.json --quick
```

- Seasonal plates: [before](../reports/images/vegetation/r1194_before.png),
  [after](../reports/images/vegetation/r1194_after.png). Rows: birch, oak, maple,
  apple, spruce. Columns: 21 April, 20 May, 15 July, 5 October, 15 January.
- Species plates: [before](../reports/images/vegetation/r1194_species_before.png),
  [after](../reports/images/vegetation/r1194_species_after.png).
- The baseline disables R-1194 geometry and shader additions while retaining the
  same surrounding working-tree content. Runs are sequential to avoid GPU
  contention. This is a local A/B comparison, not a clean-main benchmark.
- Capture scripts completed, but an independent visual comparison is still
  required; generated files alone do not establish Witcher 3 / RDR2 quality.
  The configured review agent failed without returning findings.

### Local quick GPU performance

Godot 4.7.1, GL Compatibility, Apple M5 Pro, sequential minimized GPU runs:
[raw before report](../reports/images/vegetation/r1194_perf_before.json),
[raw after report](../reports/images/vegetation/r1194_perf_after.json).

| Metric | Before | After |
|---|---:|---:|
| Lower Town scene median frame | 88.578 ms | 90.321 ms |
| Reciprocal of median frame time (not average FPS) | 11.29 | 11.07 |
| Lower Town scene p95 frame | 190.828 ms | 174.784 ms |
| Lower Town pipeline p95 frame | 10.134 ms | 30.406 ms |
| Scene static memory | 347,613,860 bytes | 347,704,386 bytes |

These are one-run quick observations, not a no-regression claim. Both scene runs
miss 60 FPS substantially; pipeline p95 worsened while scene p95 improved. Repeat
warmed GPU measurements and profile alpha overdraw before performance acceptance.
The logs also contain existing shared-tree character UID/no-rig warnings and
shutdown resource leaks. The filtered suite passed 33 tests with zero failures
and zero runtime errors; resource-leak messages still occur during shutdown.
Full asset provenance validation is blocked by four missing merchant-stone rope
textures and an unregistered grass atlas from other work; R-1194's 15 rows are
present. Active-doc validation must be regenerated against the staged file set.

## Gameplay-scale GPU evidence and review (R-1187)

Captured 2026-10-07 with a one-off script (not kept in `tools/`) through
`tools/godot_render.sh`: `prototype.sacred_grove` built by `MapView3D.create`,
shipped gameplay orthographic crop (`CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE`,
about 21 px per metre at 720p), Godot 4.7.1 GL Compatibility, Apple M5 Pro.
The struck tree is the most open in-map birch near the spawn. For 21.04, 15.07 and
10.10.1343 the script calls `MapView3D.strike_vegetation` with Kalev 1.1 m from
the trunk and saves frames at rest, 0.2 s and 1.0 s after the blow; then a
15.07 rain frame and a 10.10 ambient frame around a `player_view_rig`.

- [Full frames](../reports/images/vegetation/r1187_gameplay_frames.png): 0.2 s after
  hits on 21.04, 15.07, 10.10, and October ambient fall.
- [Zoomed crops](../reports/images/vegetation/r1187_gameplay_zoom_sheet.png): rows
  21.04, 15.07, 10.10 (rest / 0.2 s / 1.0 s), then 15.07 rest / rain / 10.10 ambient.
- Strike results: 21.04 birch 3 leaves, 15.07 12 leaves, 10.10 50 leaves; October
  ambient emitter at 16 particles. All 11 raw frames have distinct md5 hashes (no
  frozen frames).

What the captures show: the seasonal crowns read clearly at gameplay scale (sparse
fresh April green, full July crown, mixed gold and brown October). The crown shake
is visible as a shift between rest and 0.2 s. The leaf burst and ambient leaves read
only as a few bright specks. The rain frame is dominated by rain fog, so leaf and
bark wetness cannot be judged from it. Kalev is not visible in the frames; the same
runs log a GL Compatibility `Program linking failed ... uses 17 samplers` error
right after the hero character assets load.

Tuning applied after the captures:

- Particle leaf quad 0.075 x 0.055 m to 0.14 x 0.10 m (`TreeLeafFall3D._make_leaf_mesh`):
  true-size leaves were about 1.5 px at the gameplay crop.
- `VegetationPhenology.hit_leaf_count` base 26 to 34 (summer hit about 12 leaves).
- Bursts emit from the lower crown shell instead of the crown centre, so leaves leave
  the foliage that hid them.
- `SHAKE_AMPLITUDE` (0.16 m) and the autumn palette are unchanged. October crowns lean
  brown because the canopy shader multiplies the autumn hue by the leaf luminance
  times 0.82. That is a shader change, left for follow-up.

Code review of commit `3078c157`: no blocking issues found.

- The shader reads `INSTANCE_CUSTOM`, which is zero for plain `MeshInstance3D` crowns
  and MultiMeshes without custom data. `MODEL_MATRIX` includes the instance transform,
  so per-tree limb phase works.
- `use_custom_data` is set before `instance_count`. Shakes write custom data only for
  struck trees and zero it at the end.
- Per-frame cost is small: one group lookup, one ambient update, and a date-string key
  per frame. The tree walk runs every 1.5 s and on each strike.
- Static season, wind and wetness state survives `reset()`, so streamed chunks and
  rebuilt materials start in the current season. `_bark_wetness = -1` forces a re-push.
- Minor, not fixed: the leaf branch repeats `inverse(mat3(MODEL_MATRIX))` per vertex,
  and shared non-species canopy materials (bushes) never get wet.
- The delegated second reviewer agent failed without returning findings.

## Scale, glare and ground-cover popping fixes (R-1194 follow-up)

- Card size: `CARD_SCALE` 3.4 -> 2.3 and `CONIFER_CARD_SCALE` 3.8 -> 3.0 in
  `map_view_tree_meshes.gd`, with 4 cards per deciduous tip (was 3), because single
  leaves read head-sized next to the player.
- Card lighting: in `map_view_canopy.gdshader` cards use matte roughness 0.95,
  specular 0.06 and 45% backlight, so conifers no longer wash white when the sun
  grazes them.
- Grass popping: ground cover was culled per chunk by `visibility_range_end`, so a
  whole chunk appeared or vanished with camera motion. `map_view_grass.gdshader`
  now shrinks each tuft to zero between `fade_start` and `fade_end` (distance from
  the camera, same metric as the range cull) before the cull fires. Scatter grass
  (`grass_blades()`) fades 22-36 m inside its 45 m range; eye-level terrain details
  (`grass_blades_near()`) fade 7-11 m inside their 14 m range.
- Grass variety: per-tuft height, width and tint vary from the planted position.
- Not yet verified visually: needle transparency on conifers and bush popping
  (bushes have no range cull, so their cause is still open); see the follow-up tasks.

## Seamless city: real scale, near/far crowns, bark and grass plates (R-712)

The seamless city ([SEAMLESS_CITY.md](SEAMLESS_CITY.md), 1 world unit = 1 m) reuses the
district tree meshes, which are about 2.5 units tall and get scaled 3-4.5x. Everything
sized in mesh units grew with them: leaf-cluster cards were 1-1.9 m (head-sized leaves,
spruce needles read as flat planks), a 13 m spruce had a 1.1 m trunk, and bark UVs ran
0..1 per limb segment (a blurred brown smear). The city now builds its own variants;
the district maps keep their geometry and procedural bark unchanged.

What the player sees:

- **Heights** follow young-to-middle-aged trees (`CityVegetationBuilder.HEIGHT_M`:
  spruce 9.5 m, pine and oak 10 m, birch 9 m, linden/ash/elm 9.5 m), and the plan's
  per-tree size factor is compressed toward 1 (`SIZE_VARIATION` 0.6), so the tallest
  tree is under seven times Kalev's 1.83 m.
- **Trunks** are thinned to real base diameters (`TRUNK_DIAMETER_M`, spruce 0.36 m, oak
  0.7 m, birch 0.3 m; branches thin less so they never outgrow the bole) and carry
  photographic **bark plates** (birch, oak, grey for ash/linden/elm/maple/alder/willow,
  pine, spruce, cherry for orchard trees) with normal maps, tiled every 0.55 m up each
  limb. Rain darkens them like the old bark.
- **Near crowns** (trees within 34 m of the camera, released at 42 m) use real-size
  cluster cards (0.62 m deciduous, 0.58 m conifer) with up to 3.5x more cards, and single
  folded leaves at 0.4x, so leaves read at leaf size when Kalev stands under a tree.
  **Far crowns** keep the cheap big-card geometry. The swap is per tree, not per 96 m
  chunk, and both LODs share one skeleton, so the silhouette never changes.
- **Spruce** grows 26 whorls (was 14) with the skirt down to 0.34 of the trunk, so it
  reads as a dense cone instead of a few sparse tiers; pine has 16 primaries.
- **Needles**: the atlas spruce and pine tiles were regenerated from denser needle
  sprays and keyed hard enough that the soft shadows between needles are cut away
  (they were kept as an opaque pale fill, which made each card a flat sheet).
- **Grass ground**: twelve seamless meadow plates (rough pasture, hay meadow, clover,
  spring grass, sedge, yarrow and weeds, wildflowers, plus rare dry, mossy and
  leaf-strewn patches and a trodden plate round packed earth) replace the single 1.6 m
  plate. Each plate covers about 1.3 m. A warped lattice of 4.5 m cells gives every
  corner its own plate, rotation and offset and blends the four corners with
  height-aware weights, so patches meet in ragged edges and nothing repeats.
- **Grass tufts** are 0.2-0.45 m tall (`CityGrass.TUFT_SCALE` 0.36-0.78 of the shared
  tuft, was 0.55-1.15) at 2.8 tufts per m^2.

Runtime entry points:

| Piece | File |
|---|---|
| City wood, near and far crowns, city skeleton overrides | [`map_view_tree_meshes.gd`](../../scripts/map/view3d/map_view_tree_meshes.gd) (`city_wood_mesh`, `city_canopy_near_mesh`, `city_canopy_far_mesh`, `CITY_PROFILE_OVERRIDES`) |
| Profile-driven segment cap (`max_segments`) | [`map_view_tree_mesh_skeleton.gd`](../../scripts/map/view3d/map_view_tree_mesh_skeleton.gd) |
| Per-tree near/far swap | [`city_tree_lod.gd`](../../scripts/city/city_tree_lod.gd) (`CityTreeLod`, child `Vegetation/TreeLod` of `CityWorld3D`; follows the active camera) |
| Heights, trunk diameters, LOD registration | [`city_vegetation_builder.gd`](../../scripts/city/city_vegetation_builder.gd) |
| Bark plate materials | [`map_view_prop_materials.gd`](../../scripts/map/view3d/map_view_prop_materials.gd) (`bark_plate`, `BARK_PLATES`), `MapViewTreeSpecies.bark_plate_for` |
| Grass ground plates | [`city_grass_ground.gdshaderinc`](../../scripts/city/city_grass_ground.gdshaderinc), included by `city_ground.gdshader`; textures bound in `CityTerrainBuilder.TEXTURES` |
| Tuft size | [`city_grass.gd`](../../scripts/city/city_grass.gd) (`TUFT_SCALE`) |

Data and assets: `assets/materials/pbr/grass_ground/grass_ground_{albedo,normal}_array.jpg`
(imported as 4x3 `Texture2DArray`s; slice order is the `GRASS` list in the processor and
the comment in the include) and `assets/materials/pbr/bark_<plate>/` (the spruce and pine
tiles of `foliage_cards/leaf_card_atlas.png` came from here until R-1329 drew the whole
atlas procedurally). Sources are OpenAI `gpt-image-1` plates under
`generated/openai/vegetation_v1/<group>/<name>/prompt.json` (prompt, generation id, SHA-256;
the raw PNGs are not committed). Rebuild with
`python3 tools/assets/build_vegetation_plates.py [--only grass,bark] [--preview build/vegetation_plates]`
(the preview writes 2x2 tilings for a seam check). Provenance rows
are in `assets/SOURCES.csv` (visual and rights approval pending). Nothing is saved: the LOD
and all geometry are rebuilt deterministically from the plan.

Verify:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_city_vegetation
tools/godot_render.sh --script tools/capture_city_vegetation.gd -- --tag=after   # build/vegetation/*.png
```

[`test_city_vegetation.gd`](../../tests/godot/test_city_vegetation.gd) checks heights against
Kalev, trunk diameters, bark-tile UVs and tangents, bark plates, near card size, density and
triangle budget, the city spruce whorls, the unchanged district spruce, the LOD swap and its
hysteresis, the grass-plate import contract and tuft size. The capture tool frames the most
open spruce, pine, oak and birch next to a 1.83 m reference figure, plus needle, bark and
grass close-ups and a far stand.

Before / after (Godot 4.7.1 GL Compatibility, Apple M5 Pro, 15 July, late morning):
[spruce](../reports/images/vegetation/veg_city_spruce_scale.jpg),
[spruce, gameplay camera](../reports/images/vegetation/veg_city_spruce_gameplay.jpg),
[spruce needles](../reports/images/vegetation/veg_city_spruce_needles_close.jpg),
[pine](../reports/images/vegetation/veg_city_pine_scale.jpg),
[oak, gameplay camera](../reports/images/vegetation/veg_city_oak_gameplay.jpg),
[oak bark](../reports/images/vegetation/veg_city_oak_bark_close.jpg),
[birch bark](../reports/images/vegetation/veg_city_birch_bark_close.jpg),
[grass at eye level](../reports/images/vegetation/veg_city_grass_eye.jpg),
[grass from above](../reports/images/vegetation/veg_city_grass_wide.jpg),
[far stand](../reports/images/vegetation/veg_city_stand_far.jpg).

Cost: in the densest stand (18 trees within 35 m, 17 near crowns) a 1600x900 frame took
8.4 ms with near crowns off and 9.0-10.5 ms with them on (one local run). Near crowns
are 12-20k triangles for broadleaves, about 55k for spruce and 66k for pine
(`NEAR_TRIANGLE_CAP` 56k; conifers carry cards along every segment and stay a little over).

Limits of this pass: Scots pine keeps a stylised clumped crown; the grass plates'
plantain and dandelion rosettes can repeat in a regular rhythm inside one plate; the
district maps keep their old bark and crown geometry. Shrub leaves were fixed in R-1315
(below).

### City shrubs: real-size leaves (R-1315)

Status: implemented (task **R-1315**). Scope: seamless-city shrubs from the plan's
`bushes` list. Out of scope: district-map bushes (`MapViewBushMeshes.mesh_for` is
unchanged) and the leafless scrub tufts (juniper, sea buckthorn, heather).

City shrubs are drawn two ways, and both had the wrong leaf size beside Kalev:

- **Tree-mesh shrubs.** Elder, hazel, guelder rose, willow and alder scrub, hawthorn,
  spindle and blackthorn use the hazel, hawthorn or blackthorn tree meshes
  (`CityVegetationBuilder.SHRUB_AS_TREE`). Their far cards are 0.36-0.54 m and they
  never swapped to a near crown. They now join `CityTreeLod` like trees, and their near
  crown uses `MapViewTreeMeshes.NEAR_SHRUB_CARD_METRES` (0.28 m cluster cards, about
  8-12 cm leaves) with up to 3.5x more cards, so the shrub keeps its mass
  (`MapViewTreeMeshes.CITY_SHRUBS`).
- **Bush-mesh shrubs.** Dog rose and raspberry used the shared ~1 unit vertex-colour
  blob meshes scaled 1.5-1.9x: sticks with smooth green balls and no leaf cards. The
  city builds its own variant in metres (`MapViewBushMeshes.city_mesh_for`, chosen by
  `CityVegetationBuilder.bush_mesh` / `bush_scale`): 14-15 arching canes (`CITY_CANES`;
  rose arches out, raspberry stands upright) carrying alternate leaf-cluster cards of
  `CITY_CARD_METRES` (0.24 m) from just above the ground to the tip. Cards use the canopy
  card contract (UV2 = (1, 1), CUSTOM0 = twig base + seed) and the canopy material of a
  proxy tree (`CITY_LEAF_PROXY`: rose -> rowan, raspberry -> hazel), so they sway, green
  up, colour and drop with that species; canes stay bare in winter. The plan's size
  factor is the only instance scale.

Cost: a city rose is about 2.2k triangles and a raspberry 1.8k (the blobs were 320).
Shrub near crowns are 11-19k triangles (far 8.5-11k) and only within 34 m. Nothing is
saved; meshes are rebuilt deterministically from the plan.

Verify: `test_city_bush_leaf_cards_are_real_size` measures every card along its spine
(rose and raspberry under 0.4 m at the plan's largest size factor, at least 150 cards,
height and spread kept; tree-mesh shrub near cards under 0.4 m and smaller than far
cards) and `test_district_bush_meshes_unchanged` guards the district geometry. GPU
plates: `tools/godot_render.sh --script tools/capture_city_vegetation.gd -- --only=dog_rose_close,raspberry_close,elder_close`
(the most open shrub of each species next to the 1.83 m figure).

Before / after:
[dog rose](../reports/images/vegetation/veg_city_dog_rose_close.jpg),
[raspberry](../reports/images/vegetation/veg_city_raspberry_close.jpg),
[elder (hazel tree mesh)](../reports/images/vegetation/veg_city_elder_close.jpg).

Limits: rose hips, raspberry fruit and flowers are not drawn on the city variants (the
district blobs show berries all year); the lower canes read bare and dark from close up;
a dense hedge of city roses costs about seven times the old blob triangles (the 120 m
`BUSH_RANGE` is unchanged).

## Limits

- GPU plates are attached above; visual tuning and independent sign-off remain pending. Distance LOD/impostors and alpha-coverage-preserving mips are not implemented; distant needle cards can thin out.
- Fallen leaves vanish when they land. There is no persistent ground litter, and grass and bushes do not change with the season (except the seamless city's dog rose and raspberry leaf cards and tree-mesh shrubs, which follow their proxy species, R-1315).
- Only the player's swings strike trees. NPC melee, magic blasts, and projectiles do not.
- When two hosted views overlap at a seam, each runs its own ambient emitter, which can double the leaf fall right at the seam.
- Late-April leaf density is a design choice for the slice's spring look. Real Tallinn birches usually break bud a week or two later.

## Conifer volume and atlas fringe fix

- Conifer cards are smaller (`CONIFER_CARD_SCALE` 2.0, trunk fans x0.62), three per tip, and branch whorls use three fans rolled around the branch axis so needles read as volume from every side.
- Conifer realism pass: needle cards are 3-segment strips that bow downward (`CONIFER_CARD_DROOP` 0.22) with smooth, width-rounded vertex normals (`append_card` `droop`), and `map_view_canopy.gdshader` darkens gaps from the atlas (`clump`), shades sprig bases (`tip_light`) and perturbs card normals from the cluster pattern so needles stop lighting as flat plates. Conifer `card_gain` 0.84.
- Conifer card normals follow the crown shell (`CONIFER_NORMAL_OUTWARD`, no upward bias) and use `card_gain` 0.66, which stops sun wash-out.
- `tools/assets/defringe_atlas.py` removes pale outlines from `grass_blades_atlas.png` (2x2): alpha eroded, edge colour repainted from solid leaf colour. Do not run it on `leaf_card_atlas.png` since R-1329: the generator already fills empty texels with nearby leaf colour, and a second pass would erode the procedural tiles.
