# CO-01 coastal ground materials (R-948)

Task contract: [`docs/tasks/coast/CO-01_coastal_ground_materials.md`](../tasks/coast/CO-01_coastal_ground_materials.md).
Date: 2026-09-28.

## Result

Kalamaja's beach, mud and meadow now render from full PBR sets with visible grain,
relief and damp/dry roughness. The procedural sand speckle is gone for `sand` and
`coast_sand`.

The main defect was not texture resolution. Since P0-219 (2026-09-24) the terrain
blend shader resolved every authored plate in `vertex()`. With
`TERRAIN_SUBDIVISIONS = 3`, that is one texel read every 0.29 world units, so a
512 px or 2048 px plate showed up as an interpolated colour blur with speckles.
That is the "flat tinted plane" in the maintainer's report, and it affected grass,
mud, hay, timber floors and cobble as well as sand.

## What changed

| Area | Change |
|---|---|
| Plates | New Leonardo plates, generated at 1536 px (the model's limit) and processed to a 2048 px albedo: `coast_sand` (damp foreshore, shells, ripples), `sand` (dry wind-rippled upper beach), `shore_shingle` (mixed pebble storm beach), `mud` v3 (hoof and turnshoe prints, baked glints removed), `grass` v4 (same prompt as v3). |
| Normal / roughness | Derived from each processed albedo by `tools/process_leonardo_terrain_textures.py`: a wrap-aware, high-passed luminance height, a central-difference OpenGL normal, and a dryness-driven roughness, all at 1024 px. Leonardo cannot produce matching normal/roughness plates for an albedo it made earlier. |
| Runtime binding | `map_view_terrain_materials.gd` builds three `Texture2DArray`s (albedo, normal, roughness) in the fixed layer order grass, mud, sand, coast_sand, shore_shingle. That is three samplers for five PBR sets, because GL Compatibility has about 16 texture units and the renderer reserves several. It replaces the two `grass_albedo` / `mud_albedo` samplers. |
| Shader | `map_view_terrain_blend.gdshader` keeps the P0-219 per-corner weights, so paving edges stay free of wedges. Each corner now emits per-family weights, and grass, mud, sand, coast_sand, hay, timber floor and cobble are sampled **per fragment**. Only the 128 px procedural families (dirt, farm soil, ash, stone, plaster) are still resolved per corner. |
| Anti-tiling | Every family is sampled at 1x and at about 0.17x (rotated) under a low-frequency mask, with the existing continuous world-space warp. Art controls: `ground_uv_scale`, `ground_detail_strength`, `ground_normal_strength` (vec4 for families 0-3, plus scalar `shingle_*`). |
| Palette | Grass and mud keep the 16% `OutdoorTerrainPalette` nudge. The sand families are renormalised to their palette tint (`sand_palette_authority` 0.85, `sand_palette_value` 0.91, which is the retired speckle's mean). The plate mean comes from the smallest mip, read through the same `source_color` sampler as the plate. |
| Shingle | Not a terrain ID. It shows as storm-line strands inside `coast_sand` (`coast_shingle_amount` 0.35) and is available to CO-02 scatter. |
| Per-terrain material | `terrain(sand|coast_sand)` binds the authored albedo, normal and roughness on a `StandardMaterial3D` and needs no procedural bake. |
| WS-08 | The wet-sand swash path is unchanged (`sand_layer` / `coast_sand_layer`). It now darkens a real albedo. |

## Decisions (recorded per the task contract)

1. **Storage: albedo 2048, derived maps 1024.** A 2048 px derived normal is 10-11 MiB as PNG
   (`coast_sand` 11.0, `sand` 10.4 MiB), which is over the 10 MiB standard-Git limit in
   `docs/ASSET_STORAGE_POLICY.md`. It would also only resolve JPEG noise from the 1536 px source.
   Normal and roughness therefore ship at 1024. At the gameplay camera, one 2.0-unit grass repeat
   covers about 42 px on a 720 px frame, so 1024 still gives more than one texel per pixel in the
   close framing.
2. **Measured storage** (PNG, MiB): grass 7.8 / 2.4 / 0.5, mud 5.3 / 2.1 / 0.6, sand 5.0 / 2.2 / 0.5,
   coast_sand 6.6 / 2.3 / 0.7, shore_shingle 6.8 / 1.9 / 0.5 (albedo / normal / roughness). That is
   **45.2 MiB** in total, **+44.2 MiB** net over the two 512 px plates it replaces, plus 11 MiB of
   Leonardo candidates under `generated/leonardo/`. Every file is below 10 MiB.
3. **VRAM.** The plates import VRAM-compressed (`compress/mode=2`; normals as normal maps, roughness
   channel-packed), so the three arrays cost about 14 MiB (albedo, BC1/ETC2) plus about 7 MiB
   (normal and roughness) on the GPU. The same five plates at lossless RGBA8 would be about 147 MiB.
4. **sRGB decode.** A render probe (an unshaded quad sampling the smallest array mip) gave these
   results. GL Compatibility returns linear values from the VRAM-compressed array with or without
   `source_color`. Mobile/Metal returns raw sRGB unless the hint is present. So `ground_albedo`
   keeps `source_color`, and the plate mean used for sand renormalisation is read in-shader through
   that same sampler. Two earlier attempts failed on this: a manual sRGB decode (which decoded twice
   on Compatibility, so mud and grass went too dark) and CPU-side linear means (a colour-space
   mismatch that blew the sand out to white).
5. **Cobble, hay and timber floors** also moved to per-fragment sampling. Their textures and values
   are unchanged, but boards and stones now resolve at pixel rate. This is the same P0-219 defect,
   and none of those plates were replaced.
6. **Main-thread plate loading and neutral fallback layers.** The CO-01 plates stay out of the
   staged assembly's threaded prefetch. When a staged assembly was cancelled while a 2048 px plate
   was still loading on a worker, the plate was dropped before its queued RenderingServer
   initialize ran, and the full suite reported `texture_2d_initialize: "t" is null` (reproduced by
   `test_async_location_assembly::test_cancel_with_worker_jobs_in_flight_joins_them`). The arrays
   now load the plates once on the main thread and keep them until `reset()`. The shader never
   samples the grass, mud and sand layers of the 128 px `terrain_patterns` array, so they reuse one
   neutral image instead of a procedural texture per map seed.
7. **Allowed-file additions:** `generated/leonardo/<bundle>/` for the five generation bundles
   (repository convention for plate provenance), and `tests/godot/test_map_view_material_resolution.gd`,
   whose `grass_albedo` / `mud_albedo` assertion now checks the ground array. Legacy families in
   the processor keep their 512 px output.

## Evidence

Captured by `tools/capture_co01_ground_materials.gd` through `tools/godot_render.sh` on
`reval_harbor_east`, day, clear and overcast. "Before" plates come from a clean `HEAD` worktree
(`04bf644b`); "after" plates come from this change. Poses: `gameplay` (shipped orthographic camera
at `CharacterScale.GAMEPLAY_ORTHOGRAPHIC_SIZE`), `close` (eye level at 1.7 units over the foreshore)
and `shore_run` (long view along the beach, used to judge tiling).

| Plate | Compatibility | Mobile / Metal |
|---|---|---|
| Close, clear | ![](images/co01_close_clear_compat_before.png) ![](images/co01_close_clear_compat_after.png) | ![](images/co01_close_clear_mobile_before.png) ![](images/co01_close_clear_mobile_after.png) |
| Close, overcast | ![](images/co01_close_overcast_compat_before.png) ![](images/co01_close_overcast_compat_after.png) | ![](images/co01_close_overcast_mobile_before.png) ![](images/co01_close_overcast_mobile_after.png) |
| Gameplay, clear | ![](images/co01_gameplay_clear_compat_before.png) ![](images/co01_gameplay_clear_compat_after.png) | ![](images/co01_gameplay_clear_mobile_before.png) ![](images/co01_gameplay_clear_mobile_after.png) |
| Gameplay, overcast | ![](images/co01_gameplay_overcast_compat_before.png) ![](images/co01_gameplay_overcast_compat_after.png) | ![](images/co01_gameplay_overcast_mobile_before.png) ![](images/co01_gameplay_overcast_mobile_after.png) |
| Shore run, clear | ![](images/co01_shore_run_clear_compat_before.png) ![](images/co01_shore_run_clear_compat_after.png) | ![](images/co01_shore_run_clear_mobile_before.png) ![](images/co01_shore_run_clear_mobile_after.png) |
| Shore run, overcast | ![](images/co01_shore_run_overcast_compat_before.png) ![](images/co01_shore_run_overcast_compat_after.png) | ![](images/co01_shore_run_overcast_mobile_before.png) ![](images/co01_shore_run_overcast_mobile_after.png) |

Mean sRGB value of fixed frame regions, clear weather (before -> after):

| Region | Compatibility | Mobile / Metal |
|---|---|---|
| Close, sunlit sand | (158,138,103) -> (151,131,105) | (176,163,150) -> (171,156,148) |
| Close, mud foreground | (112,74,28) -> (92,68,33) | (103,62,23) -> (84,58,28) |
| Gameplay, beach band | (119,112,89) -> (117,111,94) | (137,134,130) -> (135,130,131) |
| Gameplay, mud yard | (61,67,16) -> (54,65,19) | (71,70,42) -> (66,69,44) |
| Gameplay, meadow | (26,45,21) -> (25,46,15) | (32,47,27) -> (31,47,22) |

Observations:

- Hue and value hold within about 5% everywhere except the close mud. That region is about 15%
  darker because the per-fragment hoof prints and ruts now resolve instead of being averaged away.
- Close plates: sand gains grain, ripples, shell fragments and storm-line shingle; mud gains prints
  and ruts; pier boards become legible.
- No tile grid is visible along the `shore_run` band on either renderer.
- The Mobile/Metal close plates use depth of field and were washed out before this change too;
  that is unrelated to CO-01.
- Differences in roofs, boathouse walls and facades between before and after come from other
  uncommitted building-variant work in the working tree at capture time, not from this change.

## Verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/run_godot_tests.gd -- --filter=test_terrain_material_channels,test_r715_water_material_contract
python3 tools/validate_asset_sources.py
python3 tools/verify_asset_lint.py
python3 tools/verify_storage_hygiene.py
python3 tools/verify_texture_prompts.py
python3 tools/generate_active_docs_report.py --check
```

Results on 2026-09-28. The candidate commit was verified in a clean worktree (HEAD `04bf644b` plus
this change only), because the main checkout also held other agents' uncommitted WorldHost and
building work.

- Focused filters: 73 of 73 tests pass, covering `test_terrain_material_channels`,
  `test_map_view_material_resolution`, `test_map_terrain_chunks`, `test_natural_ground_variation`,
  `test_terrain_plate_get_image`, `test_r715_water_material_contract`, `test_shore_distance_field`,
  `test_async_location_assembly` and `test_slice_surface_wiring`.
- Full suite: 401 files, 2333 tests, 270 failures, 36 errors. HEAD alone gives 400 files, 2325 tests,
  270 failures, 36 errors. The two failure sets are identical, so every failure is pre-existing, and
  the 8 new tests pass.
- Validators: asset sources, asset lint, storage hygiene, texture prompts and active docs all pass.
- Performance: `BENCHMARK_HEADLESS=0 tools/run_performance_report.sh ... --quick` was run for HEAD
  and for the candidate, followed by three alternating 120-frame runs of
  `lower_town_scene_benchmark.tscn`. Lower Town frame time was the same within noise:

  | Run | HEAD median / p95 ms | CO-01 median / p95 ms |
  |---|---|---|
  | 1 | 56.7 / 66.1 | 57.0 / 74.7 |
  | 2 | 58.3 / 71.2 | 58.3 / 65.8 |
  | 3 | 56.8 / 71.9 | 56.3 / 63.4 |

  The quick-report synthetic profiles moved by +1.0 to +1.6 ms p95 (for example `synthetic_128`
  went from 3.13 to 4.50 ms), and all of them stay under 16.67 ms. The absolute Lower Town figure
  on this host swung between 13 and 163 ms p95 from one run to the next, for HEAD as well. The
  minimized `godot_render.sh` window is throttled by the host, so this host cannot judge the
  absolute 16.67 ms budget. The A/B comparison shows no regression.

## Open items

- Named human art review of the five plates. `assets/SOURCES.csv` marks them as
  `review candidate`.
- Dirt (12.4% of Kalamaja), farm soil, ash and plaster are still 128 px procedural layers
  resolved per corner. They need authored plates to benefit from the per-fragment path.

## Seam follow-up (2026-09-29)

The five plates shipped through `_weld_edges(phase_shift=True)`. A half-tile shift makes the two
wrap edges match, but it does not make a non-tileable Leonardo plate tileable: it only moves the
original discontinuity into the middle of the tile, where it repeats as a cross grid. On the
Kalamaja gameplay camera the beach read as a patchwork of rectangular cells
(`docs/reports/images/co01_gameplay_clear_compat_seamfix_before.png`).

Two changes in `tools/process_leonardo_terrain_textures.py`, applied to every family in
`GROUND_OUTPUTS` (`SEAMLESS_FAMILIES`):

1. **Quilting.** A 1280 px tile is cut from the 1536 px plate and its wrap edges are stitched from
   the leftover overlap strips along a minimum-error cut (the second pass is cyclic so the first
   pass stays tileable). The albedo is then resized to 2048 with wrap padding.
2. **De-drift.** Leonardo lights each plate from one side. That broad shading gradient survives
   quilting and repeats as a blotch grid over large ground. It is divided out in linear light at
   80% strength (`DEDRIFT_STRENGTH`), keeping the fine grain and a residual fraction of the
   variation. Normal and roughness are rederived from the corrected albedo.

Measured on the albedo, as a ratio of the mean absolute neighbour-pixel difference of the plate
(1.0 = indistinguishable from the local grain):

| family | wrap edge before | worst interior before | wrap edge after | worst interior after |
|---|---|---|---|---|
| sand | 1.0 | 1.1 | 1.0 | 1.5 |
| coast_sand | 1.0 | 1.1 | 1.0 | 1.2 |
| grass | 0.0 | 3.8 | 0.9 | 1.7 |
| mud | 0.0 | 5.4 | 1.2 | 1.6 |
| shore_shingle | 0.0 | 11.2 | 1.1 | 1.5 |

A wrap value of 0.0 is the welded border of the old pipeline: the edge pixels were averaged, so the
border matched exactly while the real seam sat inside the tile. `sand` and `coast_sand` were already
quilted in the preceding change; only their de-drift is new here.

Evidence: `docs/reports/images/co01_gameplay_clear_compat_seamfix_before.png` and
`..._seamfix_after.png` (same pose, clear weather, Compatibility renderer). Asset sources, asset
lint and storage hygiene pass; every output stays under the 10 MiB standard-Git limit.
