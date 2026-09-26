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
| P0 |    16  |     0  | Baseline, storage, materials, historical audit |
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

- [ ] R-941 | deps: WS-11 | deliverable: sky_weather_3d.gdshader calls shared atmosphere_sky_view_uv and ATMO_SKY_VIEW_HEIGHT_KM; private sky_view_uv / SKY_VIEW_HEIGHT_KM deleted | allowed files: `scripts/map/view3d/sky_weather_3d.gdshader`, `tests/godot/test_sky_weather_3d.gd`, `TODO.md` | verify: `--filter=test_sky_weather_3d,test_sky_atmosphere_lut`; Compatibility `tools/capture_ws10_sky_elevations.gd -- --elevation=5` plate within 1 LSB of the pre-change plate; no `vec2 sky_view_uv(` left

R-941 implementation landed. The dome samples the sky-view LUT through
`atmosphere_sky_view_uv(dir, sun_direction, sky_lut_size)` and uses `ATMO_SKY_VIEW_HEIGHT_KM`
for the sun-disk transmittance height. No visual change intended. Focused tests and the
Compatibility elevation-5 plate are the remaining verify items.

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

## Storybook model set

- [ ] P0-209b | deps: P0-209a | deliverable: replace the visually rejected procedural mammals from scratch with convincingly realistic sculpted or scanned source geometry and textured surfaces | allowed files: `tools/assets/realistic_mammals.py`, `tools/assets/mammal_limb_anatomy.py`, `tools/assets/build_storybook_models.py`, `tools/assets/import_realistic_mammals.py`, `tools/assets/import_authored_rat.py`, `tools/assets/pack_authored_rat.py`, `tools/verify_storybook_models.py`, `tools/capture_animal_realism.gd`, `scripts/map/view3d/map_view_medieval_animal_models.gd`, `tests/python/test_mammal_limb_anatomy.py`, `tests/godot/test_mammal_limb_anatomy.gd`, `tests/godot/test_storybook_models.gd`, `tests/godot/test_storybook_live_integration.gd`, `assets/storybook/`, `assets/SOURCES.csv`, `docs/ART_BIBLE.md`, `docs/reports/animal_realism_2026-09-12.md`, `docs/reports/images/animal_realism/`, `TODO.md` | constraints: licensed commercial-use sources; no ripped game assets; preserve species IDs, runtime paths and behavior; replace failed geometry instead of polishing primitive unions; preserve unrelated WIP | verify: inspect replacement source silhouettes and materials; Godot imports and fauna tests; real runtime captures; provenance and independent visual review; do not close on technical tests alone; replacement implementation and 81 focused tests complete; maintainer visual acceptance remains open

## Storage and file-size (active)

See [`docs/STORAGE_SIZE_BACKLOG.md`](docs/STORAGE_SIZE_BACKLOG.md) for full deliverable/verify contracts.

- [ ] P0-180 | deps: P0-177 | deliverable: curated music take reduction with MusicDirector proof | verify: soundtrack tests + recorded byte drop
- [ ] P0-182 | deps: P0-180 | deliverable: runtime audio bitrate/size budget | verify: lint/validator + audio tests
- [ ] P0-183 | deps: P0-177 | deliverable: oversized runtime GLB budgets (oak + shared characters) | verify: asset lint + focused Godot filters
- [ ] P0-185 | deps: P0-184 | deliverable: justified view3d hotspot extractions only | verify: named focused filters

## Character visual realism (active)

See [`docs/CHARACTER_REALISM_BACKLOG.md`](docs/CHARACTER_REALISM_BACKLOG.md) for full deliverable/verify contracts. Review: [`docs/reports/character_visual_realism_review_2026-08-12.md`](docs/reports/character_visual_realism_review_2026-08-12.md).

- [ ] P0-189 | deps: P0-188 | deliverable: Godot vertex-colour albedo path for head/beard/skin tints | verify: face plates + character rig + asset lint
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
