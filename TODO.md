# Executable work

The project task board is the preferred operational queue for claims and progress.
This file remains the durable/legacy ID index expected by `README.md`, `AGENTS.md`, and active-doc link checks.

| Document | Role |
|----------|------|
| Project task board (`tasks` tool) | Claims, WIP, verification evidence |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Current focus and coordination history |
| [`docs/TASK_ARCHIVE.md`](docs/TASK_ARCHIVE.md) | Completed legacy rows |
| [`docs/STORAGE_SIZE_BACKLOG.md`](docs/STORAGE_SIZE_BACKLOG.md) | Open storage and file-size contracts (**P0-177**..**P0-187**) |
| [`docs/CHARACTER_REALISM_BACKLOG.md`](docs/CHARACTER_REALISM_BACKLOG.md) | Character model/animation realism follow-ups (**P0-188**..**P0-198**) |
| [`docs/LEGACY_REINTRODUCTION.md`](docs/LEGACY_REINTRODUCTION.md) | ADR 0017 / P7 inventory |
<!-- Quick-reference counts updated on every structural change -->
| Priority | Open | Done | Notes |
|----------|-----:|-----:|-------|
| P0 |    14  |     3  | Baseline, storage, materials, historical audit |
| P2 |     1  |     0  | Vertical-slice production (playable MVP) |



## Vegetation realism (maintainer request, 2026-09-12)

- [ ] P0-208 | deps: none | deliverable: finer curved grass, species-shaped folded tree leaves, light-driven translucency, coherent gusts and irregular nearby ground cover visible through existing vegetation renderers | allowed files: `scripts/map/view3d/map_view_foliage_meshes.gd`, `scripts/map/view3d/map_view_tree_meshes.gd`, `scripts/map/view3d/map_view_leaf_geometry.gd`, matching UID, `scripts/map/view3d/map_view_material_shaders.gd`, `scripts/map/view3d/map_view_terrain_details.gd`, `tests/godot/test_vegetation_realism.gd`, matching UID, `tools/capture_vegetation_realism.gd`, matching UID, `docs/ART_BIBLE.md`, `docs/reports/vegetation_realism_2026-09-12.md`, `docs/reports/images/vegetation_realism/`, `TODO.md` | constraints: Witcher 3 is a realism reference; original procedural geometry only; preserve species IDs, maps, collision, navigation, movement, saves, cached MultiMesh batching and unrelated WIP | verify: focused vegetation/mesh/terrain/interaction tests; full Godot suite; map audit, activation, conversion and active-doc checks; matched before/after and motion captures in GL Compatibility; bounded geometry/deterministic chunk tests; independent second review

P0-208 implementation, 64 focused tests in headless and GL Compatibility, and independent review are complete. Global acceptance remains open for unrelated full-suite/content, map-audit capture and active-doc failures; see [vegetation evidence](docs/reports/vegetation_realism_2026-09-12.md).

## Water and sky realism pack

Contracts: [`docs/tasks/water_sky/README.md`](docs/tasks/water_sky/README.md). Task board epic R-885.

- [ ] WS-01 | deps: none | deliverable: water extinction and bed sampling follow the Snell-refracted ray to the depth-buffer bed (vertical column / refracted cosine, one refinement), replacing view-ray geometric depth and the fixed screen-offset refraction | allowed files: `scripts/map/view3d/map_view_water.gdshader`, `scripts/map/view3d/map_view_water_materials.gd`, `tests/godot/test_r715_water_material_contract.gd`, `docs/THIRD_PARTY_NOTICES.md`, `docs/reports/images/ws01_*.png`, `TODO.md` | verify: contract test asserts refract/Beer-Lambert path; harbor clear-day before/after captures show a clear shallow bed with no orbit-dependent darkening and no bank halo

WS-01 implementation landed (R-886, in review). Decisions (2026-09-26): the per-terrain
`optical_depth` floor still dominates the few-centimetre flat gameplay column, so extinction
constants were not retuned (Compatibility plate within 3% of the pre-change colour). The old
`_view_depth` decoded Mobile/Metal depth with the OpenGL -1..1 convention; the shared
`_view_position` helper fixes that, so the Metal shallow strip now matches Compatibility instead
of the teal-opaque bed. Seabed layers and caustics use the floored vertical column; edge-foam
fades use the unfloored vertical column. Evidence: `docs/reports/images/ws01_*.png`.

- [ ] WS-03 | deps: none | deliverable: deterministic tools/bake_ocean_fft.py baking three band-split, time-looping JONSWAP/TMA FFT cascades (disp+foam, derivatives) into Texture2DArray PNG atlases with a profile manifest | allowed files: `tools/bake_ocean_fft.py`, `tests/python/test_bake_ocean_fft.py`, `assets/water/ocean_fft/baltic_reference/*`, `assets/SOURCES.csv`, `TODO.md` | verify: python unittest (periodicity, energy, determinism, foam loop); --check exits 0; storage/provenance/asset-lint validators pass; atlases import as 64-layer arrays

The WS-03 bake landed in commit `3cc7967f` with four recorded deviations from its contract text
(positive displacement sign with negative derivative channels, physical `Hs = 1.26 m` amplitude
normalisation, linear per-cascade foam that double-counts when summed, and
`CompressedTexture2DArray` atlases). They are authoritative for downstream work and are now carried
in the WS-04, WS-05 and WS-06 contracts; see "Final parameters and decisions" in
[`WS-03`](docs/tasks/water_sky/WS-03_fft_ocean_bake_tool.md) and the `conventions` block of
`assets/water/ocean_fft/baltic_reference/ocean_fft_profile.json`.

- [ ] WS-04 | deps: WS-03 | deliverable: water shader FFT path sampling baked C0/C1 displacement and C0-C2 derivatives with frame blending, wind rotation, distance LOD, ocean_time global clock and weather-driven cascade weights; Gerstner kept for rivers/standing basins/fallback | allowed files: `scripts/map/view3d/map_view_water.gdshader`, `scripts/map/view3d/map_view_water_materials.gd`, `scripts/map/view3d/map_view_runtime_environment.gd`, `scripts/map/view3d/sky_weather_3d.gd`, `project.godot`, `tests/godot/test_r715_water_material_contract.gd`, `tests/godot/test_r715_water_weather_sync.gd`, `tests/godot/test_ocean_fft_material.gd`, `docs/reports/images/ws04_*.png`, `TODO.md` | verify: headless suite incl. new FFT material test; harbor clear/overcast/storm captures show no tiling, no loop seam, wind-steered trains; performance report within water budget

WS-04 implementation landed (R-889, in review). The FFT path stays off in play until WS-05 adds
`BoatFloat3D.FFT_SUPPORTED`; `MapViewWaterMaterials.force_ocean_fft_support` turns it on for tests
and captures. Decisions recorded during capture review (2026-09-25):

1. **Geometry is compressed, shading is physical.** The view mesh keeps water only
   `WATER_SURFACE_LIFT` (0.006 units) above the recessed bed, so the physical sea (troughs near
   -0.72 units) exposed the bed everywhere. `fft_geometry_scale = terrain height / (0.63 m / 0.87)`
   maps the reference crest onto each terrain's Gerstner height budget, troughs ease into a
   0.0015-unit floor (`FFT_TROUGH_FLOOR`, which leaves room for the low-tide offset), and
   horizontal mesh chop is halved (`FFT_HORIZONTAL_GEOMETRY`) to close hairline cracks against
   the flat surroundings planes. Slopes, Jacobian and foam stay physical (`ocean_amplitude = 1`
   is still the Hs 1.26 m reference). WS-05 hull sampling must apply the same scale, floor and
   horizontal factor.
2. **LOD uses pixel footprint, not camera distance.** The gameplay camera is orthographic at a
   fixed 90-unit distance, so C1/C2 fade by texels per pixel instead of the 40/160-unit distances.
   The atlases import without mipmaps (`mipmaps/generate=false`), so the manual LOD clamps to
   level 0 today and the fade does the anti-aliasing.
3. **One sampler hint.** All five atlases bind as `filter_linear_mipmap, repeat_enable`, because
   Godot rejects one sampler parameter fed textures with differing hints.
4. **Sea-state scalar** is `wind + 0.4 x rain` with knots calm 0.20, reference 0.50, storm 0.85
   (the final Hs table lives above `OCEAN_FFT_SEA_STATES`). FFT choppiness keeps each terrain's
   authored ratio to deep water, so basins and shallows peak less than the open sea.
5. **Evidence:** `docs/reports/images/ws04_*` (Compatibility and Metal, clear/overcast/storm day
   at gameplay zoom 33.75, storm at zoom-out 114, a wind-turn pair, a loop-wrap strip across
   `ocean_time` 1638.4 -> 0, and the Gerstner baseline). Frame-to-frame difference across the
   wrap was 0.91 against a 0.88 median, so there is no pop. On an Apple M5 Pro at 2560x1440 storm,
   whole-frame time went Metal 5.91 -> 4.93 ms and Compatibility 8.52 -> 8.26 ms at gameplay zoom
   (zoom-out: Metal 10.33 -> 9.40 ms, Compatibility 15.0 -> 15.2 ms). That is inside the existing
   water budget. `tools/verify_r715_water_performance.py` is still BLOCKED only by its unmeasured
   minimum-tier row, which was already the case before this task.

- [ ] WS-05 | deps: WS-04 | deliverable: OceanFftSampler (CPU decode of C0/C1 atlases, shared sea-state mapping, fixed-point height_at) and BoatFloat3D heave/pitch/roll/surge from five FFT hull samples with the shared ocean_time clock | allowed files: `scripts/map/view3d/ocean_fft_sampler.gd`, `scripts/map/view3d/boat_float_3d.gd`, `scripts/map/view3d/map_view_water_materials.gd`, `tests/godot/test_ocean_fft_sampler.gd`, `tests/godot/test_boat_float_3d.gd`, `docs/reports/images/ws05_*.png`, `TODO.md` | verify: sampler decode/periodicity/inversion/perf tests; boat FFT attitude tests; harbor clip shows hulls seated at the waterline in clear and storm

WS-05 implementation landed (R-890, in review). `BoatFloat3D.FFT_SUPPORTED` is declared, so the
WS-04 FFT path is now on in play for sea, shallow and harbour water. Decisions (2026-09-25):

1. **Atlases are parsed from the imported `.ctexarray`, not read with `get_layer_data()`.** The
   headless/dummy renderer returns null layers and on Compatibility the call is a GPU readback. The
   file holds the lossless WebP layers the GPU uploads, so texels match byte for byte (test against
   the source PNG) and exports work. Load 34 ms, 8 MiB raw RGBA8.
2. **Per-terrain surface terms** (geometry scale, chop ratio, standing ratio) are passed per query
   (`OceanFftSampler.terrain_surface()`); a hull looks its terrain up once from the owning map
   view's grid. `apply_sea_weather()` pushes the same `fft_sea_state()` values to the sampler.
3. **Frame budget:** six harbour hulls cost 0.47 ms/frame with three fixed-point steps, too close to
   0.5 ms, so hull points use one step (`FFT_HULL_ITERATIONS`, 0.26 ms; error vs three steps under
   0.2 mm heave). `height_at()` keeps three steps (residual 0.00076 units on the physical sea at
   chop 1.2) for camera/swimmer queries; 14.6 us per call.
4. **Spring 0.2 s instead of ~0.35 s:** longer lag opens a waterline gap on the ~3 s C1 wave.
   Pitch now rotates about the beam axis and roll about the keel on the FFT path (the Gerstner
   fallback keeps its old axes).
5. **Evidence:** `docs/reports/images/ws05_metal_{clear,storm}_{cog,landing}_clip.png`
   (`tools/capture_ws05_boat_waterline.gd`, 12 moments 0.5 s apart): hulls stay seated with no
   visible gap or sinking at gameplay zoom. The waterline error was not measured in pixels.
   Reference sea Hs measured 1.21 m against the baked 1.25 m. Quick performance report with FFT on:
   frame p95 10.83 ms (`build/benchmarks/ws05-performance-quick.json`).
6. **Shore fade (R-909 / WS-05b):** hulls now scale FFT displacement by the same
   `smoothstep(0,0.16,COLOR.r) * mix(1.32,1.0,smoothstep(0,0.65,COLOR.r))` product
   as the water shader. `MapView3D.water_coverage_at` exposes
   `combined_water_coverage_at`; `COLOR.r` is `inverse_lerp(threshold, 1, coverage)`.
   Evidence: `docs/reports/images/ws05b_*.png` from
   `tools/capture_ws05_boat_waterline.gd --boat=landing`.
7. **Scope additions:** `tests/godot/test_coastal_sea_3d.gd` (its chop-vs-height check now reads
   the FFT sea-state table when FFT is on) and the capture tool.

- [ ] R-909 | deps: WS-05 | deliverable: hulls within ~1.5 units of land scale sampled FFT displacement by the shader shore fade and shoaling | allowed files: `scripts/map/view3d/boat_float_3d.gd`, `scripts/map/view3d/ocean_fft_sampler.gd`, `scripts/map/view3d/map_view_3d.gd`, `tests/godot/test_boat_float_3d.gd`, `docs/reports/images/ws05b_*.png`, `TODO.md` | verify: `--filter=test_boat_float_3d,test_ocean_fft_sampler`; landing-boat clear/storm clips show no clipping

R-909 implementation landed. `OceanFftSampler.shore_scale_from_coverage` matches the
WS-04 vertex scale; `BoatFloat3D` binds `MapView3D.water_coverage_at` when the hull
is under a map view. `--filter=test_boat_float_3d,test_ocean_fft_sampler` 24/24.

- [ ] WS-09 | deps: none | deliverable: deterministic offline Hillaire transmittance (256x64) and multi-scattering (32x32) LUTs as half-float EXR with profile manifest, plus atmosphere_common.gdshaderinc GLSL parameterisation | allowed files: `tools/bake_atmosphere_luts.py`, `tests/python/test_bake_atmosphere_luts.py`, `assets/sky/atmosphere/*`, `assets/SOURCES.csv`, `scripts/map/view3d/atmosphere_common.gdshaderinc`, `tests/godot/test_atmosphere_luts.gd`, `TODO.md` | verify: python oracle tests (zenith T = 0.940/0.868/0.762, monotonicity, round-trip, determinism, EXR parse); Godot loads EXRs and matches the oracle texel

WS-09 implementation landed (R-894, in review). Decisions recorded during the bake (2026-09-25),
also listed in the `conventions` block of `assets/sky/atmosphere/atmosphere_profile.json`:

1. **Consistent sub-UV, not Tidewater's.** Tidewater's forward transmittance lookup scales by
   W/(W+1) but its bake inverts with W/(W-1), so lookups land up to half a texel off and the
   contract's 1e-4 round-trip cannot hold. Both directions use the Bruneton pair
   `0.5/N + x (N-1)/N`. WS-10 must include `atmosphere_common.gdshaderinc` rather than re-port
   Tidewater's `atmosphereTransmittanceUV`.
2. **Fibonacci sphere** (64 directions) for the multi-scattering integral, per the contract,
   instead of Tidewater's 8x8 theta/phi grid. Step offset 0.3 and the 0.001/0.999 height clamp
   follow Hillaire and Tidewater.
3. **Sanity band reading.** "0.01-0.1 of the single-scattering order" is tested as
   `Psi_ms / T_sun` at the ground with the sun at the zenith: (0.018, 0.031, 0.054). Midpoint
   integration puts the zenith texel at (0.9413, 0.8687, 0.7638) against the analytic
   (0.9404, 0.8676, 0.7623), inside the 0.005 tolerance.
4. **Import:** Lossless keeps EXRs as RGBAH; `detect_3d/compress_to=0` stops Godot switching them
   to VRAM compression when WS-10 first samples them in 3D. The include compiles and samples the
   baked texels in both Compatibility and Forward+ (checked with a throwaway render probe).
5. **License:** `notice.code.tidewater` (full MIT text) now exists in
   `docs/THIRD_PARTY_NOTICES.md`. WS-03 already cited it, so it was added here, ahead of WS-01.

- [ ] WS-10 | deps: WS-09 | deliverable: per-frame Hillaire sky-view LUT in a SubViewport (HDR or RGBM) driving the sky dome background, transmittance-coloured limb-darkened sun disk and physically lit clouds, with art-direction exposure/tint/sunset-boost and gradient fallback | allowed files: `scripts/map/view3d/sky_atmosphere_lut.gd`, `scripts/map/view3d/sky_view_lut.gdshader`, `scripts/map/view3d/sky_weather_3d.gdshader`, `scripts/map/view3d/sky_weather_3d.gd`, `scripts/map/view3d/atmosphere_common.gdshaderinc`, `tests/godot/test_sky_atmosphere_lut.gd`, `tests/godot/test_sky_weather_3d.gd`, `docs/SKY_WEATHER_STATE_CONTRACT.md`, `docs/reports/images/ws10_*.png`, `docs/reports/ws10_physical_sky.md`, `tools/capture_ws10_sky_elevations.gd`, `TODO.md` | verify: LUT node/throttle/fallback tests; six-elevation clear captures show blue zenith, red low sun, Earth-shadow band, twilight into stars; R-713 continuity verifiers pass; 60 s day clip without flicker or banding

WS-10 implementation landed (R-895, in review). Decisions (2026-09-25), evidence in
[`docs/reports/ws10_physical_sky.md`](docs/reports/ws10_physical_sky.md):

1. **HDR, not RGBM.** `SubViewport.use_hdr_2d` gives a float target on both renderers (probe read
   back an exact 3.5: RGBAF on Compatibility, RGBAH on Metal), so radiance is stored directly.
2. **Backend quirks.** The kernel indexes texels with `FRAGCOORD` (memory order on every
   backend). On GL Compatibility a 3D/sky shader sampling the ViewportTexture receives
   sRGB-decoded values, so the kernel pre-encodes with the exact inverse curve there
   (`encode_srgb`, keyed on `gl_compatibility`); Metal reads the stored radiance.
3. **Art controls.** `sky_exposure` 0.7 puts the 60-degree horizon within 1% of the old gradient
   luminance on Compatibility. Added `sky_adaptation` (0.6, max gain 4) - a partial eye
   adaptation from the LUT zenith luminance, computed on the GPU - because the fixed scene grade
   left the physical dusk sky about 10x darker than noon. `sun_disk_scale` 0.218 keeps the noon
   disk at the old 2.4 peak; `cloud_sun_scale` 0.08 keeps noon cloud tops near white; the art
   dusk ramp on clouds is kept at `sunset_boost * 2` weight.
4. **Scope additions:** the capture/benchmark/day-sweep tool and the evidence report were not in
   the contract's allowed files and are listed above.

- [ ] WS-15 | deps: WS-04 | deliverable: camera-following 64x64-unit ping-pong SubViewport wave-equation ripple sim (float or packed-16) with impulse queue, deterministic rain droplets, moving-body bow/stern wake and aeration foam, sampled by the water shader for height/normal/foam | allowed files: `scripts/map/view3d/water_ripple_sim.gd`, `scripts/map/view3d/water_ripple_sim.gdshader`, `scripts/map/view3d/map_view_water.gdshader`, `scripts/map/view3d/map_view_water_materials.gd`, `scripts/map/view3d/map_view_3d.gd`, `scripts/map/view3d/sky_weather_3d.gd`, `tests/godot/test_water_ripple_sim.gd`, `docs/reports/images/ws15_*.png`, `docs/reports/ws15_ripple_sim.md`, `tools/capture_ws15_ripples.gd`, `TODO.md` | verify: sim logic tests; 600-frame max-rain stability; rain/storm/moving-body captures and clip without window seams; <= 0.4 ms

WS-15 implementation landed (R-900, in review). Decisions (2026-09-25), evidence in
[`docs/reports/ws15_ripple_sim.md`](docs/reports/ws15_ripple_sim.md):

1. **Float targets, no packed-16.** A probe read signed half-float values back exactly from a
   `use_hdr_2d` SubViewport in both canvas_item and spatial shaders, on Compatibility and on
   Metal. The water shader needs no sRGB workaround.
2. **Slower, smoother waves than the contract sketch.** `c^2` is 0.02 (about 2.1 units/s), not
   0.25, so rain reads as rings and a rowing-pace hull outruns the waves and draws a V. A
   Kelvin-Voigt velocity-Laplacian term (0.07) damps grid-scale chatter. Every impulse is a
   zero-volume Laplacian-of-Gaussian, so rain cannot pile up a standing offset.
3. **Rain has its own 40-slot array**, so the 32-per-step gameplay cap never loses wake slots.
   Aeration comes only from hull forcing. The vertex lift is crest-only, and the shading slope is
   clamped at 0.6.
4. **Evidence.** 600 steps at maximum rain peak at |h| 0.2496 on both renderers. The 10 s storm
   pan shows no window seam. Compatibility costs +0.04 ms at 2560x1440, inside the run noise.
   Metal is vsync-bound. Plates use the WS-04 `--fft` hook.
5. **Scope additions:** the capture tool and the evidence report, listed above.

- [ ] WS-08 | deps: WS-04 | deliverable: runtime shore distance field + generated beach swash sheet with analytic wave sets, shoaling/breaking bore, run-up/backwash with bead/trail foam and meniscus fade, surf turbidity, wall slosh, and deterministic wet-sand drying with residue line | allowed files: `scripts/map/view3d/shore_swash.gdshaderinc`, `scripts/map/view3d/map_view_water.gdshader`, `scripts/map/view3d/map_view_terrain_blend.gdshader`, `scripts/map/view3d/map_view_mesh_builder_terrain_water.gd`, `scripts/map/view3d/map_view_mesh_builder_terrain.gd`, `scripts/map/view3d/map_view_water_materials.gd`, `scripts/map/view3d/map_view_materials.gd`, `scripts/map/view3d/map_view_terrain_materials.gd`, `tests/godot/test_shore_distance_field.gd`, `tests/godot/test_r715_water_material_contract.gd`, `tests/godot/test_r715_water_surface_geometry.gd`, `tools/capture_ws08_shore_swash.gd`, `docs/MAP_AUTHORING.md`, `docs/tasks/water_sky/WS-08_shore_swash.md`, `docs/reports/images/ws08_*.png`, `TODO.md` | verify: shore field tests; map validation/audit/activation; reval_harbor_east clear/storm/night captures and 20 s clip show breaking sets, run-up sheet with fading edge, drying wet sand, and wall slosh

WS-08 implementation landed (R-893, in review). Decisions (2026-09-25), also in the contract's
"Final parameters and decisions" section:

1. **Fixed, quantised period.** `ocean_time` is an absolute clock that wraps every 1638.4 s, so a
   period that follows the sea state would scroll the phase by `t * dP / P^2` during every weather
   transition. The period is ~9.002 s (182 waves = 26 seven-wave sets per wrap, seamless). Sea
   state drives height, break point, run-up and foam instead.
2. **Tide.** High water fills the authored contour exactly, so the swash origin only moves seaward
   on the ebb (`-ebb * tide_shore_retreat * 1.6` units), never inland.
3. **Visibility levers (ADR 0018).** Physical run-up of a Baltic breaker is ~0.4 m, so
   `shore_runup_gain` 3.2 keeps it readable (calm ~0.9, storm ~1.6 units). Shore crest geometry is
   compressed by `shore_geometry_scale` 0.12 and only rises (the bed sits 0.074 units below), and
   the bore is a whiter foam added after the tinted edge foam.
4. **Scope additions:** `map_view_mesh_builder_terrain.gd` (one hook in `build_terrain`),
   `map_view_terrain_materials.gd` (sand layer indices and a material list for the field) and the
   capture tool were not in the contract's allowed files and are listed above. `apply_shore_field`
   re-binds on every terrain tree entry because the materials are shared by all map views.
5. **Minimum tier** is chosen with `MapViewMaterials.set_shore_swash_quality_tier()` at build time
   (like the FFT tier); production does not yet call either tier setter, so both default to
   recommended.

- [ ] WS-06 | deps: WS-04 | deliverable: FFT-path whitecaps from baked persistent foam with a seamless bubble foam tile, fresh/old foam shading, storm wind streaks, and gust/slick modulation; Gerstner Jacobian foam kept only on fallback | allowed files: `scripts/map/view3d/map_view_water.gdshader`, `scripts/map/view3d/map_view_water_materials.gd`, `scripts/map/view3d/ocean_fft_common.gdshaderinc`, `tools/bake_ocean_fft.py`, `tests/python/test_bake_ocean_fft.py`, `assets/water/ocean_fft/foam_tile.png`, `assets/SOURCES.csv`, `tests/godot/test_r715_water_material_contract.gd`, `tools/capture_ws06_whitecaps.gd`, `docs/tasks/water_sky/WS-06_fft_foam_whitecaps.md`, `docs/reports/images/ws06_*.png`, `TODO.md` | verify: foam tile seam test; contract test; clear/overcast/storm/storm-night captures and a 10 s clip show lingering, textured, wind-streaked foam that rides its wave

WS-06 implementation landed (R-891, in review). Decisions (2026-09-25), also in the contract's
"Final parameters and decisions" section:

1. **Coverage.** `foam_coverage` ends at 1.0, not 0.5: with the capped mask the reference sea
   needed the full value to show scattered overcast whitecaps. The weather table carries
   `foam_coverage` calm 0.2 / reference 0.8 / storm 1.8 and `streaks` 0 / 0 / 1.
2. **Storms break more than the bake.** The baked foam only exists where the reference sea broke,
   so the weather scale also lowers the freshness bar and the mask is capped at 1.0 so storm foam
   keeps bubble holes. A thin trail term keeps the decayed tail visible for its few seconds.
3. **Scales.** Foam tile 0.0783 tiles per unit (Tidewater 0.09 per metre x 0.87), streak amount
   0.6 (0.3 was invisible). Streaks and the coarse link use the C0 foam share; the disp atlases
   have no mips, so there is no coarser mip to read.
4. **Seamless drift.** Foam tiles and the gust field move a whole number of tiles or lattice
   periods per 1638.4 s ocean-clock wrap.
5. **Scope additions:** the shared FFT include (foam terms and a C2 gain), the capture tool and
   the contract doc are listed above.

- [ ] WS-02 | deps: none | deliverable: water light() with GGX + Smith visibility + exact dielectric Fresnel, shadow-attenuated, slope-variance roughness; hand-made pow() sun/moon glints removed | allowed files: `scripts/map/view3d/map_view_water.gdshader`, `scripts/map/view3d/map_view_water_materials.gd`, `tests/godot/test_r715_water_material_contract.gd`, `docs/reports/images/ws02_*.png`, `TODO.md` | verify: contract test; noon/sunset/storm/night harbor captures show sea-state-dependent glitter path, no glint in quay shadow, no strobing on the 60 s day cycle

WS-02 implementation landed (R-887, in review). Decisions (2026-09-25), plates in
`docs/reports/images/ws02_*.png` from `tools/capture_ws02_glint.gd`:

1. **Blocker fixed first.** `SkyWeather3D` sent `sun_reflection_color` as `Color(255, 243, 222)`,
   a 0..255 float colour. The water's sky-dome forward scatter multiplied it and turned the whole
   sea white whenever the sun stood ahead of the camera (every afternoon and sunset). It is now
   `Color8`. The WS-13 underwater tint normalises the colour, so it is unaffected.
2. **One light, two bodies.** The DirectionalLight3D is the sun by day and the moon by night, so
   the moon path is the same GGX lobe. The directional gate keeps `sun_reflection_visibility` and
   `low_sun_glitter` for the sun and uses `moon_visibility` for the moon; the moon share fades
   out quadratically over MapViewLighting's -6..0 deg handoff. Local lights keep their glint
   except under foam. No analytic moon lobe was needed.
3. **Diffuse share stays 1.0, not ~0.02.** ALBEDO is the composited bed plus sky reflection that
   was tuned under built-in diffuse; the noon plate matches the WS-06 one. Physical ~0.02 needs
   the sky reflection moved out of ALBEDO, which is WS-11.
4. **Camera geometry.** The gameplay camera's mirror direction points north-west at 30 deg, so
   the noon sun (south) never glints; the path shows from late afternoon. Evidence uses
   `evening` (sun 14.6 deg) and `sunset` (5.1 deg) instead of noon, plus `*_baseline` plates of
   the old shader: the old pow() glint drew no sunset path at all. Hull shadows cut the path
   (quay shadow check). Moon plate: 3 May 1343 01:55 (moon 8 deg, NW), `--no-mist` because the
   pre-dawn mist hides the sea.
5. **No strobing.** 120 frames of the 60 s day cycle at sunset: mean frame-to-frame water
   luminance change 0.0014-0.0016 (old shader 0.0007-0.0016), worst 0.0026. Quick performance
   report (`build/benchmarks/ws02-performance-quick.json`, taken while the headless suite ran):
   Lower Town scene p95 13.86 ms against 13.23 ms for WS-06, inside the 16.67 ms budget.
6. **Scope additions:** `scripts/map/view3d/sky_weather_3d.gd` (the colour fix),
   `scripts/map/view3d/ocean_fft_common.gdshaderinc` (stale comment), `tests/godot/test_map_view_3d_core.gd`
   (it required the removed `sun_alignment`/`moon_alignment` names) and the capture tool.

- [ ] R-908 | deps: none | deliverable: pre-dawn ground mist uses dark moonlit haze at night and pales toward sunrise without changing rain haze | allowed files: `scripts/map/view3d/map_view_lighting.gd`, `tests/godot/test_map_view_lighting.gd`, `docs/reports/images/fog_night_*.png`, `TODO.md` | verify: `--filter=test_map_view_lighting`; night mist luminance at or below night ambient and monotonic toward sunrise; Metal/Compatibility harbour plates at `--date=3-5 --progress=0.08` and sunrise

R-908 implementation landed. `FOG_NIGHT_COLOR` lerps to `FOG_MORNING_COLOR` by `day_blend` only while morning mist is present; rain-only haze keeps the previous pale-to-rain lerp. Evidence: `docs/reports/images/fog_night_{metal,opengl3}_{night,sunrise}_harbour.png` (3 May 1343; night progress 0.08 mean luma ~13, sunrise 0.157 mean luma ~104).

- [ ] R-911 | deps: R-908 | deliverable: peak morning mist keeps harbour waterline and boats readable by capping fog density and height-density | allowed files: `scripts/map/view3d/map_view_lighting.gd`, `tests/godot/test_map_view_lighting.gd`, `docs/reports/images/fog_dawn_*.png`, `TODO.md` | constraints: do not remove mist or change rain haze; keep the R-908 night colour path | verify: `--filter=test_map_view_lighting`; waterline height-fog cover stays in 0.25-0.55; Metal/Compatibility harbour plates at `--date=3-5` sunrise and night

R-911 implementation landed. Peak height density 1.1 -> 0.20 so Godot waterline cover is ~0.50 instead of ~0.98; distance density 0.018 -> 0.010. Rain-only haze stays 0.0035. Evidence: `docs/reports/images/fog_dawn_{metal,opengl3}_{sunrise,night}_harbour.png` (3 May 1343; sunrise 0.157 mean luma ~66/64, night 0.08 mean luma ~6/5). `--filter=test_map_view_lighting` 7/7.

- [ ] WS-11a | deps: WS-07 | deliverable: lighting passes presentation sunset_factor and the active SkyWeather3D preset `darken` into apply_water_sky_reflection so water haze, sky-reflection darkening and sunset tint follow weather | allowed files: `scripts/map/view3d/map_view_lighting.gd`, `scripts/map/view3d/map_view_materials.gd`, `tests/godot/test_map_view_lighting.gd`, `docs/reports/images/ws11a_*.png`, `TODO.md` | verify: `--filter=test_map_view_lighting` asserts overcast water `cloud_darken` is 0.72; clear/overcast/sunset harbour plates

WS-11a implementation landed (R-930). `MapViewLighting.apply_cycle_progress` now forwards `sunset_factor` and `water_cloud_darken()` (named preset `darken`, overcast 0.72). Presentation still has no blended `cloud_darken` field; WS-11 can replace the lookup. `--filter=test_map_view_lighting` 8/8.

R-933 harbour plates (2026-09-26) used `tools/capture_ws02_glint.gd` on Harbor North, then copied to `docs/reports/images/ws11a_*` and restored the `ws02_*` originals. Clear noon, overcast noon, and clear sunset exist on Metal and Compatibility; overcast `--set=cloud_darken:0` off pairs sit beside them. Water-crop luma: Metal clear 123, overcast 81, sunset 68; Compatibility 100 / 59 / 49. Isolated `cloud_darken` is a pale overcast veil, so the on plate is about +7 luma versus off; the weather overcast sea is still about -42 versus clear noon. The R-715 helper now forwards `sunset_factor` and `Lighting.water_cloud_darken()`. `--filter=test_map_view_lighting,test_r715_water_weather_sync` 14/14. WS-07 overcast plates were not retuned.

- [ ] WS-11 | deps: WS-10, WS-02 | deliverable: AtmosphereCpu (sun colour, sky irradiance, horizon colour from static LUT images, 4 Hz, smoothed) driving DirectionalLight colour/energy, ambient and fog, and water reflections sampling the shared sky-view LUT; old colour constants become art tints | allowed files: `scripts/map/view3d/atmosphere_cpu.gd`, `scripts/map/view3d/map_view_lighting.gd`, `scripts/map/view3d/map_view_water_materials.gd`, `scripts/map/view3d/map_view_materials.gd`, `scripts/map/view3d/map_view_water.gdshader`, `scripts/map/view3d/sky_weather_3d.gd`, `scripts/map/view3d/atmosphere_common.gdshaderinc`, `tests/godot/test_atmosphere_cpu.gd`, `tests/godot/test_r715_water_weather_sync.gd`, `tests/godot/test_weather_realism.gd`, `docs/reports/images/ws11_*.png`, `TODO.md` | verify: AtmosphereCpu oracle/perf tests; sunset captures show sun disk, lit walls and sea glitter in one hue and the Earth-shadow band reflected in the sea; 60 s day clip without colour stepping

WS-11 implementation landed (R-896, in review). Decisions (2026-09-26), plates in
`docs/reports/images/ws11_*.png` from `tools/capture_ws11_sky_lighting.gd` (2x2 sheets: gameplay
camera over the harbour and the quay, then a low view towards and away from the sun):

1. **Sampler budget.** GL Compatibility links at most 16 fragment samplers and the water shader
   was at the limit, so the sky-view LUT failed to link (`uses 17 samplers`; the headless suite
   cannot see this). The WS-07 fine and broad caustic tiles (both 512x512 L8) are now packed at
   runtime into one RG8 texture (`MapViewWaterMaterials.caustic_tiles_texture()`, uniform
   `caustics_tiles`, `_caustic_tile(..., channel, ...)`), which also frees the slot WS-12 will
   need. No asset or bake change.
2. **Sun colour hand-off.** The physical sun colour (the transmittance that colours the WS-10
   disk) hands off to `SUN_NIGHT_COLOR` over the same -6..0 degree `sun_light_weight` that turns
   the light direction, not over `day_blend` (0.74 at 2 degrees would mix in 26% moonlight).
   At 2 degrees the light, the disk and the water sun colour are the same (1.0, 0.545, 0.146),
   hue 28.0 on both renderers. Below the horizon the LUT clamps to its horizon column.
3. **Energy relative to local noon.** `physical_sun_energy` divides by the culmination of the
   capture date, so noon keeps `SUN_DAY_ENERGY` (existing authored-noon tests stay exact) and it
   replaces `SUNSET_ENERGY_DIM` in the physical path instead of stacking on it
   (`weather_sun_energy`). Clamp 0.15-1 as specified.
4. **Hue physical, luminance calibrated.** Ambient and mist take the physical hue at the linear
   luminance of `AMBIENT_DAY_COLOR` / `FOG_MORNING_COLOR`, so the ADR 0018 grade, R-908 night
   mist and R-911 cover stay tuned. Noon ambient (0.50, 0.70, 1.00) against the old
   (0.66, 0.70, 0.74); civil twilight skylight is violet. `*_ART_TINT` are white.
5. **Fog follows the horizon the dome draws.** The raw LUT horizon at sunrise is red-orange at
   every azimuth; the dome looks purple away from the sun only because it adds the night
   gradient floor. `presentation.horizon_display_color` mirrors that composition (LUT x exposure
   x CPU eye adaptation + night horizon x (1 - day_blend)) and weights every azimuth's hue
   equally, because a radiance mean is dominated by the Mie glow (7x) that Godot's
   `fog_sun_scatter` already draws. First-light mist reads dusty rose (0.63, 0.43, 0.37) where
   the old mist was slate (0.45, 0.49, 0.54) under a warm sky; its saturation is the main item
   for the art review (`FOG_ART_TINT`). Rain haze keeps its lerp on top and is unchanged.
6. **Water.** `_sky_dome_reflection` samples the dome's LUT through the new shared
   `atmosphere_sky_view_uv` with the dome's exposure, tint, adaptation, night floor and sunset
   boost; the gradient stays as the fallback. HDR storage (WS-10 decision 1) means no RGBM decode
   mode. The sun azimuth travels in `sun_direction`; `presentation.sun_azimuth` is informational.
   The sky shader keeps its private copy of the lookup because it was outside the allowed files.
7. **Cadence.** Each `SkyWeather3D` owns an `AtmosphereCpu` tracker: evaluation at most every
   0.25 s of real time, exponential smoothing with tau 0.3 s, snap on the first sample or a sun
   jump over 10 degrees (captures, save restore). Full evaluation 0.33 ms averaged over 100 runs
   headless. 60 s day clip (`--day-sweep`, gameplay camera): largest frame-to-frame step of the
   light colour 0.0054 / ambient 0.0022 on Compatibility and 0.0167 / 0.0039 on Metal. The Metal
   peak sits in pre-dawn twilight (progress 0.124): the moon-to-sun colour hand-off spans 6
   degrees, about one second of the compressed day, so it is a fast continuous ramp, not a 4 Hz
   step (a step would need a >10 degree jump inside one evaluation interval). Quick performance
   report (`build/benchmarks/ws11-performance-quick.json`): Lower Town scene p95 12.19 ms, inside
   the 16.67 ms budget; the 4 Hz evaluation costs about 1.3 ms per real second.
8. **Evidence reading.** Walls, disk and glitter share one hue at 2 degrees on both renderers;
   noon boat shadows are blue-filled; rain plates match today's rain; the gameplay-camera sea at
   sunset mirrors the violet-pink twilight sky instead of the old day gradient. The Earth-shadow
   band opposite the sun is visible in the sky at -3 degrees, but its reflection is barely
   readable because the low sea is almost black there; the art review should judge it.
9. **60 degrees is unreachable** at Reval (culmination 53.7 degrees on 21 June 1343); the `e60`
   plates are noon. `-3` degree gameplay views are near-black in both the physical and the legacy
   plates: dusk darkness predates WS-11.
10. **Scope additions:** `scripts/map/view3d/caustics_common.gdshaderinc`,
   `scripts/map/view3d/underwater_pass.gd`, `scripts/map/view3d/underwater_pass.gdshader`,
   `tests/godot/test_underwater_pass.gd`, `tests/godot/test_r715_water_material_contract.gd`
   (sampler packing), `tests/godot/r715_water_test_support.gd` (mirrors the lighting call) and the
   capture tool. Two uncommitted WS-02 leftovers ship in the same commit because they share
   files: the `Color8` fix in `sky_weather_3d.gd` (same hunk) and the WS-02 block above.
   `tests/godot/test_map_view_3d_core.gd` stays with R-887. The old colour constants stay until
   the review accepts the plates.

- [ ] WS-12 | deps: none | deliverable: shared sky_clouds.gdshaderinc cloud field published via global uniforms and a screen-space cloud-shadow pass that projects it along the sun onto world depth, scaled by direct-sun share, outdoor only | allowed files: `scripts/map/view3d/sky_clouds.gdshaderinc`, `scripts/map/view3d/sky_weather_3d.gdshader`, `scripts/map/view3d/sky_weather_3d.gd`, `scripts/map/view3d/cloud_shadow_pass.gd`, `scripts/map/view3d/cloud_shadow_pass.gdshader`, `scripts/map/view3d/map_view_3d.gd`, `project.godot`, `tests/godot/test_cloud_shadow_pass.gd`, `tests/godot/test_sky_weather_3d.gd`, `docs/reports/images/ws12_*.png`, `TODO.md` | verify: pass lifecycle/sun-share tests; sky byte-identical after include move; partly-cloudy clip shows soft downwind patches that kill water glint, none when overcast or at night; pass <= 0.3 ms

WS-12 headless pass landed (R-897, `752e7c5b`). GPU verify items 2-4 are **R-1033**.

- [ ] R-1033 | deps: R-897 | deliverable: harbour GPU plates, sky include-parity plates, 20 s partly-cloudy clip, and isolated 1080p pass-cost measurement for WS-12 | allowed files: `tools/capture_ws12_cloud_shadows.gd`, matching UID, `docs/reports/images/ws12_*.png`, `docs/tasks/water_sky/WS-12_cloud_shadow_map.md`, `tests/godot/test_cloud_shadow_pass.gd`, `TODO.md` | verify: `--filter=test_cloud_shadow_pass,test_sky_weather_3d`; Metal/Compatibility harbour partly/overcast/night plus clip; sky 3x3 plates; `--bench` delta <= 0.3 ms at 1080p

R-1033 capture tool landed. Headless 38/38. Valid plates: clear `--no-pass`, overcast and night
on Metal and Compatibility, plus `ws12_metal_clear_sky_e20.png`. Pass-on partly-cloudy harbour
plates are blocked: `hint_screen_texture` in the capture path is a default buffer. Bench
delta -0.028 ms at 1080p Metal. Follow-up **R-1048**: play-path screen-texture capture.

- [ ] R-1048 | deps: R-1033 | deliverable: play-path harbour plates (partly 0.45 / overcast / night, Metal and Compatibility) and a 20 s clip where CloudShadowPass samples the same screen the player sees; optional shader skip when sun_share is 0 | allowed files: `scripts/map/view3d/cloud_shadow_pass.gdshader`, `scripts/map/view3d/cloud_shadow_pass.gd`, `tools/capture_ws12_cloud_shadows.gd`, `docs/reports/images/ws12_*.png`, `docs/tasks/water_sky/WS-12_cloud_shadow_map.md`, `TODO.md` | verify: `--filter=test_cloud_shadow_pass,test_sky_weather_3d`; pass-on vs `--no-pass` differ by shadow darkening on water/ground, not by replacing the sea with beige or noise; clip patches move downwind; overcast/night stay patch-free

R-1048 implementation landed. Decision: drop `hint_screen_texture` and
`blend_mul` the live framebuffer, then `discard` when `sun_share <= 0.01`.
That is the play path the player sees; a default-buffer resample cannot
replace the sea. Overlay hide at the same threshold stays as a second skip.
`--filter=test_cloud_shadow_pass,test_sky_weather_3d` 40/40. Metal pass-on
harbour luma 59.8 vs `--no-pass` 96.4, both B>R ~0.94 (real sea, not beige).
Compatibility is darker on the same multiply; follow-up **R-1051** owns a
GL strength match. Clip cells change neighbor mean-abs 0.24-0.41 (downwind).
Overcast and night keep `sun_share=0` and no patches.

- [ ] R-1051 | deps: R-1048 | deliverable: Compatibility cloud-shadow multiply matches Metal harbour readability | allowed files: `scripts/map/view3d/cloud_shadow_pass.gdshader`, `tools/capture_ws12_cloud_shadows.gd`, `docs/reports/images/ws12_opengl3_*.png`, `docs/tasks/water_sky/WS-12_cloud_shadow_map.md`, `TODO.md` | verify: `--filter=test_cloud_shadow_pass,test_sky_weather_3d`; GL pass-on vs `--no-pass` B>R ~0.94 and luma drop comparable to Metal

R-1051 implementation landed. Compatibility `blend_mul` stores dest_lin *
factor as linear bytes that plates read as sRGB. `COMPAT_BLEND_GAIN`
(0.5 / IEC linear(0.5) ≈ 2.336) applies only on
`RENDERER_COMPATIBILITY`. Cloud-field maths and sample counts stay
shared. `--filter=test_cloud_shadow_pass,test_sky_weather_3d` 40/40.
GL pass-on luma 55.5 vs `--no-pass` 108.3 (ratio 0.51; Metal 59.6/96.4
= 0.62). B>R 0.938. Clip neighbor mean-abs 0.023-0.159 (downwind).
Overcast and night keep `sun_share=0`. Handoff: QA visual review
(**R-1052**).

- [ ] R-1097 | deps: R-1091 | deliverable: scale capture_ws12 sky origin by cell_size and recapture sky-identity plates | allowed files: `tools/capture_ws12_cloud_shadows.gd`, matching UID, `docs/reports/images/ws12_*.png`, `docs/tasks/water_sky/WS-12_cloud_shadow_map.md`, `TODO.md` | verify: capture log prints WS12_SKY_FOCUS at the water cell centre; `--filter=test_cloud_shadow_pass,test_sky_weather_3d`; sky identity plates match the include-parity sheet; harbour pass-on plates unchanged

R-1097 implementation landed. Sky origin multiplies `_open_water_cell` by
`definition.cell_size`. Log: `WS12_SKY_FOCUS map=reval_harbor_north
cell=4.5,4.5 world=4.500,4.500` (in-sea, not the quay).
`--filter=test_cloud_shadow_pass,test_sky_weather_3d` 40/40. Recaptured
`ws12_metal_clear_sky_e20.png` and `ws12_opengl3_clear_sky_e20.png`.
Harbour gameplay plates were not recaptured.

- [ ] R-941 | deps: WS-11 | deliverable: sky_weather_3d.gdshader calls shared atmosphere_sky_view_uv and ATMO_SKY_VIEW_HEIGHT_KM; private sky_view_uv / SKY_VIEW_HEIGHT_KM deleted | allowed files: `scripts/map/view3d/sky_weather_3d.gdshader`, `tests/godot/test_sky_weather_3d.gd`, `TODO.md` | verify: `--filter=test_sky_weather_3d,test_sky_atmosphere_lut`; Compatibility `tools/capture_ws10_sky_elevations.gd -- --elevation=5` plate within 1 LSB of the pre-change plate; no `vec2 sky_view_uv(` left

R-941 implementation landed. The dome samples the sky-view LUT through
`atmosphere_sky_view_uv(dir, sun_direction, sky_lut_size)` and uses `ATMO_SKY_VIEW_HEIGHT_KM`
for the sun-disk transmittance height. `--filter=test_sky_weather_3d,test_sky_atmosphere_lut`
35/35. Compatibility `ws10_opengl3_clear_lut_e5.png` vs a HEAD recapture is pixel-identical
in the top 40% sky (0 differing pixels). Full-frame 1 LSB fails on water/boats: two after
captures of the same shader also differ there (max 116) while the sky stays 0.

- [ ] R-942 | deps: WS-11 | deliverable: civil twilight (sun 0 to -6 deg) keeps harbour ambient readable and brighter than midnight, fading into the ADR 0018 night floor | allowed files: `scripts/map/view3d/map_view_lighting.gd`, `tests/godot/test_map_view_lighting.gd`, `tests/godot/test_map_view_3d_lighting.gd`, `docs/reports/images/twilight_*.png`, `TODO.md` | verify: `--filter=test_map_view_lighting,test_map_view_3d_lighting`; twilight (-3) ambient energy x luminance above midnight and below noon, monotonic from -6 to 0; Metal/Compatibility harbour plates

R-942 implementation landed. Decisions (2026-09-26):

1. **Cause.** `daylight_blend` is a -6..+6 smoothstep, so sun at -3 deg is already
   ~0.16 and ambient/post-grade crush to night under a still-bright dome.
2. **Fill only.** Ambient colour/energy and post-grade ease out to the existing
   horizon blend (0.5) at 0 deg and stay on `daylight_blend` at night (<= -6)
   and after sunrise. Directional sun energy is unchanged (no new lights).
   Morning mist stays on `day_blend` (R-908 / R-911).
3. **Verify.** `--filter=test_map_view_lighting` 9/9, including the new monotonic
   twilight metric. `--filter=test_map_view_3d_lighting` 13/15: the two failures
   are `st_catherines_church` authored as `house` without glass panes. That path
   never calls `MapViewLighting` and is a pre-existing church-mesh gap.
4. **Plates.** Shared worktree has Godot `--editor`; Metal/Compatibility harbour
   plates are **R-988**, not taken here.

- [ ] WS-07 | deps: WS-01, WS-03 | deliverable: photon-splat caustic tiles (fine/broad) baked from the FFT spectrum and applied as bed light along the refracted sun ray with depth focus, anisotropic-safe gradients, dispersion and cloud/sun gating; sine-lattice caustics removed | allowed files: `tools/bake_ocean_fft.py`, `tests/python/test_bake_ocean_fft.py`, `assets/water/ocean_fft/caustics_fine.png`, `assets/water/ocean_fft/caustics_broad.png`, `assets/SOURCES.csv`, `scripts/map/view3d/map_view_water.gdshader`, `scripts/map/view3d/map_view_water_materials.gd`, `tests/godot/test_r715_water_material_contract.gd`, `docs/reports/images/ws07_*.png`, `TODO.md` | verify: tile seam/energy tests; contract test; noon/sunset/overcast/night captures and an orbit clip show a depth-focused, sun-leaning, shimmer-free caustic net on the bed

WS-07 implementation landed (R-892, in review). Decisions are in the contract's "Final parameters
and decisions": the bands extend to 0.12 m / 0.5 m because the specified cut-offs do not focus;
`caustics_profile.json` beside the tiles; `min(a, b)` mean divided out; apparent depth x15 like
`sigma_t`; art knobs `caustic_pattern_scale` 3.0 and `caustic_strength` 2.8 until WS-11 moves the
sky reflection out of ALBEDO; the cloud gate uses `sun_reflection_visibility` because water never
receives `cloud_darken`. Scope additions: `tools/capture_ws07_caustics.gd`,
`assets/water/ocean_fft/caustics_profile.json` and the `.import` sidecars,
`tests/godot/test_coastal_sea_3d.gd` (it required `_bed_caustics`) and the contract doc.

- [ ] WS-13 | deps: WS-01, WS-05, WS-07 | deliverable: UnderwaterPass (AIR/STRADDLE/UNDER from the camera height) screen pass with per-pixel FFT waterline and meniscus, Beer-Lambert medium with HG sun in-scatter, submerged caustics and marched light shafts; water underside Snell's window with total internal reflection; SFX low-pass; wet lens on surfacing; P0-227 tint removed | allowed files: `scripts/map/view3d/underwater_pass.gd`, `scripts/map/view3d/underwater_pass.gdshader`, `scripts/map/view3d/ocean_fft_common.gdshaderinc`, `scripts/map/view3d/map_view_water.gdshader`, `scripts/map/view3d/map_view_3d.gd`, `audio/default_bus_layout.tres`, `tools/capture_underwater.gd`, `tests/godot/test_underwater_pass.gd`, `tests/godot/test_r715_water_material_contract.gd`, `tests/godot/test_ocean_fft_material.gd`, `docs/tasks/water_sky/WS-13_underwater_view_pass.md`, `docs/reports/images/ws13_*.png`, `TODO.md` | verify: state/bus/lens tests; include refactor pixel-identical; under/up/straddle/night/storm captures and dip clip; pass <= 1.0 ms under water and 0 in air

WS-13 implementation landed (R-898, in review) ahead of its dependencies. Decisions (2026-09-25),
also in the contract's "Final parameters and decisions" section:

1. **Dependency stand-ins.** WS-01 is not in: the shared include now owns `WATER_IOR` and the
   per-channel `WATER_SIGMA_T_PER_M` for WS-01 to adopt. WS-05 is not in: the camera surface is the
   rest plane plus tide, and the STRADDLE band is widened on the AIR side by the terrain's crest
   budget (`wave_height`). WS-07 tiles are now bound (WS-13f / R-931); the procedural
   `_uw_caustic()` stand-in is gone.
2. **Surface from below in the pass too.** `hint_screen_texture` is copied before the transparent
   pass, so it never contains the water; pixels whose eye ray meets the surface first are shaded
   in the pass with the same `_uw_window()` / `_uw_below_color()` as the water underside.
3. **Underside test is the camera height**, not `FRONT_FACING`: map-edge water strips are wound
   the other way and read as back faces from the gameplay camera.
4. **Reverse Z everywhere.** Godot 4.7 Compatibility also uses reverse Z (near NDC z = +1, empty
   depth 0) with a -1..1 NDC range.
5. **Thin view water.** The view water column is ~9 mm (bed recessed 0.08, surface lift 0.006 plus
   tide), so the under-water plates show the medium, Snell's window, waterline and lens, but no
   metres of fading distance. Real underwater depth is a follow-up before WS-14.
6. **Tests file** `test_ocean_fft_material.gd` (reads the include too) was added to the allowed files.

- [ ] WS-13c | deps: WS-13 | deliverable: CC0/attributed submerge and emerge one-shots through the audio attribution pipeline, played from UnderwaterPass on AIR->UNDER and UNDER->AIR; emerge is unfiltered after the SFX low-pass opens | allowed files: `scripts/map/view3d/underwater_pass.gd`, `sounds/water/*`, `tools/audio/generate_water_cross_clips.py`, `tools/verify_water_cross_clips.py`, `tools/generate_credits.py`, `CREDITS.md`, `assets/SOURCES.csv`, `tests/godot/test_underwater_pass.gd`, `tests/python/test_verify_water_cross_clips.py`, `TODO.md` | verify: `--filter=test_underwater_pass`; `python3 tools/verify_water_cross_clips.py`; credits generator and asset provenance validators pass

WS-13c implementation landed (R-903). Decisions (2026-09-26):

1. **In-house synthesis, not a field recording.** `tools/audio/generate_water_cross_clips.py` bakes two deterministic mono MP3 one-shots (lavfi seeds 903101-903203) so the row stays commercially usable without an external recordist. Attribution still goes manifest -> `generate_credits.py` -> CREDITS.md.
2. **One cue per crossing.** AIR->UNDER plays `submerge` immediately. UNDER->AIR queues `emerge` and plays it only after `lowpass_mix` reaches 0, so the splash is not still under the 700 Hz cutoff. STRADDLE and hysteresis bobbing fire nothing. Diving again during the fade cancels the pending emerge.
3. **Evidence:** `test_underwater_pass` crossing and cancel cases; `python3 tools/verify_water_cross_clips.py`. Follow-up R-915 replaces the synthetic Foley with a real harbour splash when sourced.

R-915 implementation landed. Decisions (2026-09-26):

1. **Field recordings, not lavfi.** `submerge.mp3` is a 1.40 s trim of blaukreuz FS 195877 (Brela harbour jetty jump, CC0). `emerge.mp3` is a 1.10 s trim of morganveilleux FS 389987 (water-lift surface-break, CC0). Same runtime paths, 44.1 kHz mono 128 kbps, loudnorm -18 LUFS.
2. **HQ preview cache.** Original 24-bit masters need a Freesound login. The public HQ previews live in `sounds/water/source/` behind `.gdignore`; `generate_water_cross_clips.py` rebakes from that cache.
3. **Evidence:** `python3 tools/verify_water_cross_clips.py`; `--filter=test_underwater_pass`; asset provenance validators. A named harbour-dip listen is still a human check.

- [ ] WS-13b | deps: WS-13 | deliverable: view-only sea basin under open-sea cells (shallow 1.0, deep 3.6 units below the flat gameplay bed; natural banks shelve, pier/stone edges drop), sand/silt seabed, border seabed apron, water shader measures its optical column to the flat bed so the top-down look is unchanged | allowed files: see `docs/tasks/water_sky/WS-13b_harbour_basin_depth.md` | verify: `--filter=test_ws13b_sea_basin_depth` and the water suites; harbour overview parity plates; `tools/capture_underwater.gd` under/up/sun/straddle/night/storm/dip plates on Metal and Compatibility

WS-13b implementation landed (R-901, in review). Decisions (2026-09-25), full list in the task file:
the gameplay bed, collision and water surface are unchanged; the only top-down change is that the
dark grass stripes where the flat bed poked through FFT troughs are gone; the FFT geometry budget is
kept; readable light shafts were not reached (procedural caustic period equals the march step) and
move to a follow-up with WS-07.

- [ ] R-904 | deps: WS-13b, WS-13f | deliverable: readable slanted underwater light shafts over the WS-13b basin (board title "WS-13c"; not the WS-13c SFX row above), dimmed at night and in storms | allowed files: `scripts/map/view3d/underwater_pass.gdshader`, `scripts/map/view3d/ocean_fft_common.gdshaderinc`, `tests/godot/test_underwater_pass.gd`, `tools/capture_underwater.gd`, `docs/tasks/water_sky/WS-13_underwater_view_pass.md`, `docs/reports/images/ws13c_*.png`, `TODO.md` | verify: `ws13c_under_{sun,horizontal}_{gl,metal}.png` show distinct beams (A/B `ws13c_under_horizontal_noshafts_*`); `--filter=test_underwater_pass` green; pass <= 1.0 ms at 1080p (`--bench=600`); AIR cost 0

R-904 implementation landed (in review). Decisions (2026-09-27), details in the WS-13 task file:
shafts sample their own prefilter of the WS-07 broad tile (20 m patch, mip 3, focus smoothstep
1.3-2.0) at the surface entry point along the refracted sun, instead of the bed net; the march is
stratified importance sampling of exp(-t / 3.5 m) over 12 m; shaft phase g = 0.5; overcast removes
collimation (`1 - smoothstep(0.1, 1.0, cloud_darken)`). IGN jitter kept (white noise was grainier).

- [ ] WS-13d | deps: WS-13b | deliverable: view-only stone-filled log crib and guide piles under timber landing decks down to the WS-13b rendered bed (steep pier face in the bed, logs and piles under the surface), no collision/nav/content change | allowed files: see `docs/tasks/water_sky/WS-13d_pier_cribs.md` | verify: `--filter=test_ws13d_pier_cribs` and `--filter=test_ws13b_sea_basin_depth`; `ws13d_under_horizontal_{metal,gl}.png` show the crib; GL overview A/B differs only at the pier tips

WS-13d implementation landed (R-905, in review). Decisions (2026-09-26) are in the task file:
timber decks leave the hard-bank field for a 12-per-cell crib face; logs follow the jittered
rendered face; everything stays 0.22 units under the rest surface; the crib is a reconstruction,
not an attested 1343 structure.

- [ ] WS-13e | deps: WS-13d | deliverable: review Harbor East and Saaremaa cribs; add saddle-notched tip corners and visible stone fill under CRIB_TOP_CLEARANCE without a third MeshInstance | allowed files: `scripts/map/view3d/map_view_pier_crib_builder.gd`, `scripts/map/view3d/map_view_mesh_builder_config.gd`, `tests/godot/test_ws13d_pier_cribs.gd`, `docs/tasks/water_sky/WS-13d_pier_cribs.md`, `docs/reports/images/ws13e_*.png`, `TODO.md` | verify: `--filter=test_ws13d_pier_cribs`; Metal/Compatibility `under_horizontal` plates on both maps; GL overview plates stay under the WS-13d waterline budget

WS-13e implementation landed (R-921). Decisions are in the WS-13d task file: tip corners emit a
saddle notch instead of a round cap; rubble shares the logs node as a second surface; Harbor East
and Saaremaa keep two MeshInstance children. Evidence: `docs/reports/images/ws13e_*.png`.
`--filter=test_ws13d_pier_cribs` 9/9.

R-939 (2026-09-26) revises the extras after `r929_crib_visual_review.md` REJECT: irregular interior
stone instead of the exterior box diamond, and a carved U-saddle with aligned tip ends so Saaremaa
does not read as truncated pipes. Compatibility under-water frames stay with R-932.
`--filter=test_ws13d_pier_cribs` 11/11. Metal plates recaptured; GL overviews still under the
waterline. QA named review is the handoff.

- [ ] WS-13f | deps: WS-07, WS-13 | deliverable: UnderwaterPass samples the WS-07 caustic tiles instead of the procedural stand-in so submerged surfaces and shafts match the bed net | allowed files: `scripts/map/view3d/underwater_pass.gd`, `scripts/map/view3d/underwater_pass.gdshader`, `scripts/map/view3d/caustics_common.gdshaderinc`, `scripts/map/view3d/map_view_water.gdshader`, `tests/godot/test_underwater_pass.gd`, `tests/godot/test_r715_water_material_contract.gd`, `docs/reports/images/ws13f_*.png`, `TODO.md` | verify: `--filter=test_underwater_pass,test_r715_water_material_contract`; water include move pixel-identical; `tools/capture_underwater.gd` under/up plates show the same net scale as WS-07

WS-13f implementation landed (R-931). `_caustic_stretch` / `_caustic_tile` moved unchanged into
`caustics_common.gdshaderinc`. The pass binds the WS-07 tiles; shafts stay on one tile (2 samples)
so the march budget is unchanged. GPU under/up plates are a follow-up while a Godot editor holds
the worktree.

- [ ] WS-14a | deps: WS-13 | deliverable: ADR 0021 swimming and diving naming the removed scope, allowed water/maps, player-only traversal layer, breath/gear/combat/consequence rules, canon note, asset follow-ups and save fields | allowed files: `docs/adr/0021-swimming-and-diving.md`, `TODO.md` | verify: active docs check; maintainer acceptance recorded in ADR status
- [ ] WS-14b | deps: WS-14a, WS-13, WS-05 | deliverable: PlayerSwimState (walk/wade/swim/dive/climb-out, FFT surface float, player-only swimmable traversal, ADR rules) with input, presentation hooks and save/load | allowed files: per accepted ADR 0021 | verify: swim state + save tests; map audits unchanged; keyboard/gamepad clip of wade/swim/dive/surface/climb-out

WS-14a drafted (R-899): [ADR 0021](docs/adr/0021-swimming-and-diving.md) is **Proposed**. It lists
scope-trade candidates with costs and recommends deferring Smuggling Run, but the maintainer picks.
Proposed rules: wading in `shallow_water`, swimming in `water`/`deep_water`, rivers stay blocking;
harbour maps only behind a per-map `swimming_allowed` flag; player-only `is_swimmable_cell` layer
(NPC pathing and audits unchanged); 20 s breath, no drowning death; 12 kg and no `body` armour to
swim; no combat in water; optional save fields. WS-14b stays blocked until acceptance.

- [x] WS-14c | deps: WS-14a, WS-13, WS-15 | deliverable: Kalev wades, swims and dives (player-only water layer on CollisionLayers.WATER, depth-driven PlayerSwimState, breath, combat lock, procedural crawl and tread, camera lift, wake) plus a clean Compatibility underwater tint | allowed files: `scripts/player.gd`, `scripts/player/player_swim_state.gd`, `scripts/player/player_water_traversal.gd`, `scripts/characters/swim_stroke_modifier.gd`, `scripts/map/view3d/map_view_swimmer_presenter.gd`, `scripts/map/view3d/map_view_runtime_actors.gd`, `scripts/map/view3d/map_view_runtime_camera_follow.gd`, `scripts/map/view3d/map_view_3d.gd`, `scripts/map/view3d/underwater_pass.gdshader`, `scripts/map/map_scene_bootstrap.gd`, `scripts/physics/collision_layers.gd`, `project.godot`, `tools/capture_swim.gd`, `tests/godot/test_player_swim_state.gd`, `tests/godot/test_player_water_traversal.gd`, `docs/adr/0021-swimming-and-diving.md`, `docs/CONTROLS.md`, `docs/CANON.md`, `TODO.md` | verify: `--filter=test_player_swim_state,test_player_water_traversal,test_map_scene_bootstrap,test_underwater_pass`; map audit/activation/conversion and world-layout checks unchanged; `tools/godot_render.sh --script tools/capture_swim.gd` plates wade/swim/dive on Kalamaja | closed: 2026-09-29
WS-14c landed on the maintainer's direct request ("enter the water, walk on shallow water, swim or even dive"), recorded as acceptance in ADR 0021's Status. Open follow-ups: the scope trade row of Decision 1 (maintainer choice), the 12 kg / body-armour gate and climb-out ladders, stroke and splash SFX, swim clips instead of the procedural stroke, R-958 drowning, NPC swimming, and a fix for the Compatibility screen/depth sampler read-back that forced the tint-only pass.

## Coastal realism pack (maintainer request, 2026-09-26)

Contracts: [`docs/tasks/coast/README.md`](docs/tasks/coast/README.md). Task board epic R-947.
Raised after reviewing Kalamaja (`reval_harbor_east`) in play. The water and sky pack fixed the sea
surface, sky and underwater optics; this pack fixes what the sea meets - ground materials, shore
silhouette, depth profile, vessels, wind, and the fact that Kalev cannot enter the water.

Measured baseline (2026-09-26, blueprint compiled and `MapVerification.is_walkable_cell` flood-filled;
1 cell = 0.87 m): `reval_harbor_east` 144x80, 41.7% water, 37.8% walkable, elevation span **0.00..0.05**;
`reval_harbor_north` 160x108, 49.5% water, 36.9% walkable, span 0.00..0.60; `world.saaremaa` 104x60
(90x52 m), 28.5% water, **41.8% walkable (2610 cells)**, **zero elevation profiles**. Root causes:
`sand`/`coast_sand` have no texture at all (`PATTERN_SPECKLE`), `grass`/`mud`/`limestone_rubble` are
albedo-only at 512, there are no rock/pebble/algae props, the sea edge is a full-width rect, the boats
are two primitive builders with a static sail, and `SkyWeather3D.wind_direction_xz()` returns a
compile-time constant so wind never changes direction anywhere in the game.

- [ ] R-948 | deps: none | deliverable: 2048 three-map PBR sets for coast_sand, sand, shore_shingle, mud and grass plus a two-scale anti-tiling detail blend, replacing the procedural sand speckle | allowed files: per docs/tasks/coast/CO-01_coastal_ground_materials.md | verify: `--filter=test_terrain_material_channels,test_r715_water_material_contract`; asset sources/lint/storage validators; Kalamaja gameplay and close plates before/after on Compatibility and Metal show grain, relief and no tile grid; quick performance report inside budget

R-948 implemented 2026-09-28 (in review): five PBR ground families (albedo 2048, normal/roughness 1024, three texture arrays) sampled per fragment; the P0-219 per-vertex plate sampling was the main blur cause. Storage +44.2 MiB, all files < 10 MiB. Evidence and decisions: [`docs/reports/co01_coastal_ground_materials.md`](docs/reports/co01_coastal_ground_materials.md). Open: named art review of the plates.
- [ ] R-949 | deps: R-948 | deliverable: shore boulder/stone-cluster/pebble-patch/wrack/algae GLB family with waterline-aware deterministic scatter and collision only above 1.0 m | allowed files: per docs/tasks/coast/CO-02_shore_debris_props.md | verify: `--filter=test_shore_debris_scatter,test_shore_distance_field`; blueprint validate, map audit and activation; asset sources/lint/storage; walkable region unchanged at 4326 (harbor east) and 6333 (harbor north); Kalamaja cove/spit/underwater plates before/after
R-949 implemented 2026-09-28 (in review): 11 deterministic Blender GLBs plus five 512 px PBR plate sets under `assets/props/environment/shore/`, scattered per chunk by WS-08 shore distance (erratic kind chosen so its crown clears the water); stones >= 1.0 m block only already-impassable sea cells, so the walkable region stays at 4326 / 6333. Evidence and decisions: [`docs/reports/co02_shore_debris.md`](docs/reports/co02_shore_debris.md). Open after R-1092: named visual review (R-1093), strand weed apron (R-1094).
- [x] R-1092 | deps: R-949 | deliverable: retire primitive `CoastalRocks` spheres (`map_view_shoreline_3d.gd`) so harbour scatter uses only the CO-02 ShoreDebris family | allowed files: `scripts/map/view3d/map_view_mesh_builder_scatter.gd`, `scripts/map/view3d/map_view_shoreline_3d.gd`, matching UID, `tests/godot/test_coastal_sea_3d.gd`, `tests/godot/test_r715_water_surface_geometry.gd`, `tests/godot/test_r715_water_rollout_inventory.gd`, `docs/reports/r715_water_rollout_inventory.md`, `docs/reports/co02_shore_debris.md`, `docs/ROADMAP.md`, `agents/rebel-map/playbook.md`, `TODO.md` | constraints: no collision/nav/map edits; keep CO-02 walkable counts; do not restore SphereMesh shoreline rocks | verify: `--filter=test_coastal_sea_3d,test_r715_water_surface_geometry,test_r715_water_rollout_inventory,test_shore_debris_scatter`; no `CoastalRocks` node or `map_view_shoreline_3d.gd` left | closed: 2026-09-28; deleted `map_view_shoreline_3d.gd`; harbour scatter is CO-02 ShoreDebris only
- [ ] R-1093 | deps: R-949 | deliverable: named human visual review of CO-02 Kalamaja plates | allowed files: `docs/reports/co02_shore_debris.md`, `TODO.md` | verify: reviewer named in the CO-02 report; no geometry or scatter change
- [ ] R-1094 | deps: R-949 | deliverable: strand-card weed apron replacing flat frond clumps, plus a readable Compatibility underwater Kalamaja frame | allowed files: per CO-02 follow-up in `docs/reports/co02_shore_debris.md` | verify: `--filter=test_shore_debris_scatter`; new apron plates; Compatibility `under_horizontal` on harbor east is not a corrupted frame
- [ ] R-950 | deps: R-951 | deliverable: ADR-gated re-authoring of reval_harbor_east to 192x128 and reval_harbor_north to 208x144 with wider sea and shore bands, a constructively irregular waterline (>= 6 coves, >= 5 spits, +/- 5 row variation, no full-width sea-edge rect) and a monotonic seaward bed gradient | allowed files: per docs/tasks/coast/CO-03_shore_silhouette_and_depth.md | verify: blueprint validate, full Godot suite, map audit/activation/conversion/composition, active docs; test_coastal_band_budget band minima, cove/spit counts and 12 monotonic bed transects; full stable-ID census green; transitions and anchors still walkable; top-down and three gameplay plates clear/storm before/after on Compatibility and Metal
- [ ] R-951 | deps: none | deliverable: documented coastal elevation ladder (foreshore/berm/dune/terrace) applied to reval_harbor_east (span 0.05 -> >= 1.2), reval_harbor_north and world.saaremaa (first profiles, crater rim), plus a monotonic seabed depth ramp and elevation_range_min thresholds | allowed files: per docs/tasks/coast/CO-04_coastal_elevation_levels.md | verify: blueprint validate; `--filter=test_coastal_elevation_ladder,test_reval_harbor_map,test_ws13b_sea_basin_depth`; map audit/activation/composition; active docs; walkable region and all transition/anchor cells unchanged vs the 2026-09-26 baseline; shore-parallel plates and a waterline-to-terrace walk clip per map
- [ ] R-952 | deps: none | deliverable: docs/reports/baltic_vessels_1343.md covering cog, two inshore clinker fishing sizes, rowing/ferry boat, lodja-type lighter and a Saaremaa strait craft, each with sourced dimensions, construction, rig, oars, fittings, confidence labels, a 1343 rigging-behaviour section and a feature reject list | allowed files: per docs/tasks/coast/CO-05_historical_vessel_research.md | verify: active docs check and speculative-archive dry run clean; every numeric claim carries an inline citation and a CANON confidence label; second reviewer confirms no uncited dimension is stated as fact

R-952 dossier written (2026-09-26). Decisions: CANON labels only (bounded reconstruction maps to `plausible composite`); Peeter is the 1343-contemporary Reval cog, Lootsi is a c. 1360 large comparandum; fishing/ferry/lodi/Saaremaa cards leave unmeasured fields `unknown` instead of inventing plank counts; 20th-c. *lodi* and Salme lengths are on the reject list. Evidence: `docs/reports/baltic_vessels_1343.md`.
R-991 addendum (2026-09-26): Lootsi maststep block starts 4.40 m from the keelson forward end and is 2.75 m long on the 14.95 m keelson (Reinvars 2023); original LOA stays unknown because the stem is missing. Peeter rudder hang stays unknown; 2020 DIGAR book and 2025 monograph were not readable.
R-993 (2026-09-28): DIGAR nlib-digar:432237 is unavailable on both the public and National Library intranet. The 2025 monograph remains shop-only. Peeter hang stays unknown. Clearing is a physical-copy read (R-1075), not a login retry.
- [ ] R-953 | deps: R-952 | deliverable: authored GLB vessel fleet (cog, two inshore fishing sizes, rowing boat, lodja lighter, Saaremaa strait craft) with wear/load variants, named rig sub-nodes, segmented sail meshes, deterministic per-prop variant selection, per-design BoatFloat3D hull extents and LODs, deleting both primitive boat builders | allowed files: per docs/tasks/coast/CO-06_vessel_asset_fleet.md | verify: `--filter=test_vessel_fleet,test_boat_float_3d`; blueprint validate; asset sources/lint/storage; map audit; active docs; >= 3 distinct appearances among the six Kalamaja boats; no reference to the deleted builders remains; fleet line-up, six-boat beach and roadstead plates clear/storm before/after on Compatibility and Metal
- [ ] R-954 | deps: R-953, R-955 | deliverable: VesselRigDynamics driving sail furl/reef/set with hysteresis, leeward billow, luff flutter, yard brace, gust taut/slack, wave-driven oar-blade rocking that feeds the WS-15 ripple sim, and mooring-line sag clamping hull surge, all off the shared wind and ocean_time clock | allowed files: per docs/tasks/coast/CO-07_rig_and_oar_dynamics.md | verify: `--filter=test_vessel_rig_dynamics,test_boat_float_3d,test_water_ripple_sim` incl. 600-frame no-flicker, leeward monotonic billow, brace clamp, stowed-oar zero motion, surge clamp, determinism and < 0.3 ms budget; calm/breeze/gale/storm and wind-shift clips before/after on Compatibility and Metal; quick performance report inside budget
- [ ] R-955 | deps: none | deliverable: real deterministic wind direction in SkyWeather3D replacing the constant CLOUD_DRIFT_PER_SECOND.normalized(), a documented Beaufort force / wind speed / Hs / sea_state ladder shared by water, sampler, boats and rigs, Beaufort-keyed whitecap onset, and a fetch/shelter term off the WS-08 shore field | allowed files: per docs/tasks/coast/CO-08_sea_state_wind_coupling.md | verify: `--filter=test_sea_state_ladder,test_sky_weather_3d,test_weather_realism,test_r715_water_weather_sync,test_r713_sky_weather_continuity,test_ocean_fft_sampler` incl. non-constant deterministic direction, all consumers agreeing, Hs monotonic in force, documented whitecap onset and sheltered lee < open water; save/load and transition continuity; water performance verifier; calm/breeze/gale/storm, opposite-quarter and sheltered-lee plates on Compatibility and Metal

R-955 implementation landed (2026-09-26). Decisions in
[`docs/reports/co08_sea_state_ladder.md`](docs/reports/co08_sea_state_ladder.md): heading is a pure
function of weather + noon-zero day veer + gust; Hs stays the WS-04 knots plus a force-3 row;
whitecaps gate at Beaufort 4; fetch/shelter reuses the WS-08 signed field. GPU plates and the water
performance verifier are follow-up **R-994** while a Godot editor holds the worktree.

- [ ] R-956 | deps: R-951 | deliverable: ADR-gated re-authoring of world.saaremaa to 160x104 raising walkable cells from 2610 (41.8%) to >= 6000 (>= 55%), opening the south/west/east woodland fences with >= 3 gaps each, a full-width coastal path, a circumnavigable Kaali rim with >= 2 descents and >= 2 distinct routes between the ferry landing, muster camp, crater and Poide road | allowed files: per docs/tasks/coast/CO-09_saaremaa_traversability.md | verify: blueprint validate, full Godot suite, map audit/activation/conversion/composition, active docs; test_world_saaremaa_map walkable, connectivity, stable-ID census, no full-width blocking band and route-redundancy assertions; arrival from reval_harbor_north reaches all three transitions; walkability overlay before/after plus ferry/alvar/rim/strait plates
- [ ] R-957 | deps: none | deliverable: ADR 0021 amended and accepted - maintainer acceptance and scope trade recorded in Status, item 4 rewritten from "no drowning death" to a struggling state with a documented grace window, named save-scum mitigations and a non-lethal fallback if no death path exists, item 2 listing every swimmable map explicitly including world.saaremaa, item 7 covering breath_s and the save version, plus the CANON canon note | allowed files: `docs/adr/0021-swimming-and-diving.md`, `docs/CANON.md`, `docs/tasks/water_sky/WS-14_swim_dive_adr.md`, `docs/tasks/coast/README.md`, `TODO.md` | verify: active docs check; Status carries acceptance, date and named trade; items 2/4/7 complete; CANON note carries confidence labels; maintainer sign-off recorded
- [ ] R-958 | deps: R-957, WS-14b | deliverable: drowning on top of PlayerSwimState - struggling state, breath drain while exhausted or overloaded in SWIM, death through the existing death path, safe-shore respawn cell, breath UI plus audio and underwater warning cues, and save/load that never restores into death | allowed files: per docs/tasks/coast/CO-10_swim_dive_drown.md | verify: `--filter=test_player_swim_state,test_player_drowning` plus the full suite; map audit and activation byte-identical walkable counts proving no is_walkable_cell leak; grace window sufficient from the deepest swimmable cell on both harbour maps; wading never drowns; struggling save loads at the surface; keyboard and gamepad clips for the survive case and the drown-and-respawn case

R-950, R-956 and R-957 need a maintainer decision before coding: the coastal footprint-growth ADR
(R-950, R-956) and the ADR 0021 acceptance plus scope trade (R-957). R-948, R-951, R-952 and R-955 are
unblocked today.

## Architecture realism pack (maintainer request, 2026-09-26)

Contracts: [`docs/tasks/architecture/README.md`](docs/tasks/architecture/README.md). Board rows
R-959..R-971. Raised after reviewing the built fabric in play: current buildings are too simplistic, the
game looks too generic, and the target is Witcher 3 / Kingdom Come: Deliverance quality, with the
Monastery District and Padise named explicitly as needing custom models in a shared theme.

Measured baseline (2026-09-26, counted over the 29 authored `content/maps/*.rrmap` sources and the asset
tree): **362** `building ... house` records, **182** `wall`, 10 `interior_wall`, 6 `interior_block`. Only
**43** house records resolve to authored geometry (`house_tier=`, all in `lower_town_slice`), so **319
(88%)** are a procedural box plus gable. The whole project ships **6** authored house GLBs, **4** service
buildings, 4 gates and **zero** GLBs for churches, monastic ranges, the town hall, the cathedral, keeps or
wall towers - `map_view_mesh_builder_churches.gd`, `map_view_monastic_models.gd` and
`map_view_mesh_builder_building_fortification.gd` hold ~54k of GDScript with no `res://assets` reference at
all. Wall and roof surfaces have no albedo texture and no roughness map: `map_view_building_materials.gd`
uses a single `Color` with `vertex_color_use_as_albedo`, a procedural pattern normal, and a hard-coded
`roughness = 1.0`. The one good texture library, `assets/materials/pbr/building_variants` (21 albedo+normal
pairs), reaches only those 43 houses, and the three finished window facades in `assets/buildings/facades`
are referenced by no runtime script.

- [ ] R-959 | deps: none | deliverable: docs/reports/reval_architecture_typology_1343.md with one sourced typology card per building family (stone Diele house, timber-frame house, log dwelling, craft boda, yard service fabric, parish church, Cistercian range, Toompea elite, civic, fortification, rural/coastal) giving frontage, storey and eave heights, bay module, gable form and pitch per roof cover, opening schedule, plinth/cellar/pentice practice, coursing and 1343 exclusions, each with a confidence label and a source row, plus an extended HISTORICAL_AUDIT source register and a table mapping the seven measured root causes to their card | allowed files: per docs/tasks/architecture/AR-01_building_typology_dossier.md | verify: active docs check; archive header check; all 11 families carded with labels and sources; five randomly sampled numbers traceable to source rows; exclusions consistent with HISTORICAL_AUDIT cross-map exclusions; named canon review that nothing new is labelled attested without a primary source

R-959 dossier written (2026-09-27). Eleven family cards in
[`docs/reports/reval_architecture_typology_1343.md`](docs/reports/reval_architecture_typology_1343.md).
H-register extended H26-H35. Decisions: one steep-roof band (cover-specific degrees
unknown); Town Hall arcade 0.62 units labelled invented; no new institution marked
attested beyond existing H-rows. **R-1034** (2026-09-27) second-reader pass:
7-11 m and hoist leave the CANON `attested` parenthetical; St Michael ~6.5 ha
is unknown; *boda* hoist/hypocaust bans are D. Ledger in the typology dossier.
- [ ] R-960 | deps: R-959 | deliverable: docs/adr/0025-architectural-asset-pipeline.md deciding the kit-vs-bespoke tier split per building family, the provenance rule for external meshes and textures, numeric triangle/texture/material/LOD-distance and on-disk budgets per tier, the instancing and chunk-streaming contract that keeps generated geometry disposable, the named visual acceptance protocol that green tests cannot substitute for (P0-209b precedent), the named equivalent-cost scope trade, and any ADR 0016/0018/0009 amendment notes | allowed files: per docs/tasks/architecture/AR-02_adr_architecture_pipeline.md | verify: active docs check; ADR numbered 0025 with Status/Context/Decision/Alternatives/Consequences; all seven decisions carry concrete values; scope trade names existing task ids; acceptance protocol reproducible without clarification; budgets consistent with PERFORMANCE_REPORT and ASSET_STORAGE_POLICY; Accepted with maintainer named, or Proposed with AR-04 explicitly blocked
- [ ] R-961 | deps: none | deliverable: roughness (and AO where it reads) added to all seven existing building_variants families plus new ashlar, plank, daub, brick, straw, soot and gable_board families at three stems each, a toggleable anti-tiling detail-blend path, and the surface-variety library made reachable by map_view_building_materials.gd for all 362 building records keyed by (map_seed, building_id), retiring the hard-coded roughness=1.0 and flat vertex-colour albedo for every wall/roof material the authored maps actually use | allowed files: per docs/tasks/architecture/AR-03_building_surface_pbr.md | verify: `--filter=test_building_surface_pbr,test_building_materials,test_burgher_house_models`; full Godot suite; blueprint validate; python generator unittest; asset sources/lint/storage; map composition and audit; active docs; every authored wall_material and roof_material resolves to albedo+normal+roughness with no flat-colour fallback and no constant roughness; byte-identical map fingerprint proving zero geometry change; material line-up plus matched before/after lower_town_slice and north_quarter plates at noon/overcast/rain/midnight on Compatibility and Metal at both quality tiers; quick performance report with the anti-tiling cost recorded; named human review that stone, lime, tar, clay and reed are distinguishable without tint and no street repeats
- [ ] R-962 | deps: R-959,R-960 | deliverable: assets/buildings/kit part library built by tools/build_architecture_kit.py covering ground, wall-bay (eight material families), storey, gable, roof (four covers at AR-01 pitches), opening and attachment groups on a documented snap module, an explicit architecture_kit_catalogue.gd registry with sockets/bounds/surface family/LODs, an assembler, docs/ARCHITECTURE_KIT.md snap contract, and four reference assemblies (stone Diele, timber frame, log dwelling, craft boda) built from parts only | allowed files: per docs/tasks/architecture/AR-04_modular_architecture_kit.md | verify: python generator unittest; `--filter=test_architecture_kit`; full Godot suite; blueprint validate; asset sources/lint/storage; map audit and activation; active docs; snapped neighbours gapless and non-overlapping with correct winding; every part within the ADR 0025 triangle budget with its LOD set; deterministic assembly fingerprint; emitted part list matches the documented set exactly; unchanged MapDefinition fingerprint and map audit for all 29 maps proving zero runtime change; part contact sheet, four reference assemblies and side-by-side against the three monolithic house GLBs; draw-call/material/triangle comparison; named human review answering whether the kit can carry a district
- [ ] R-963 | deps: R-961,R-962 | deliverable: deterministic kit assembly replacing the box-plus-gable path for all 319 untiered house records, driven only by hash(map_seed, building_id) over bay count, storey count, gable form, share-aware roof cover, per-storey opening schedule, plinth/undercroft, attachments and AR-03 surface stems, with explicit per-district style sets matched to the HISTORICAL_AUDIT target cards, neighbour de-duplication, shared party walls, LOD/instancing per ADR 0025, and the old path retired one map per commit | allowed files: per docs/tasks/architecture/AR-05_ordinary_house_assembler.md | verify: `--filter=test_ordinary_house_assembly,test_architecture_kit,test_map_verification`; full Godot suite; blueprint validate; tools/verify_building_variety.py failing under 40 distinct configurations across north_quarter's 96 houses, outside any map's HISTORICAL_AUDIT roof-share band, or on three identical street-adjacent buildings; python verifier unittest; map audit, activation, conversion plan and composition; active docs; determinism across save/load; bit-identical per-map walkable-cell count and largest walkable region; empty `git diff --stat content/maps/`; matched before/after plus long-street vista plates per retired map at noon and midnight on Compatibility and Metal at both tiers; north_quarter frame/draw-call/material/triangle budget; named human review per map that the street reads as a town
- [ ] R-964 | deps: R-961,R-962 | deliverable: the three burgher tiers converted from six stretched monolithic GLBs to per-plot AR-04 kit assemblies with bay-count frontage fitting (retiring the non-uniform whole-model scale fit and its MIN/MAX_VERTICAL_SCALE band), enough authored variation that none of the 43 lower_town_slice plots repeat, the three orphaned assets/buildings/facades window GLBs wired live into the opening schedule with deterministic open/closed shutter mixing and extended per AR-01, preserved flue outlet contracts, and surface_variety reduced to a wear/stem selector | allowed files: per docs/tasks/architecture/AR-06_burgher_tier_expansion.md | verify: `--filter=test_burgher_house_models,test_window_facades,test_architecture_kit,test_save`; full Godot suite; blueprint validate; verify_building_variety reporting 43 distinct configurations and no identical adjacent pair; asset sources/lint/storage; map audit, activation, composition; active docs; pre-commit all; door and window head heights inside the AR-01 band on every plot with no whole-assembly non-uniform scale; roof pitch matching the assigned cover; every facade GLB referenced by the catalogue; bit-identical walkability; demo route menu->Lower Town->forge->Mart->anvil still completes and a pre-change save loads unchanged; empty `git diff --stat content/maps/`; matched before/after Pikk/Vene/Saiakang/market plates plus a contiguous-run variety plate and a shutter close-up at noon and midnight on Compatibility and Metal at both tiers; frame/draw-call/material/triangle budget; named human review that the shipped street reads as a Hanseatic Lower Town
- [ ] R-965 | deps: R-962 | deliverable: bespoke assets/buildings/monastic set for the Monastery District as multiple models in one theme - St Michael's convent church/oratory, dorter range, refectory range, chapter house, repeatable cloister-walk bay, service wing, precinct wall and gate, well house, dovecote, garden frame - plus St Olaf 1343 church, west tower and churchyard wall, with map_view_monastic_models.gd and the St Olaf path in map_view_mesh_builder_churches.gd switched to the AR-04 catalogue and their primitive assembly deleted | allowed files: per docs/tasks/architecture/AR-07_monastery_district_set.md | verify: `--filter=test_monastic_buildings,test_architecture_kit,test_churches`; full Godot suite; blueprint validate; asset sources/lint/storage; map audit, activation, composition; building variety; active docs; git diff --check; every replaced primitive id and every building/anchor/patrol/landmark id in monastery_quarter.rrmap still resolves; cloister walk built from repeated bays; great_guild_front, blackheads_corner and brotherhood_wing stay generic merchant masses per P4-023e; no 15th-century St Olaf chancel, basilica or spire and no Great Guild/Blackheads frontage; models within the ADR 0025 budget with LODs; bit-identical walkability and anchor accounting with the map still inactive; empty `git diff --stat content/maps/`; matched before/after gate-approach, cloister, chapel, service-court and St Olaf plates plus a precinct-vs-merchant district vista at noon/overcast/midnight on Compatibility and Metal at both tiers; frame/draw-call/material/triangle budget; named human review that it reads as a Cistercian precinct and that St Olaf is its 1343 self; canon review of the confidence label on every reconstructed mass
- [ ] R-966 | deps: R-962 | deliverable: assets/buildings/padise set for the attested 1343 pre-quadrangle phase per Kadakas AVE 2011 - stone hall with modelled undercroft and external stair, arched-niche building with its niches actually built, timber oratory, conventual range, lay range, service range, threshing barn, two cottage frontages, watermill with wheel and race, fieldstone boundary, timber gate, well, ford crossing and road apron - plus authored fire-damage variants so wall.burned and wall.smoked resolve to damage geometry rather than a dark tint, wired through the AR-04 catalogue | allowed files: per docs/tasks/architecture/AR-08_padise_estate_set.md | verify: `--filter=test_padise_buildings,test_monastic_buildings,test_architecture_kit`; full Godot suite; blueprint validate; asset sources/lint/storage; map audit, activation, composition; active docs; git diff --check; all 14 house records and every building/anchor/transition id in world_padise.rrmap resolve; stone hall numerically taller than every timber model; niche geometry present; damage assignment comes from map data not a runtime roll; an explicit exclusion assertion that no claustral quadrangle, abbey church, gate tower, gun tower or moat exists in the set; models within the ADR 0025 budget with LODs; bit-identical walkability and anchor accounting with the map still inactive; empty `git diff --stat content/maps/`; matched before/after road-approach, ford, stone hall, niche south face, timber range, mill and site-scatter vista plates plus a fire-damage plate at noon and midnight on Compatibility and Metal at both tiers; frame/draw-call/material/triangle budget; named human review that it reads as a 1343 working estate rather than the later fortified abbey and that the fire is legible; canon review of every per-model confidence label
- [ ] R-967 | deps: R-962 | deliverable: assets/buildings/toompea set covering St Mary's 1343 construction phase as a group (nave, west front, unfinished bay, scaffold, lifting wheel, stone yard, precinct wall), the Small Castle as separate keep/hall/service ranges with curtain, gate and courtyard stair, elite domestic fabric (two canonical curia frontages, episcopal curia, chancery range, compound wall and gate) and the Long Leg / Short Leg gate works with retaining walls, wired through the AR-04 catalogue | allowed files: per docs/tasks/architecture/AR-09_toompea_set.md | verify: `--filter=test_toompea_buildings,test_architecture_kit,test_churches,test_fortification`; full Godot suite; blueprint validate; asset sources/lint/storage; map audit, activation, composition; building variety; active docs; git diff --check; all 23 house records across toompea_quarter, toompea_small_castle and archbishops_garden resolve with every id intact; cathedral has an unfinished bay, scaffold and lifting wheel and no completed east end; castle is a compound of separate ranges; named assertion that no bespoke knights-compound or western canonical hall model exists (HISTORICAL_AUDIT D); realised tile share on toompea_quarter inside 35-55%; models within the ADR 0025 budget with LODs; bit-identical walkability and anchor accounting with all three maps still inactive; empty `git diff --stat content/maps/`; matched before/after cathedral, castle, curia, Long Leg and plateau-vista plates plus a Toompea-curia-beside-Lower-Town-plank-house comparison at noon/overcast/midnight on Compatibility and Metal at both tiers; frame/draw-call/material/triangle budget; named human review that the plateau reads as a separate elite authority town and the cathedral as a building site; canon review that nothing disputed was reintroduced
- [ ] R-968 | deps: R-962 | deliverable: assets/buildings/civic set covering the weathered 1343 town hall (no arcade) with a repeatable window bay, gable with loft hoist, portal and pillory ground; Holy Spirit chapel, hospital range, court wall and alms porch; two wide guild frontages, guild hall body, authored crow-stepped stepped_gable_merchant, weighhouse and open market bay; gabled warehouse with two-level gable doors, hoist beam with pulley, cellar hatch and loading apron; and the four existing service GLBs folded onto the AR-04 module and AR-03 surfaces with two frontage variants each | allowed files: per docs/tasks/architecture/AR-10_civic_guild_set.md | verify: `--filter=test_civic_buildings,test_service_building_models,test_architecture_kit,test_town_hall`; full Godot suite; blueprint validate; asset sources/lint/storage; map audit, activation, composition; building variety; active docs; git diff --check; every civic and guild primitive/style across market_civic_quarter, town_hall, holy_spirit_church and st_olafs_guild_hall resolves with ids intact; town hall built from repeated window bays with no arcade; named assertion that no Great Guild Hall, Brotherhood or Blackheads frontage exists and st_olafs_guild_hall stays a generic wide frontage; existing service GLBs snapped and resurfaced; models within the ADR 0025 budget with LODs; bit-identical walkability; empty `git diff --stat content/maps/`; matched before/after town hall front, east gable hoist, Holy Spirit court, guild-beside-neighbours, warehouse hoist, weighhouse and market vista plates at noon/overcast/midnight on Compatibility and Metal at both tiers; frame/draw-call/material/triangle budget; named human review that the square reads as the civic centre and the guild frontage is distinguishable without becoming a 15th-century monument
- [ ] R-969 | deps: R-962 | deliverable: assets/buildings/fortification set covering repeatable coursed/rubble/precinct/unfinished wall sections with real batter, putlog bands, repeated merlon parapet, corner returns and arrow slits; drum, square and horseshoe towers with conical tile roofs plus an unfinished tower=false variant and distinct Kuldjala, Nunnatorn and Rentenitorn silhouettes; Viru gate towers, passage vault, machicoulis and flanking walls with the existing gate GLBs folded onto the module; wall-walk deck, stair, ladder, hatch and hoarding matching the 19 authored wall_walk primitives; and rampart, ditch revetment, palisade and hill barrier/gate fabric, replacing the asset-free procedural fortification builder | allowed files: per docs/tasks/architecture/AR-11_fortification_set.md | verify: `--filter=test_fortification_buildings,test_wall_walk_access,test_architecture_kit`; full Godot suite; blueprint validate; verify_p4_027f_tower_portfolio; asset sources/lint/storage; map audit, activation, composition; active docs; git diff --check; all 182 wall records and 19 wall-walk primitives resolve; wall sections tile seamlessly and turn corners without interpenetration; merlons are repeated geometry; round_tower=true gives a drum with conical tile roof; named assertion that tower=false is geometrically distinguishable as unfinished with no ground door or arrow slits; three distinct named-tower silhouettes; wall-walk deck top matches the authored platform height exactly and all traversal tests pass unchanged; models within the ADR 0025 budget with LODs; bit-identical walkability with wall-walk cells reported separately; empty `git diff --stat content/maps/`; matched before/after long-wall, drum tower, unfinished-vs-finished, Viru gate complex, three-tower and from-the-wall-walk plates plus a raking-light coursing plate at noon/overcast/midnight on Compatibility and Metal at both tiers; frame/draw-call/material/triangle budget; named human review that the wall reads as hand-laid limestone and incomplete fabric is legible
- [ ] R-970 | deps: R-962 | deliverable: assets/buildings/rural set covering chimneyless smoke cottages in two sizes, the rehielamu barn dwelling, croft cottage, log hut and plank dwelling; threshing barn, hay barn, byre, granary on stones, drying kiln, root-cellar mound and yard fencing; open boat shed sized to a CO-05/CO-06 fishing hull, net store, fish-drying shed, smokehouse, salt store, timber harbour crane, quay warehouse and landing-stage hut; watermill with wheel, race and sluice and a post windmill with sails; camp shelters, work sheds and supply lean-tos matching the existing camp and work_shed primitives; plus distinct coastal and inland dwelling variants | allowed files: per docs/tasks/architecture/AR-12_rural_harbour_set.md | verify: `--filter=test_rural_buildings,test_architecture_kit,test_fishing_net`; full Godot suite; blueprint validate; asset sources/lint/storage; map audit, activation, composition; building variety; active docs; git diff --check; all ~65 rural/harbour/world house records and every primitive resolve one-for-one with ids intact; smoke cottage chimneyless with a smoke hood; barn dwelling has both threshing bay and living end; watermill has wheel/race/sluice and windmill has sails; boat shed opening fits the fishing-hull extents; named assertion that world_saaremaa resolves only to camp shelters and a supply shed; coastal and inland variants are distinct models; models within the ADR 0025 budget with LODs; bit-identical walkability across all twelve maps; empty `git diff --stat content/maps/` and no overlap with in-flight coast-pack files; matched before/after Kalamaja shore, boat shed with hull, drying yard, smoke cottage, barn dwelling, watermill, windmill, Saaremaa camp and coastal-vs-inland plates at noon/overcast/midnight on Compatibility and Metal at both tiers; frame/draw-call/material/triangle budget; named human review that Kalamaja reads as a fishing suburb and the smoke cottage as Estonian
- [ ] R-1064 | deps: R-960 | deliverable: `tools/architecture_budgets.py` holds the ADR 0025 Decision 3 tables; `tools/verify_asset_lint.py` checks every GLB under `assets/buildings/**` for K-S/K-L/B/B-module/K-part triangle caps, LOD1/LOD2 siblings, zero kit embedded images, K6/B8 material slots, 6 MiB GLB / 4 MiB texture / kit 24 MiB / set 12 MiB / total 96 MiB | allowed files: `tools/architecture_budgets.py`, `tools/verify_asset_lint.py`, `tests/python/test_architecture_budgets.py`, `docs/adr/0025-architectural-asset-pipeline.md`, `TODO.md` | verify: `python3 -m unittest tests.python.test_architecture_budgets -v`; `python3 tools/verify_asset_lint.py`; `git diff --check`

R-1064 implementation landed. Path prefixes declare tier (never mesh-size guesses).
`assets/buildings/facades/` is grandfathered until AR-04 rebuilds the three window
GLBs as kit parts; the six house monoliths stay listed for AR-06. Numbers match
the Proposed ADR 0025 tables and should be retuned if acceptance changes them.
Follow-up **R-1066** drops the facades prefix once AR-04 ships kit replacements.
- [ ] R-1066 | deps: R-962,R-1064 | deliverable: remove `assets/buildings/facades/` from `GRANDFATHERED_PREFIXES` once AR-04 emits those openings as kit parts with LOD1 siblings and zero embedded images | allowed files: `tools/architecture_budgets.py`, `tests/python/test_architecture_budgets.py`, `docs/adr/0025-architectural-asset-pipeline.md`, `TODO.md` | verify: `python3 -m unittest tests.python.test_architecture_budgets -v`; `python3 tools/verify_asset_lint.py`
- [ ] R-971 | deps: R-963,R-964,R-965,R-966,R-967,R-968,R-969,R-970 | deliverable: tools/verify_building_variety.py promoted to a fail-closed gate with committed per-map thresholds in docs/data/building_variety_budget.json for distinct configurations, identical-neighbour run length, minimum world distance between identical appearances, realised roof-cover and wall-material shares against the HISTORICAL_AUDIT bands, part-reuse histogram and silhouette-tuple diversity; a landmark uniqueness check; architecture rows wired into docs/data/world_building_visual_benchmark.json; a fixed-framing district contact sheet; pre-commit wiring for assets/buildings and the architecture scripts; and docs/reports/ar13_architecture_pack_review.md restating the pack baseline table with measured after values | allowed files: per docs/tasks/architecture/AR-13_repetition_audit_gate.md | verify: python verifier unittest with negative fixtures for a repeated-configuration map, an out-of-band roof share, a missing budget row and two landmarks sharing a silhouette signature; verify_building_variety zero on the real repo with a per-map headroom table; world-building visual gate run with every remaining blocker a named pending human review; pre-commit fixture proving the hook fires on a staged assets/buildings change and not on an unrelated one; full Godot suite; map audit and activation; active docs; git diff --check; thresholds set from the measured post-AR state with stated headroom and no currently-failing map; one contact-sheet plate per exterior map at fixed framing; named human review answering whether the districts read as different historically specific places and the generic complaint is resolved

R-960 (ADR 0025; 0022 went to realistic humans) needs a maintainer decision before R-962 and everything downstream of it can code.
Proposed [ADR 0025](docs/adr/0025-architectural-asset-pipeline.md) landed 2026-09-27 and awaits maintainer acceptance. It decides:
kit-vs-bespoke split, external-mesh provenance, budgets, and the named scope trade. **R-959 and R-961
are unblocked today** and can run in parallel. R-961 is the highest-value single fix in the pack - it
removes the flat-colour albedo and constant `roughness = 1.0` from every building in the game and does not
touch one vertex. The monastery work the maintainer named explicitly is R-965 (St Michael's and St Olaf)
and R-966 (Padise), both authored as multiple models in one theme rather than one huge mesh.

Seam with the world-building pack (R-972): WB owns **where** buildings sit - plots, yards, prop density,
wear, relief, re-authored `content/maps/*.rrmap` and `MapBlueprint` prefabs. AR owns **what a building is
made of** - kit parts, bays, gables, roofs, openings, surfaces and landmark geometry - and never edits map
data. R-964 and WB-14 (R-986) both target `lower_town_slice`; run them in sequence, not concurrently, and
whichever is second re-captures its plates. Full table in
[`docs/tasks/architecture/README.md`](docs/tasks/architecture/README.md#seam-with-the-world-building-pack-r-972-wb-01wb-14).
- [ ] R-1100 | deps: none | deliverable: authored Kalev smithy interior - Blender room shell, loft ceiling, raised hearth under a clay hood, block anvil, great bellows, slack tub, stock rack and scrap crate from the smithy dossier; `MapViewKalevSmithyInterior` binds shared PBR plates and hides generic wall dressing; warm indoor bounce light | allowed files: `tools/assets/generate_kalev_smithy_interior.py`, `tools/assets/derive_plate_normals.py`, `tools/capture_kalev_smithy_interior.gd`, `assets/props/architecture/interiors/kalev_smithy_*/**`, `assets/props/forge/kalev_smithy_*/**`, `scripts/map/view3d/map_view_kalev_smithy_interior.gd`, `map_view_smithy_prop_builder.gd`, `map_view_3d.gd`, `map_view_lighting.gd`, `content/maps/kalev_smithy.rrmap`, `assets/SOURCES.csv`, matching tests, `docs/reports/kalev_smithy_interior_redesign.md` | constraints: rrmap stays collision/navigation authority; retire the old smithy anvil/furnace/bellows/quench GLBs | verify: `tools/godot_render.sh --script tools/capture_kalev_smithy_interior.gd`; `--filter=test_kalev_smithy_interior,test_forge_prop_meshes,test_kalev_smithy_map`; map pre-commit gates | status: in review 2026-09-30 - [report](docs/reports/kalev_smithy_interior_redesign.md)
## Historical landmark remodel pack (R-1121)

Maintainer request 2026-09-30: every notable 1343 building historically accurate, realistic and aged, never brand new. Reference: [`docs/reports/town_hall_1343_remodel.md`](docs/reports/town_hall_1343_remodel.md). Decision: the Town Hall follows the 1343 dossier with no arcade (supersedes the 2026-07-23 P0-072 arcade choice); red banners with a white cross are a `plausible composite` in `docs/CANON.md`. Procedural view3d builders now; authored GLBs stay with AR-07/09/10/11 behind ADR 0025.

- [ ] R-1135 | deps: none | deliverable: 1343 Town Hall remodel - rubble limestone, dressed quoins and frames, stone gables with loft hoist, cellar lights, wear, moss tile, Dannebrog banners, no arcade | verify: `--filter=test_market_prototype_maps`; `tools/godot_render.sh --script tools/capture_town_hall_facade.gd` | status: in review 2026-09-30, maintainer visual acceptance open
- [ ] R-1123 | deps: none | deliverable: LM-01 shared landmark weathering kit extracted from `map_view_town_hall_model.gd` into `map_view_landmark_weathering.gd` | verify: `--filter=test_landmark_weathering,test_market_prototype_maps,test_building_surface_pbr`; Town Hall plates unchanged
- [ ] R-1124 | deps: R-1123 | deliverable: LM-02 St Catherine's Dominican church 1343 weathered exterior (`st_catherines_church`, lower_town_slice) | verify: map pre-commit gate; `--filter=test_st_catherines_church`; day/night captures; canon sign-off
- [ ] R-1126 | deps: R-1123 | deliverable: LM-03 Holy Spirit chapel-almshouse and hospital range, 1343 state with wear | verify: `--filter=test_market_prototype_maps`; day/night captures; canon review
- [ ] R-1128 | deps: R-1123 | deliverable: LM-04 Toompea Danish royal castle 1343 (keep, curtain, gate, Dannebrog), no Pikk Hermann or Order convent | verify: map pre-commit gate; `--filter=test_toompea_castle_model`; captures; canon sign-off
- [ ] R-1130 | deps: R-1123 | deliverable: LM-05 St Michael's Cistercian convent precinct, chapel and service wing with wear | verify: St Michael's test filter; captures; canon review
- [ ] R-1131 | deps: R-1123 | deliverable: LM-06 Karja Gate 1343 state | verify: map pre-commit gate; `--filter=test_karja_gate_model,test_transition_manifest`; captures
- [ ] R-1132 | deps: R-1123 | deliverable: LM-07 city wall and drum tower 1340s wear, repairs and wooden fighting decks | verify: `--filter=test_map_view_3d_fortification`; quick performance report within budget; captures
- [ ] R-1134 | deps: R-1123 | deliverable: LM-08 St Nicholas' church 1343 research dossier, placement decision and weathered model | verify: canon-reviewed dossier; model tests; captures after placement

## Storybook model set

- [ ] P0-209b | deps: P0-209a | deliverable: replace the visually rejected procedural mammals from scratch with convincingly realistic sculpted or scanned source geometry and textured surfaces | allowed files: `tools/assets/realistic_mammals.py`, `tools/assets/mammal_limb_anatomy.py`, `tools/assets/build_storybook_models.py`, `tools/assets/import_realistic_mammals.py`, `tools/assets/import_authored_rat.py`, `tools/assets/pack_authored_rat.py`, `tools/verify_storybook_models.py`, `tools/capture_animal_realism.gd`, `scripts/map/view3d/map_view_medieval_animal_models.gd`, `tests/python/test_mammal_limb_anatomy.py`, `tests/godot/test_mammal_limb_anatomy.gd`, `tests/godot/test_storybook_models.gd`, `tests/godot/test_storybook_live_integration.gd`, `assets/storybook/`, `assets/SOURCES.csv`, `docs/ART_BIBLE.md`, `docs/reports/animal_realism_2026-09-12.md`, `docs/reports/images/animal_realism/`, `TODO.md` | constraints: licensed commercial-use sources; no ripped game assets; preserve species IDs, runtime paths and behavior; replace failed geometry instead of polishing primitive unions; preserve unrelated WIP | verify: inspect replacement source silhouettes and materials; Godot imports and fauna tests; real runtime captures; provenance and independent visual review; do not close on technical tests alone; replacement implementation and 81 focused tests complete; maintainer visual acceptance remains open

## Storage and file-size (active)

See [`docs/STORAGE_SIZE_BACKLOG.md`](docs/STORAGE_SIZE_BACKLOG.md) for full deliverable/verify contracts.

- [x] P0-180 | deps: P0-177 | deliverable: curated music take reduction with MusicDirector proof | verify: soundtrack tests + recorded byte drop | closed: 2026-09-28; `music/` 131/757462289 -> 76/435777018 bytes; unused `(N)` takes and unreferenced district extras in `archive/music/` (LFS-skip); `music/battle/` retained-library note in `docs/data/slice_soundtrack_manifest.json`
- [x] P0-182 | deps: P0-180 | deliverable: runtime audio bitrate/size budget | verify: lint/validator + audio tests | closed: 2026-09-28; lossy `sounds/` 192 kbps / 2 MiB and `music/` 256 kbps / 12 MiB in `docs/data/runtime_audio_budget.json`; woodpecker source 10503962 -> 584768 bytes; 22 over-budget MP3s recompressed to 128 kbps CBR
- [x] P0-183 | deps: P0-177 | deliverable: oversized runtime GLB budgets (oak + shared characters) | verify: asset lint + focused Godot filters | closed: 2026-09-28; oak 10045452 -> 7868736 bytes (URI sibling PBR maps, 63891 tris); shared LOD0/1/2 byte+triangle caps in `docs/data/runtime_glb_budget.json`
- [ ] P0-183b | deps: P0-183,P0-209b | deliverable: storybook mammal GLB byte cap after P0-209b replacement (rat/boar/cow) | verify: runtime GLB budget + asset lint + storybook/fauna filters
- [ ] P0-185 | deps: P0-184 | deliverable: justified view3d hotspot extractions only | verify: named focused filters

P0-185 shore peel (2026-09-28, **R-1080**): `map_view_shore_materials.gd` owns WS-08 shore-field, swash sheets, and quality gating; `MapViewMaterials` keeps the public API and `apply_weather_presentation`. Gate: `--filter=test_shore_distance_field,test_r715_water_material_contract,test_r715_water_weather_sync,test_map_view_material_resolution`. Hosted-location rebinding is already closed in `map_view_runtime_hosted.gd`. Prefer leftover **R-1079** if claiming crash-stability work.

P0-185 tree-skeleton peel (2026-09-28): `map_view_tree_mesh_skeleton.gd` owns recursive trunk/branch growth; `MapViewTreeMeshes` keeps wood/canopy/fruit emitters (659 -> 320 lines). Gate: `--filter=test_map_view_tree_species,test_vegetation_realism,test_map_view_3d_mesh`. Next P0-185 claim: keep `apply_weather_presentation` on the materials facade until a second caller needs a weather-material adapter.

P0-185 shore-debris peel (2026-09-28): `map_view_shore_debris.gd` owns CO-02 scatter, GLB loading, and blocking cells; `MapViewTerrainDetails` keeps first-person grass and public facade delegates (883 -> 292 lines). Gate: `--filter=test_shore_debris_scatter,test_map_view_terrain_details,test_vegetation_realism,test_r715_water_rollout_inventory`. Next P0-185 claim: keep `apply_weather_presentation` on the materials facade until a second caller needs a weather-material adapter.

## Character visual realism (active)

See [`docs/CHARACTER_REALISM_BACKLOG.md`](docs/CHARACTER_REALISM_BACKLOG.md) for full deliverable/verify contracts. Review: [`docs/reports/character_visual_realism_review_2026-08-12.md`](docs/reports/character_visual_realism_review_2026-08-12.md).

- [ ] P0-189 | deps: P0-188 | deliverable: Godot vertex-colour albedo path for head/beard/skin tints | verify: face plates + character rig + asset lint

P0-189 implementation landed (2026-09-28). Runtime opt-in is by non-white
`ARRAY_COLOR`, not the `_fur_cutout` suffix. ADR 0022 complexion is the albedo
bake; beard fur COLOR_0 drives strand cut-off. Evidence:
`docs/reports/images/characters/p0_189/`.
Verify: `--filter=test_character_vertex_albedo,test_realistic_kalev,test_character_rig`
and `python3 tools/verify_asset_lint.py`.
- [ ] P0-190 | deps: P0-189 | deliverable: soften beard cheek hard edge / fibre continuity | verify: rebuilt bodies + face plates + lint
- [ ] P0-191 | deps: P0-188 | deliverable: fix hair-shell terracing and UV-island blocks | verify: dialogue plates + lint + rig tests
- [ ] P0-192 | deps: P0-189 | deliverable: GL-Compat wrap skin + cornea/iris specular response | verify: day/night face plates + material/rig tests
- [ ] P0-193 | deps: P0-191 | deliverable: hair/beard card or layered shell inside tier caps | verify: hero/townswoman/bearded rebuild + lint
- [ ] P0-194 | deps: P0-189, P0-191 | deliverable: refresh stale full-body character closeup plates | verify: new closeup evidence replaces 2026-07-31 set
- [ ] P0-195 | deps: P0-188 | deliverable: locomotion weight/foot-plant (+ optional cape secondary) | verify: arm-swing audit + walk/run plates + rig tests
- [ ] P0-196 | deps: P0-188 | deliverable: dialogue look-at/blink/talk micro-motion without blendshapes | verify: focused Godot filter + dialogue/showcase capture
- [ ] P0-197 | deps: P0-195 | deliverable: smithy station bespoke animation pack | verify: smithy routine filters + forge station capture
- [ ] P0-198 | deps: P0-196 | deliverable: ambient NPC idle/gesture variety for Witcher-style routines | verify: four role mappings + ambient/rig tests

New major work still requires the task contract in [`AGENTS.md`](AGENTS.md): player-facing goal, allowed files, deps, constraints, deliverable, verify.

## Map conversion parity (active)

Completed map-conversion contract rows **P0-043** through **P0-046**, **P2-018** through **P2-020**, and **P4-014** / **P4-015** live in [`docs/TASK_ARCHIVE.md`](docs/TASK_ARCHIVE.md).

- [ ] P2-021 | deps: P2-021a,P0-101 | deliverable: visual-parity and gameplay-parity gate for the converted smithy and Lower Town slice with matched captures, annotated anchor accounting, topology traces, collision and navigation overlays, Y-sort and fade cases, and identical-framing day/night review | allowed files: `TODO.md`, `docs/MAP_CONVERSION_PLAN.md`, `docs/reports/map_conversion_parity.md`, `docs/reports/images/map_conversion_smithy_before.png`, `docs/reports/images/map_conversion_smithy_after_day.png`, `docs/reports/images/map_conversion_smithy_after_night.png`, `docs/reports/images/map_conversion_lower_town_before.png`, `docs/reports/images/map_conversion_lower_town_after_day.png`, `docs/reports/images/map_conversion_lower_town_after_night.png`, `tools/verify_map_conversion_parity.py`, `tests/python/test_verify_map_conversion_parity.py` | constraints: semantic parity rather than pixel tracing, no map or runtime-art edits, no acceptance by hue alone, unresolved parity failures block P2-012 | verify: `python3 tools/verify_map_conversion_parity.py` and `python3 -m unittest tests.python.test_verify_map_conversion_parity -v` pass with 100 percent anchor accounting, all required route pairs reachable, all hard exclusions blocked, zero spawn overlaps, zero missing references, and signed human review of composition, depth, readability, and day/night value hierarchy

## Tooling (class cache guard)

- [x] R-925 | deps: none | deliverable: fail-fast class_name scratch guard in on-commit checks and the Godot harness, plus `build/scratch/.gdignore` from `godot_render.sh` | allowed files: `tools/run_pre_commit_checks.sh`, `tools/run_godot_tests.gd`, `tools/godot_render.sh`, `docs/SETUP.md`, `agents/playbook.md`, `TODO.md` | verify: unignored `class_name` copy under `build/tmp_guard/` fails the hook and harness with a clear message; adding `.gdignore` or moving it under `build/scratch/` clears the guard; `godot_render.sh --script res://build/...` still runs; `python3 tools/generate_active_docs_report.py --check`
- [x] R-926 | deps: R-925 | deliverable: pre-commit fixture that plants an unignored `class_name` under `build/tmp_guard/`, asserts `CLASS CACHE GUARD`, then proves folder `.gdignore` clears the guard | allowed files: `tests/python/test_pre_commit_hooks.py`, `TODO.md` | verify: `python3 -m unittest tests.python.test_pre_commit_hooks -v`
- [x] R-1002 | deps: none | deliverable: register `crowd_townsman_01/02` and `crowd_townswoman_01/02` scenes in the conversion plan and scene inventory as retained actor variants | allowed files: `docs/MAP_CONVERSION_PLAN.md`, `docs/reports/scene_inventory.md`, `TODO.md` | constraints: character variants only, no map activation, no runtime change | verify: `python3 tools/verify_map_audit.py`; `python3 tools/verify_map_conversion_plan.py`; `python3 tools/generate_active_docs_report.py --check`
- [x] R-1014 | deps: R-1011 | deliverable: South Quarter fabric-contract test requires shared Rataskaev labels (1325 B/C, 1343 Dunkri/Cat's Well U, 1375 rebuild later) instead of a bare `1375` substring | allowed files: `tests/godot/test_south_quarter_prototype_map.gd`, `TODO.md` | constraints: no `.rrmap` or scene edits; no promotion of 1325 to attested | verify: `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_south_quarter_prototype_map`

## Magic (P7-010 follow-up)

- [x] R-944 | deps: R-706 | deliverable: blessing grant/revoke in test_magic_runtime uses MagicResolver content ops | allowed files: `tests/godot/test_magic_runtime.gd`, `TODO.md` | verify: `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_magic_runtime`
- [x] R-959 | deps: R-944 | deliverable: learned-spell HUD that does not collide with Quick Access, number keys cast granted recipes, LMB is not a cast bind, Fireball is visible in the 3D map, demo seeds Fireball/Earth Tremor/Iron Skin | allowed files: `scripts/magic/spellforge_hud.gd`, `scripts/magic/spellforge_model.gd`, `scripts/magic/spellforge_controller.gd`, `scripts/settings/input_binding_settings.gd`, `scripts/map/view3d/map_view_magic_vfx.gd`, `scripts/session/session_state.gd`, `scripts/ui/quick_access_menu.gd`, `tests/godot/test_spellforge_hud.gd`, `tests/godot/test_map_view_magic_vfx.gd`, `tests/godot/test_quick_access_menu.gd`, `docs/CONTROLS.md`, `docs/SYSTEMS/MAGIC.md`, `TODO.md`, `agents/rebel-dev/playbook.md` | constraints: no legacy element sprites, no catalog dump, demo path stays playable without casting, no LMB/combat dual-bind | verify: `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_spellforge_hud,test_map_view_magic_vfx,test_input_bindings,test_quick_access_menu`
- [x] R-718 | deps: none | deliverable: Divine Blessing is an executable fixed rite: authored self damage_bonus, piety spend, HUD slot when granted, melee outgoing damage scaled while active | allowed files: `content/examples/valid/rite.blessing.json`, `schemas/magic.schema.json`, `scripts/combat/combat_timed_modifiers.gd`, `scripts/combat/melee_attack_resolver.gd`, `scripts/magic/magic_resolver.gd`, `scripts/magic/spellforge_model.gd`, `scripts/magic/spellforge_hud.gd`, `tests/godot/test_magic_blessing.gd`, `tests/godot/test_magic_runtime.gd`, `tests/godot/test_magic_iron_skin.gd`, `tests/godot/test_spellforge_hud.gd`, `docs/SYSTEMS/MAGIC.md`, `TODO.md` | constraints: no demo seed, no LMB cast, no new VFX, cookbook stays pagan-only | verify: `python3 tools/validate_content.py content/examples/valid content/examples/support`; `godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_magic_blessing,test_magic_runtime,test_magic_iron_skin,test_spellforge_hud`
- [x] R-332 | P7-010 closeout | deps: P7-002,R-718 | deliverable: runtime magic foundation verified against MAGIC.md section 8: conduit-gated example `spell.pagan.forgefire_weapon` + `magic.grant.forge_forgefire_weapon` (not demo-seeded), Kalev `ap.forge.anvil` activity binds `forge_conduit_bound` until the smithy scene exits, tests for `needs_hammer`, `suppressed`, `insufficient_health` (test-only fixture `tests/godot/fixtures/magic/rite.test_martyrdom.json`) | allowed files: `content/examples/valid/spell.pagan.forgefire_weapon.json`, `content/examples/valid/magic.grant.forge_forgefire_weapon.json`, `scripts/world/smithy_routine_controller.gd`, `scenes/reval_east/forge/forge.gd`, `tests/godot/test_magic_runtime.gd`, `tests/godot/test_forge_conduit_binding.gd`, `tests/godot/fixtures/magic/**`, `docs/SYSTEMS/MAGIC.md`, `docs/CANON.md`, `TODO.md` | verify: `--filter=test_magic_runtime`, `--filter=test_forge_conduit_binding`, `--filter=test_spellforge_hud`, `--filter=test_demo_walkthrough`; `python3 tools/validate_content.py content/examples/valid content/examples/support`; `python3 tools/validate_content_examples.py`
- [x] R-1015 | deps: R-332 | deliverable: MAGIC.md 3.2 records the fireball-air / double-deception slice exceptions and the 8-castable count; `tests/python/test_magic_budget.py` fails when slice grants exceed 6 budget elements or 8 castables | allowed files: `docs/SYSTEMS/MAGIC.md`, `tests/python/test_magic_budget.py`, `TODO.md` | verify: `python3 -m unittest tests.python.test_magic_budget -v`; `python3 tools/generate_active_docs_report.py --check`
- [x] R-1017 | deps: R-1015 | deliverable: path-aware on-commit queue runs `tests.python.test_magic_budget` when a magic grant/spell/rite example or MAGIC.md changes | allowed files: `tools/run_pre_commit_checks.sh`, `tests/python/test_magic_budget.py`, `TODO.md` | constraints: no recipe or demo-seed edits; do not raise the 6/8 caps; non-magic JSON must not queue the budget module | verify: `python3 -m unittest tests.python.test_magic_budget -v`
- [x] R-1019 | deps: R-1017 | deliverable: CI Python contract tests run `tests.python.test_magic_budget` | allowed files: `.github/workflows/ci.yml`, `TODO.md` | verify: workflow lists the module; `python3 -m unittest tests.python.test_magic_budget -v`
- [x] R-1020 | deps: R-1019 | deliverable: `test_magic_budget` asserts the CI Python contract-test step lists `tests.python.test_magic_budget` | allowed files: `tests/python/test_magic_budget.py`, `TODO.md` | constraints: no recipe, demo-seed, or 6/8 cap edits | verify: `python3 -m unittest tests.python.test_magic_budget -v`; deleting the CI module line fails the new assertion
## South Quarter register alignment

- [x] R-1011 | deps: R-1009 | deliverable: South Quarter fabric contract uses the shared R-1009 labels (1325 name B/C, 1343 Dunkri / Cat's Well anchor U, 1375 rebuild later) | allowed files: `docs/reports/south_quarter_1343_fabric_contract.md`, `TODO.md` | verify: no 1375-first-mention line; years match P0-072 and WB-12; `python3 tools/generate_active_docs_report.py --check`
- [x] R-1086 | deps: R-1082 | deliverable: intramural Rataskaev/King/Knights frontage plus sparse extramural barns so South Quarter zone H-bands pass without lowering H08-H10 | allowed files: `content/maps/south_quarter.rrmap`, `docs/data/south_quarter_authoring_contract.json`, `tests/godot/test_south_quarter_prototype_map.gd`, `tests/godot/test_map_composition_audit.gd`, `docs/data/map_composition_thresholds.json`, `docs/reports/south_quarter_1343_fabric_contract.md`, `TODO.md` | constraints: no parity-fixture regen; no `enforce=false`; do not roof owned courts or move stable IDs | verify: `--filter=test_map_composition_audit,test_south_quarter_prototype_map`; `python3 tools/verify_map_composition.py`; inside_wall 40-55 and outside_wall 10-25

## Seamless streaming (R-977)

- [ ] R-977 | deps: none | deliverable: ADR 0019 Status accepted or rejected with an ISO date, an explicit seamless-group membership list covering every map (including an interiors decision), a phase plan in `docs/SEAMLESS_STREAMING_PLAN.md` mapping phases 3-5 to R-978..R-980 with exit gates and rollback, a re-measured startup baseline, and the map-activation prerequisites | allowed files: per docs/tasks/world/WB-05_accept_adr_0019_phases.md | constraints: no runtime or flag-default change; no map activation | verify: active docs check; baseline reproduces from a named command; second reviewer confirms no map is left unassigned to a group

R-977 implementation landed (2026-09-27). ADR 0019 Status is Accepted (Artjom Kurapov).
Membership, interiors decision, phases 3-5, and activation prerequisites:
[`docs/SEAMLESS_STREAMING_PLAN.md`](docs/SEAMLESS_STREAMING_PLAN.md). Baseline:
[`docs/reports/seamless_startup_baseline_2026-09-26.md`](docs/reports/seamless_startup_baseline_2026-09-26.md)
(149 ms compact 2D pipeline, 4.2 s warm `MapView3D.create`, 17.3 s contended full
`reval_east` scene). No runtime or flag-default change. Second-reviewer census is
**R-1016**.

- [ ] R-1039 | deps: R-978 | deliverable: WB-06c - real baked location regions connect across an active seam on the host navigation map despite the 16 px agent-radius world-edge inset; flag-off bake byte-identical | allowed files: `scripts/map/map_nav_builder.gd`, `scripts/world/world_host.gd`, `scripts/map/map_world_layout.gd`, `tests/godot/test_world_host_residency.gd`, `docs/SEAMLESS_STREAMING_PLAN.md`, `TODO.md` | verify: `map_get_path` across a seam between two real baked packages; `--filter=test_async_location_assembly` nav parity; `--filter=test_world_host_residency`
- [x] R-1041 | deps: R-1039,R-978 | deliverable: phase-3 `create_globals` host proves a click path across two `assemble_location_package()` mounts via the shared seam `NavigationLink2D`s | allowed files: `scripts/world/world_host.gd`, `tests/godot/test_world_host_residency.gd`, `docs/SEAMLESS_STREAMING_PLAN.md`, `TODO.md` | verify: `--filter=test_world_host_residency` including a path across two assembled packages; `--filter=test_async_location_assembly` nav byte-identity | status: done 2026-09-27 - 13/13 residency (phase-3 assemble mounts + phase-2 regression); 18/18 async including threaded nav bake

- [x] R-1024 | deps: R-1022 | deliverable: `surroundings/backdrops` water rest Y reads empty-relief historic recess without `MapBuilder.build()`, or one worker bake for all water sides on relief maps | allowed files: `scripts/map/view3d/map_view_mesh_builder_surroundings.gd`, `tests/godot/test_map_relief_water.gd`, `tests/godot/test_async_location_assembly.gd`, `TODO.md` | verify: `--filter=test_map_relief_water,test_async_location_assembly`
- [x] R-1028 | deps: R-1024 | deliverable: warm the two backdrop water ShaderMaterials before `surroundings/backdrops` so cold harbour `backdrops` stays under 4 ms without reordering WORLD_SIDES | allowed files: `scripts/map/view3d/map_view_mesh_builder_surroundings.gd`, `tests/godot/test_async_location_assembly.gd`, `TODO.md` | verify: `--filter=test_async_location_assembly`; harbor-east `cold_staged` and warm `staged` `surroundings/backdrops` under 4 ms | status: done 2026-09-27 - `backdrops_water_warm` binds throwaway meshes before WORLD_SIDES planes; focused suite 18/18; harbor-east trace has no backdrops overrun

## Urban form: streets, block form, landmarks, seam continuity, hinterland (R-1108)

Raised by the maintainer on 2026-09-30 after playing the districts: the quarters read as "just a
matrix of houses, without any human design or streets", streets must be historically accurate, maps
must "better fit each other", maps need real elevation, the notable churches and monasteries need
dedicated modelling and placement tasks, and moving between maps in Tallinn **and the surrounding
areas** should not make the player wait. Reference bar: Kingdom Come: Deliverance and The Witcher 3.

Pack contract and measured baseline: [`docs/tasks/urban_form/README.md`](docs/tasks/urban_form/README.md).
Each row below has its own contract document in that folder. Board epic: **R-1108**.

Two rows were maintainer decisions, and the maintainer took both on **2026-09-30**: **ADR 0023**
(relief as gameplay) is `Accepted, Artjom Kurapov, 2026-09-30`, which closes **UF-00 / R-1109** and
releases the relief chain from that gate; and the **ADR 0027** scope - a bounded `reval_hinterland`
second streaming group past the town wall, distant regions staying travel - is approved, so
**UF-14 / R-1129** now writes an accepted ADR rather than waiting for a decision. **UF-01 / R-1110**
still reserves ADR 0026 for streets as an authored network and is still undecided. No row starts
before its ADR is accepted.

Ownership seam against the sibling packs (WB relief/streaming/plots/density, AR building fabric,
CO coast) is in the pack README. **UF-05 / R-1114** must land before WB-14 (**R-986**) and AR-05
(**R-964**) on `lower_town_slice`; the three cannot run concurrently.

- [x] R-1109 | UF-00 | deps: none | deliverable: named maintainer acceptance or rejection of ADR 0023 with ISO date, premature-relief-code consequences, exact dependent-row disposition and prevention lesson | verify: ADR Status and Consequences human review; dependent-row audit against WB/UF tables; python3 tools/generate_active_docs_report.py --check; git diff --check | done 2026-09-30: accepted by Artjom Kurapov
- [ ] R-1110 | UF-01 | deps: none | deliverable: ADR 0026 for authored StreetNetwork and frontage authority, replacing WB-09/R-981 independent plot geometry with UF-03 consumption and recording owner agreement | verify: five-section ADR and named maintainer ISO-dated decision; WB-09 seam review; MAP_AUTHORING link; python3 tools/generate_active_docs_report.py --check; git diff --check
- [ ] R-1111 | UF-02 | deps: none | deliverable: sourced docs/reports/reval_street_register_1343.md and docs/data/reval_street_register.json, with dated names, 1343 route verdicts, owner map, trace, bounded width/surface/drainage/frontage, map conflicts, forum open space, citations and exclusions | verify: JSON parse and full schema/coverage review, active-docs check and speculative-archive dry run; Canon Keeper signs 1343 claims
- [ ] R-1112 | UF-03 | deps: R-1110 | deliverable: typed RRMap street primitive, deterministic StreetNetwork and stable diagnostics | verify: headless parser/network tests, all-map identity, blueprint validation and world-layout checks
- [ ] R-1113 | UF-04 | deps: R-1112, R-1111 | deliverable: street-bound frontages, irregular strip plots and fail-closed anti-grid budget | verify: Python negative/real-repo fixtures, headless frontage test, pre-commit fixtures and fingerprint compatibility
- [ ] R-1114 | UF-05 | deps: R-1113, R-1111 | deliverable: authored Lower Town and civic street networks with bound, irregular frontage and square edges | verify: blueprint, full headless suite, urban-form/composition/world/audit checks, route/patrol parity and named visual review
- [ ] R-1115 | UF-06 | deps: R-1114 | deliverable: named street networks and irregular frontage for monastery, north and south quarters | verify: headless map/route/patrol tests, urban-form/composition/world/audit/activation/conversion checks and named district review
- [ ] R-1116 | UF-07 | deps: R-1113, R-976, R-1109 | deliverable: relief-aware Pikk jalg/Lühike jalg ramps and Toompea plateau streets | verify: ADR gate, compiled-height walk positive/negative tests, blueprint/world/urban-form checks and named silhouette review
- [ ] R-1117 | UF-08 | deps: R-1114, R-980 / R-1043 | deliverable: fail-closed continuity gate for compiled form across reval_outdoor seams | verify: negative and real seam fixtures, pre-commit/CI integration, existing layout checks retained
- [ ] R-1118 | UF-09 | deps: R-1111 | deliverable: docs/data/reval_landmark_register_1343.json and docs/reports/reval_landmark_placement_1343.md with 1343 phase, UF-02 address, actual map/anchor status, ADR-0025 tier, sourced exclusions and task-bound absence grace; fail-closed landmark verifier and tests | verify: JSON and UF-02 reference check; negative fixture suite and real-repo verifier pass; catalog coverage reviewed; Canon Keeper signs phases
- [ ] R-1119 | UF-10 | deps: R-1118,R-1114,R-1134,R-1123 | deliverable: place St Nicholas' on its owning map - church `building` record sized to the LM-08 dossier, register anchor, churchyard reconciled with the existing `niguliste_close`/`niguliste_lane`/`niguliste_row`/`niguliste_chapter_house` ids, `sign.niguliste` re-aimed at the real building, close kept as owned open region | verify: map pre-commit gate; world-layout rebuild and verify; composition and route gates; `python3 tools/verify_landmark_register.py`; day/night plates from the street and the churchyard | note: model, dossier and wear belong to LM-08 (R-1134), not here
- [ ] R-1120 | UF-11 | deps: R-1118,R-1115,R-1123 | deliverable: 1343 exteriors for the two landmarks the LM pack does not name - St Olaf's (`st_olaf_silhouette`, replacing the box-and-extrusion `st_olaf_1343` assembly) and the Great Guild (`house.guild` / `guild_frontage`), both through the LM-01 weathering kit, ids and the Pikk-spine bypass preserved | verify: focused model filters; asset sources, lint and GLB budget; map pre-commit gate; skyline plates from the harbour and Pikk at noon and midnight; canon sign-off per 1343 phase | note: Town Hall is R-1135 and Holy Spirit is LM-03 (R-1126)
- [ ] R-1122 | UF-12 | deps: R-1116,R-1118,R-1123,R-1128 | deliverable: St Mary's / the Dome Church 1343 state (keep or replace `primitive=st_marys_construction_1343` with a stated, labelled reason), plus relief bedding for the whole Toompea compound - cathedral and LM-04 castle both sitting on the compiled height field, never a fixed Y, with no relief edited to fit a model | verify: `--filter` on the cathedral and Toompea model tests; compiled-height assertion for both masses; map pre-commit gate; skyline plates from the Lower Town looking up, the harbour and the plateau; canon sign-off | note: the castle model is LM-04 (R-1128)
- [x] R-1125 | UF-13 | CANCELLED 2026-09-30 - fully duplicated: St Catherine's is LM-02 (R-1124) and St Michael's is LM-05 (R-1130), same building ids on the same maps, both already placed. Carried requirement: convent closes stay open ground registered as owned `open_regions` and no signed historical band may be lowered for a model - held by R-1118 and to be restated in R-1124 and R-1130. Contract kept at `docs/tasks/urban_form/UF-13_convent_precincts.md` for the repository state it recorded.
- [ ] R-1129 | UF-14 | deps: R-980 | deliverable: ADR 0027 (scope approved by Artjom Kurapov 2026-09-30; write it Accepted with that date) for bounded reval_hinterland gate-linked membership, complete census, per-map measured-baseline cost estimates and the approved equivalent-cost removal of WB-11 deliverables 4 and 7 | verify: ADR carries the maintainer name and ISO date and does not widen the approved membership; independent scope/budget review; unique membership count check; python3 tools/generate_active_docs_report.py --check; git diff --check
- [ ] R-1133 | UF-15 | deps: R-1129, R-980, R-1117, R-976 | deliverable: registered connective hinterland blueprints and second world layout, consuming CO-04 shore ladder | verify: headless blueprint/layout/seam/audit/activation/conversion checks, cross-gate walk, benchmark and graded-shore plates
- [ ] R-1136 | UF-16 | deps: R-1114,R-1115 | deliverable: 20 exterior master plans and additive R-716 street-legibility packets covering every gate/street end at noon and midnight plus skeleton overlays and named human reviews | verify: existing visual verifier and unittest module; missing-plate/inventory/review negative checks; 20-plan coverage review; python3 tools/generate_active_docs_report.py --check; python3 tools/verify_evidence_image_retention.py; human review answers and board refs for repeated-row findings

## Spirit dialogue pack (ADR 0033, maintainer request 2026-10-07)

Contract: [ADR 0033](docs/adr/0033-teen-protagonist-and-spirit-dialogue-combat.md), feature page [`docs/SYSTEMS/SPIRIT_DIALOGUE.md`](docs/SYSTEMS/SPIRIT_DIALOGUE.md). Rows use pack IDs `SD-nn`; the board assigns the `R-NNN` refs when each row is created there (create the epic first, then renumber if needed). Delivery order stays strict: these rows do not pull ahead of the vertical-slice MVP gates. Every row updates its feature page in the same change.

- [x] SD-01 | DONE 2026-10-07 (`apprentice.md` brief, CANON section, kalev/mart/README sync; hero name still open) | deps: ADR 0033 | deliverable: canon and character reconciliation - confidence labels in `docs/CANON.md` for the almshouse, spirit-world creatures and guilt rites; a brief for the teen protagonist; `kalev.md` and `mart.md` rewritten for the mentor/missing-apprentice roles; README story text synced | allowed files: `docs/CANON.md`, `docs/CHARACTERS/`, `README.md`, `TODO.md` | constraints: docs only; no clinical diagnosis for the hero; every new named claim carries a label | verify: `python3 tools/docs_index.py --check`; `python3 tools/generate_active_docs_report.py --check`; Canon Keeper review
- [x] SD-02 | DONE 2026-10-07 (schema `duel`/`move`, validator codes DUEL_*, runner `get_duel`/`get_current_move`, fixture and tests) | deps: ADR 0033 | deliverable: dialogue move tags (`move_kind`, `element`, `stakes[]`, `spirit_image_id`) in the schema, runner passthrough and validator rules (missing stakes, unreachable resolution) | allowed files: `schemas/dialogue.schema.json`, `tools/validate_content.py`, `tests/python/test_validate_content.py`, `scripts/dialogue/dialogue_runner.gd`, `tests/godot/test_dialogue_move_tags.gd`, `docs/SYSTEMS/DIALOGUE.md`, `docs/SYSTEMS/SPIRIT_DIALOGUE.md` | constraints: untagged dialogue stays valid; no runtime LLM; no change to existing record IDs | verify: `python3 -m unittest tests.python.test_validate_content -v`; `python3 tools/validate_content.py content/examples/valid content/examples/support`; `godot --headless --path . --script tools/run_godot_tests.gd --filter=test_dialogue_move_tags`
- [x] SD-03 | DONE 2026-10-07 (`GuiltLedger`, `GameState.guilt`, `guilt` save section, `test_guilt_state`) | deps: ADR 0033 | deliverable: per-school guilt state (`guilt.church`, `guilt.folk`, `guilt.civic`) with deterministic circumstance weights and absolution hooks, saved and loaded through `GameState` | allowed files: `scripts/state/`, `scripts/save/`, `tests/godot/test_guilt_state.gd`, `docs/SYSTEMS/STATE_AND_SAVES.md`, `docs/SYSTEMS/SPIRIT_DIALOGUE.md` | constraints: no single morality score; guilt never mutates faction ledger directly | verify: guilt weight table test, save/load round trip, full Godot suite
- [x] SD-04 | DONE 2026-10-07 (`SpiritDuel`, `SpiritArenaHost`, `test_spirit_arena`, capture tool; no scene mounts it yet; the reply wheel is buttons, no separate .tscn) | deps: SD-02, SD-03 | deliverable: spirit arena host prototype - enter and exit from a dialogue node, telegraphed opponent lines, reply wheel, guard/dodge on existing `CombatVitals`, one authored duel | allowed files: `scripts/combat/`, `scripts/dialogue/`, `scenes/combat/`, `tests/godot/test_spirit_arena.gd`, `docs/SYSTEMS/COMBAT.md`, `docs/SYSTEMS/SPIRIT_DIALOGUE.md` | constraints: reuse combat feel, no new framework or event bus; keyboard/mouse and gamepad paths; outcomes use the existing `EncounterOutcome` vocabulary | verify: arena headless test (enter, win, lose with checkpoint, exit state), captured arena frames via `tools/godot_render.sh`, full Godot suite
- [x] SD-05 | DONE 2026-10-07 (content/prologue: quarrel, confrontation with three resolutions, Kalev scene, three cast records, test_spirit_prologue; not mounted in a map yet) | deps: SD-02, SD-04, SD-10 | deliverable: prologue content - almshouse quarrel as a tagged duel the hero observes, a first own duel, the physical-versus-spiritual choice, Kalev taking the apprentice | allowed files: `content/`, `localization/`, `tests/godot/test_spirit_prologue.gd`, `docs/SYSTEMS/SPIRIT_DIALOGUE.md`, `docs/SYSTEMS/QUESTS.md` | constraints: one location, no new map activation without its gates; offline authored text only | verify: content validator, prologue playthrough test, authoring-cost note appended to `docs/SYSTEMS/SPIRIT_DIALOGUE.md`
- [x] SD-06 | DONE 2026-10-07 (`SpiritObservation`, `GameState.learn_move`, host `observe()`, `test_spirit_observation`; learned moves and intervention flags are not yet consumed) | deps: SD-04 | deliverable: observation mode - dim the world into an NPC-versus-NPC duel, learn a move from it, optional intervention | allowed files: `scripts/dialogue/`, `scripts/combat/`, `tests/godot/test_spirit_observation.gd`, `docs/SYSTEMS/SPIRIT_DIALOGUE.md` | constraints: no input needed to watch; learned moves are save-stable IDs | verify: observation test (learn once, intervene branch), save/load, captured frames
- [x] SD-07 | DONE 2026-10-07 (`PhysicalBlowGuilt`, `GuiltLedger.record_kill`, `CombatRoomEnemy.guilt_context`, player hook, arena debuffs, `test_hybrid_combat_guilt`; prologue flag blows and rites still unwired) | deps: SD-03, SD-04 | deliverable: hybrid physical strike - a blow in the world opens guilt weighted by circumstance and applies the spirit-layer debuff; physical-only encounters carry low guilt | allowed files: `scripts/combat/`, `scripts/state/`, `tests/godot/test_hybrid_combat_guilt.gd`, `docs/SYSTEMS/COMBAT.md`, `docs/SYSTEMS/SPIRIT_DIALOGUE.md` | constraints: weights deterministic; existing encounter checkpoints keep working | verify: weight and debuff tests per circumstance (self-defence, defence of another, unarmed victim, killing), full Godot suite
- [x] SD-08 | DONE 2026-10-07 (`DialogueLanguage`, comprehension state and saves, schema fields, always-translate setting and toggle, arena and observation gating, `test_language_comprehension`; no content trains languages yet) | deps: SD-02, SD-03 | deliverable: language comprehension skill - unknown-language lines render as imagery, comprehension unlocks stakes and replies | allowed files: `scripts/dialogue/`, `localization/`, `tests/godot/test_language_comprehension.gd`, `docs/SYSTEMS/DIALOGUE.md`, `docs/SYSTEMS/SPIRIT_DIALOGUE.md` | constraints: accessibility settings still show readable subtitles on request | verify: render test at comprehension levels, settings test, save/load
- [x] SD-09 | DONE 2026-10-07 (`SelfTalk`, `player_self_talk` action and bindings, NPC witness hook, `test_self_talk`; map-view actors are not witnesses yet) | deps: SD-03 | deliverable: self-talk action (buff) and deterministic witness reactions by faction | allowed files: `scripts/player/`, `scripts/faction/`, `tests/godot/test_self_talk_witness.gd`, `docs/SYSTEMS/FACTIONS_AND_ECONOMY.md`, `docs/SYSTEMS/SPIRIT_DIALOGUE.md` | constraints: witness count and faction rules are authored; no hidden randomness | verify: witness reaction table test, save/load
- [x] SD-10 | DONE 2026-10-07 (hero spec `apprentice`, `variants/apprentice.tscn`, player rig switched, `test_apprentice_rig`; portrait still open) | deps: SD-01 | deliverable: teen protagonist model and portrait on the realistic-human pipeline and the shared rig | allowed files: `tools/assets/realistic_humans/`, `assets/characters/`, `assets/SOURCES.csv`, `tests/godot/test_character_rig.gd`, `docs/CHARACTER_REALISM_BACKLOG.md` | constraints: ADR 0022 pipeline only, no legacy sprites; GLB budget per ADR 0025; provenance rows added | verify: asset lint and sources validators, rig test, neutral and walk captures
- [x] SD-11 | DONE 2026-10-07 (`BUILD_TEEN` adjustment in `CombatMoveCatalog`, resolver and rig build plumbing, `Player.combat_build`, `test_teen_move_set`; adult-pinned tests set the adult build; rolls, dodges and casts not scaled) | deps: SD-10 | deliverable: teen move set mapped on the shared rig, replacing adult-smith moves in `CombatMoveCatalog` | allowed files: `scripts/combat/combat_move_catalog.gd`, `scripts/player/`, `tests/godot/test_combat_moves.gd`, `docs/SYSTEMS/COMBAT_ANIMATION.md` | constraints: no new clip import pipeline, existing 76 clips reused | verify: move catalog test, timing capture sheet
- [x] SD-12 | DONE 2026-10-07 (scope corrected: the commission side only - `apprentice_method` on forging options, `select_option(id, secretly)`, overlay button, authored on three commissions, `test_apprentice_commissions`; Kalev as a mounted master-smith NPC moved to SD-17) | deps: SD-01, SD-10 | deliverable: Kalev as master-smith NPC and apprentice control of commissions (quiet modification, substitution, concealment) writing the same forged records | allowed files: `scripts/forge/`, `content/`, `tests/godot/test_apprentice_commissions.gd`, `docs/SYSTEMS/QUESTS.md` | constraints: forged-record schema unchanged; Bitter Brew still completes | verify: commission and aftermath tests for each modification path, full Godot suite
- [ ] SD-17 | deps: SD-12, SD-10 | deliverable: Kalev mounted as the master-smith NPC in the smithy (placement, schedule and dialogue hand-off to the apprentice) without breaking the smithy routine system | allowed files: `content/routines/kalev_smithy.json`, `scripts/world/smithy_routine_controller.gd`, `scripts/world/smithy_routine_definition.gd`, `tests/godot/test_kalev_smithy_domestic_life.gd`, `content/prologue/`, `docs/SYSTEMS/SPIRIT_DIALOGUE.md` | constraints: no hand edits to giant city `.tscn`; the player rig is the apprentice; keep stable activity-point IDs | verify: routine tests, a smithy capture with both rigs, full Godot suite for the smithy
- [x] SD-13 | DONE 2026-10-07 (scope corrected: `scripts/tower/` is NOT unmounted - `test_enterable_tower_contract`, the Kuldjala and Rentenitorn interior tests and three boss encounters depend on it, so nothing was deleted; physical night-mission templates marked retired in `COMBAT_NIGHT.md`, tower bosses marked frozen in `COMBAT.md` and ADR 0033; code deletion moves to SD-16) | deps: ADR 0033 | allowed files: `docs/SYSTEMS/COMBAT_NIGHT.md`, `docs/SYSTEMS/COMBAT.md`, `docs/adr/0033-teen-protagonist-and-spirit-dialogue-combat.md`, `TODO.md` | verify: `python3 tools/generate_active_docs_report.py --check`
- [x] SD-14 | DONE 2026-10-07 (world casts refused via `GameState.in_spirit_world`, arena `cast_spell` through `MagicResolver`, host number keys and modal overlay, `test_spirit_magic`; arena draws no spell art) | deps: SD-04 | deliverable: magic casting only in the spirit arena - gate spellforge input and world VFX, reuse the delivery nodes in the arena | allowed files: `scripts/magic/`, `scripts/map/view3d/map_view_magic_vfx.gd`, `tests/godot/test_magic_runtime.gd`, `docs/SYSTEMS/MAGIC.md` | constraints: existing grants and willpower state keep saving; no new spell content | verify: magic tests (cast blocked in world, works in arena), full Godot suite
- [x] SD-15 | DONE 2026-10-07 (`SpiritTraits`, `GameState.grant_trait` and saves, `duel.temperament`, arena modifiers, `test_spirit_traits`; nothing grants traits in play yet) | deps: SD-02, SD-04 | deliverable: double-edged hero traits and NPC temperament tags that change which move kinds hit | allowed files: `scripts/state/`, `content/`, `tests/godot/test_traits.gd`, `docs/SYSTEMS/PSYCHE.md`, `docs/SYSTEMS/SPIRIT_DIALOGUE.md` | constraints: traits are authored IDs, not a morality score | verify: trait modifier table test, save/load
- [ ] SD-16 | PROGRESS 2026-10-07: report written at `docs/reports/spirit_dialogue_prototype_review.md` with a go recommendation and conditions; the independent second review and the maintainer's decisions (faction authoring order, tower code, hero name) are still open | deps: SD-05, SD-06, SD-07 | deliverable: prototype review gate - authoring cost per tagged scene, balance of hybrid combat, go or no-go, and a decision on the launch faction count, and whether to delete the frozen tower boss code | allowed files: `docs/reports/spirit_dialogue_prototype_review.md`, `docs/adr/`, `TODO.md` | constraints: report states the evidence; any scope change needs an ADR | verify: independent second review; `python3 tools/generate_active_docs_report.py --check`
