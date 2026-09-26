# Water and sky realism task pack (Tidewater port)

Status: proposed task pack, 2026-09-25. None of these tasks are in [`TODO.md`](../../../TODO.md) yet.
Each file contains a ready-to-paste `TODO.md` line; give it the next free `P0-` id when it is added
(the last used id on 2026-09-25 was **P0-229**). The `WS-NN` ids below are local names only.

## Reference

[Tidewater](https://dgreenheck.github.io/tidewater/) ([source](https://github.com/dgreenheck/tidewater),
MIT license) is a browser fishing game with its own WebGPU/WGSL engine. We want its ocean, underwater
and sky look. The constants quoted in these tasks were read from its shipped bundle
(`assets/index-*.js`) on 2026-09-25. Clone the repository for the readable source before porting.

**License rule:** porting MIT code or shader math into this AGPLv3 project is allowed, but the MIT
copyright notice must ship with it. The first task that ports code (WS-01) adds a
`notice.code.tidewater` entry to [`docs/THIRD_PARTY_NOTICES.md`](../../THIRD_PARTY_NOTICES.md) that
holds the full MIT text. Later tasks cite that entry in code comments where they port code
(`// Ported from Tidewater (MIT), see notice.code.tidewater`).

## The main constraint

Tidewater does its ocean FFT, foam accumulation, wake simulation, atmosphere lookup tables and clouds
in **compute shaders**. This project uses the **GL Compatibility** renderer (`project.godot`
`renderer/rendering_method="gl_compatibility"`). It has no compute shaders and no `RenderingDevice`,
and it doesn't support SSR. Every task below therefore uses one of these substitutes:

| Tidewater technique | Our substitute |
|---|---|
| Real-time GPU FFT | Offline Python FFT bake into **seamless looping** textures (WS-03) |
| Compute LUT passes | Offline bake for static LUTs (WS-09); `SubViewport` + `ColorRect` shader rendered on demand for dynamic LUTs (WS-10) |
| Foam and wake state carried between frames | Baked into the loop (WS-06), or two `SubViewport` render targets swapped each frame (WS-15) |
| Volumetric clouds | Out of scope; reuse the existing 2D cloud field for shadows (WS-12) |

Don't switch the project renderer inside any of these tasks. That would be a separate ADR.

## Shared facts

- **World scale:** 1 world unit = 1 map cell = **0.87 m**
  (`MapViewBuildingMaterials.METERS_PER_WORLD_UNIT`). Every physical constant (wavelengths, g,
  extinction per metre) must be converted.
- **Water shader:** `scripts/map/view3d/map_view_water.gdshader`. It is lit by Godot (`ALBEDO`,
  `ROUGHNESS`, `SPECULAR`), reads `hint_screen_texture` and `hint_depth_texture`, and uses
  `cull_disabled` so the underside can be seen.
- **Water material wiring:** `scripts/map/view3d/map_view_water_materials.gd`
  (`water_surface`, `apply_sea_weather`, `apply_water_lighting`, `apply_coastal_tide`,
  `apply_water_sky_reflection`).
- **Sky:** `scripts/map/view3d/sky_weather_3d.gdshader` + `sky_weather_3d.gd` (`SkyWeather3D`,
  quality tiers `minimum` / `recommended`), astronomy in `sky_astronomy.gd`, lighting in
  `map_view_lighting.gd`.
- **Boats:** `scripts/map/view3d/boat_float_3d.gd` must match the shader's wave field
  (`sample_wave`, `sample_hull_attitude`).
- **Existing water tests:** `tests/godot/test_r715_water_*.gd`, `test_boat_float_3d.gd`,
  `test_sky_weather_3d.gd`, `test_r713_sky_weather_continuity.gd`, `test_weather_realism.gd`.
- **Visual evidence:** `tools/capture_r715_water_acceptance.gd` (needs a real renderer, never
  `--headless`) and `tools/capture_r713_sky_weather_continuity.gd`. Put screenshots in
  `docs/reports/images/`.
- **Performance evidence:** `tools/run_performance_report.sh`,
  `python3 tools/verify_r715_water_performance.py`.
- **Godot binary:** `/Applications/Godot.app/Contents/MacOS/Godot` (not on PATH).

## Task list and order

| # | File | Summary | Depends on |
|---|------|---------|------------|
| WS-01 | [WS-01_refracted_water_column.md](WS-01_refracted_water_column.md) | Light path through the water follows the refracted ray (Snell's law) to the bed | none |
| WS-02 | [WS-02_ggx_sun_glint.md](WS-02_ggx_sun_glint.md) | Physically based sun and moon glint via a water `light()` function | none |
| WS-03 | [WS-03_fft_ocean_bake_tool.md](WS-03_fft_ocean_bake_tool.md) | Offline JONSWAP FFT tool that bakes seamless looping cascades | none |
| WS-04 | [WS-04_fft_ocean_shader.md](WS-04_fft_ocean_shader.md) | Water shader samples the baked FFT cascades | WS-03 |
| WS-05 | [WS-05_boat_float_fft_parity.md](WS-05_boat_float_fft_parity.md) | Boats and CPU water-height queries read the same baked field | WS-04 |
| WS-06 | [WS-06_fft_foam_whitecaps.md](WS-06_fft_foam_whitecaps.md) | Lingering, textured whitecaps from the baked foam channel | WS-04 |
| WS-07 | [WS-07_baked_caustics.md](WS-07_baked_caustics.md) | Caustics derived from the FFT, projected onto the real bed | WS-01, WS-03 |
| WS-08 | [WS-08_shore_swash.md](WS-08_shore_swash.md) | Waves break, run up the beach and leave a wet band on the sand | WS-04 |
| WS-09 | [WS-09_atmosphere_static_luts.md](WS-09_atmosphere_static_luts.md) | Offline Hillaire transmittance and multi-scattering LUTs | none |
| WS-10 | [WS-10_sky_view_lut_runtime.md](WS-10_sky_view_lut_runtime.md) | Physical sky dome from a sky-view LUT that follows the sun | WS-09 |
| WS-11 | [WS-11_sky_driven_water_and_fog.md](WS-11_sky_driven_water_and_fog.md) | Water reflection, fog, sun and ambient colour come from the atmosphere | WS-10, WS-02 |
| WS-12 | [WS-12_cloud_shadow_map.md](WS-12_cloud_shadow_map.md) | Moving cloud shadows on ground and water | none |
| WS-13 | [WS-13_underwater_view_pass.md](WS-13_underwater_view_pass.md) | Underwater fog, light shafts, Snell's window and a waterline split across the lens | WS-01, WS-05, WS-07 |
| WS-13b | [WS-13b_harbour_basin_depth.md](WS-13b_harbour_basin_depth.md) | Real rendered depth under open sea (flat gameplay bed kept), seabed apron, top-down parity | WS-13 |
| WS-13d | [WS-13d_pier_cribs.md](WS-13d_pier_cribs.md) | Log crib and guide piles under timber landing decks, down to the rendered bed | WS-13b |
| WS-14 | [WS-14_swim_dive_adr.md](WS-14_swim_dive_adr.md) | ADR and design for swimming and diving (scope change) | WS-13 |
| WS-15 | [WS-15_interactive_ripples_wake.md](WS-15_interactive_ripples_wake.md) | Ripples and wakes around moving bodies, simulated in render targets | WS-04 |

Recommended order: WS-01 → WS-02 → WS-03 → WS-04 → WS-05 → WS-06 → WS-09 → WS-10 → WS-11 →
WS-07 → WS-12 → WS-08 → WS-13 → WS-13b → WS-14 → WS-15. WS-01, WS-02, WS-03, WS-09 and WS-12 have no
dependencies and can run in parallel.

## Rules for every task

1. Read [`AGENTS.md`](../../../AGENTS.md) (task contract, definition of done),
   [`docs/ART_BIBLE.md`](../../ART_BIBLE.md) and
   [ADR 0018](../../adr/0018-saturated-hdr-fantasy-anime-visual-direction.md) first. ADR 0018 calls
   for an HDR range with AgX tonemapping, saturated Baltic cyan and blue, and colourful cobalt/indigo
   nights. Physically based water and sky are the *base*. Where art direction and physical accuracy
   disagree, art direction wins, so keep an explicit tint, exposure or grade uniform that lets art
   override the physics.
2. Change only the files listed under **Allowed files**. If another file must change, stop and
   update the task first.
3. Both quality tiers must work. The `minimum` tier may fall back to the old path, but it must never
   show a black or missing surface.
4. There must be no per-frame CPU readback from the GPU. Readbacks are only allowed on event-driven
   updates such as a LUT rebuild.
5. Baked binary assets follow [`docs/ASSET_STORAGE_POLICY.md`](../../ASSET_STORAGE_POLICY.md), get
   rows in `assets/SOURCES.csv` (`creator_or_tool` = the bake tool path, `seed`, and the parameters
   in `edits`), and must pass `python3 tools/verify_storage_hygiene.py`,
   `python3 tools/validate_asset_sources.py` and `python3 tools/verify_asset_lint.py`.
6. Before committing, run at minimum:
   ```bash
   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd
   python3 tools/generate_active_docs_report.py --check
   git diff --check
   ```
   Also run any task-specific commands listed in the task.
7. Visual tasks must attach before and after captures of the same plate (map, time and weather)
   from `tools/capture_r715_water_acceptance.gd`, run through `tools/godot_render.sh` (never the
   bare Godot binary, which pops up a window) with
   `--rendering-method mobile --rendering-driver metal` and also with the default Compatibility
   renderer.
8. Another agent may be committing at the same time. Stage files by explicit path only.
