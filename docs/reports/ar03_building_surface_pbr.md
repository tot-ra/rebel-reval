# AR-03 building surface PBR with anti-tiling (R-961)

Status: implemented, awaiting named human visual review and the Metal / weather plate set.
Contract: [`docs/tasks/architecture/AR-03_building_surface_pbr.md`](../tasks/architecture/AR-03_building_surface_pbr.md).

## What changed

- **Surface library.** `tools/generate_building_surface_variants.py` now emits albedo + OpenGL normal +
  packed ORM (R = AO, G = roughness, B = metallic 0) for every stem. It covers the 7 original families
  (21 stems) plus 8 new families at 3 stems each: `ashlar`, `plank`, `daub`, `brick`, `straw`,
  `soot`, `gable_board`, and `logwall`. `logwall` is round-log courses for flat box walls. The existing
  `log` stems are bark and grain only because the kit GLBs model the logs. That makes 45 stems and
  136 PNGs, plus the shared `building_macro_variation.png`. The new painters live in
  `tools/burgher_house_kit_common.py`: `_surface_brick`, `_surface_log_courses`,
  `_surface_boards_horizontal`, `_surface_gable_board`, `_surface_straw` and `_surface_soot`.
  The 42 pre-existing albedo/normal PNGs are byte-identical after regeneration. ORM uses its own RNG
  stream.
- **Library reaches every building.** `map_view_building_materials.gd` resolves each authored key
  through `MapViewBurgherHouseSurfaceVariety.library_stem(key, is_roof, surface_id, map_seed)`. This
  covers `wall_surface_for_building`, `roof_surface_for_building`, `wall_surface`,
  `wall_surface_for_size`, `wall_surface_triplanar`, `roof_surface`, `roof_tile_world` and
  `fortification_masonry`. Key map:

  | Authored key | Library family |
  |---|---|
  | `limestone`, `stone` | `rubble`; `ashlar` on church/chapel/cathedral/convent/monastery/precinct/castle/guild/town_hall IDs |
  | `plaster` | `render` or `limewash` (6 stems) |
  | `timber` | `daub` |
  | `smoked_plaster` | `soot` |
  | `brick`, `plank`, `log` | `brick`, `plank`, `logwall` |
  | roofs `tile`, `shingle`, `thatch`, `straw` | same-named families |

- **Real-metre plates.** Each family has a plate size in metres (`FAMILY_PLATE_METRES`), measured
  from the painter. Examples: brick is 4 x 0.3 m bricks by 12 x 0.1 m courses, shingle is 7 x 0.12 m
  by 10 x 0.2 m, and reed thatch has 6 x 0.27 m courses. Box walls correct for Godot's **3 x 2 BoxMesh
  UV atlas** (one face spans 1/3 U and 1/2 V), which the legacy per-face constants never accounted for.
- **Roughness is no longer constant.** Library materials read roughness from ORM green and AO from ORM
  red. The procedural fallback (cone tower roofs, generic `wall()` / `roof()` helpers) now uses
  per-family constants (`PATTERN_ROUGHNESS`, 0.68-0.95) instead of 1.0. Tar finishes are 0.2 glossier
  than bare timber. The kit GLB variety path (`_vary_material`) also receives the ORM map.
- **Anti-tiling.** A shared macro tone plate (values 0.86-1.0) multiplies every library surface. It uses
  the StandardMaterial3D detail layer on world-triplanar UV2 at 0.037 repeats per unit (about 23 m, not
  a multiple of any plate). It needs no mesh UV2 and no geometry change. Albedo is lifted by the plate
  mean so toggling does not change exposure. `set_anti_tiling_enabled(bool)` updates cached and new
  materials.
- **No texture forking.** Stems are shared resources. Per-building identity is tint (the authored
  colour steers hue at weight 0.25), weathering band and a stable per-ID UV phase. Materials stay one
  per building surface, as before.

## Decisions

- **P0-053 "no shared albedo" guards re-expressed.** `test_building_surface_weathering.gd` and
  `test_slice_surface_wiring.gd` asserted that every house or interior wall owns a unique albedo
  texture. That contradicts this contract's "does not fork textures" rule. They now assert a unique
  surface recipe (stem albedo + UV phase) instead. The intent, no two neighbours showing the same plate
  in the same phase, still holds.
- **Legacy density tests follow the stem.** `test_roof_cover_density`, `test_thatch_roof_dressing`,
  `test_map_view_3d_mesh`, `test_map_view_3d_fortification` and `test_fortification_realism` compared
  against procedural-plate constants. They now expect `library_world_uv_density(stem)` or
  `library_box_uv_scale(stem, size)` when a library stem is present. The fortification course check is
  expressed in metres (<= 0.2 m). The library rubble plate gives ~0.19 m courses. The new
  `test_library_roof_plates_keep_real_cover_sizes` keeps the real-cover-size bands.
  These test files are outside the AR-03 allowed-file list; editing them was unavoidable because AR-03
  changes the density model they pin.
- **Map seed.** Stem selection hashes `(map_seed, surface_id, key)`. R-995 wires
  `MapViewMaterials.apply_building_map_seed(map_id)` from `MapView3D._assemble`
  before the interior shell and streamed houses. The salt is `String(map_id).hash()`,
  not the authored terrain seed (most maps still share `DEFAULT_SEED` 42042) and
  not a node path or instance ID.
- **Anti-tiling at `minimum`.** `MapViewMaterials.set_building_quality_tier`
  turns the detail blend off when the resolved sky-weather tier is `minimum`,
  the same gate as `set_shore_swash_quality_tier`. `MapView3D` applies it after
  `SkyWeather3D.configure`; the toggle updates already-cached house materials.
- **Ashlar selection** is an ID-substring rule, because material helpers receive only the building ID.
  AR-05 / AR-06 should replace it with an explicit building attribute.

## Measurements

| Check | Result |
|---|---|
| Distinct Walls/Roof materials on `lower_town_slice` | 113 before, 113 after (budget held; AR-02 has not set an ADR number) |
| Library coverage on `lower_town_slice` | 141 of the Walls/Roof surfaces carry a library stem; every authored `wall_material` / `roof_material` resolves (test) |
| Quick performance report, frame p95 (M5 Pro dev baseline, noisy) | before 11.16 ms; after 12.71 / 11.89 ms; after with anti-tiling off 11.71 ms |
| Static memory (same report) | before 1,186,877,133 B; after 1,032,111,079 B (-155 MB: shared stems replace per-building procedural plates) |
| Storage | `building_variants/` 20 MB total, largest file < 1 MB; storage hygiene passes |
| Geometry no-op | no file under `content/maps/`, blueprints, map compilers or mesh builders changed. `test_lower_town_slice_map` and `test_map_pipeline_hardening` (the `parity` stage) show the identical failure set before and after. `tools/run_map_pipeline_ci.sh parity` cannot run: its filter `lower_town_slice_map` matches no file (pre-existing). |

The anti-tiling cost is within run-to-run noise on this host (0.2-1.0 ms p95). R-995
turns the blend off at `minimum` so that host never pays it. Re-measure with and
without the blend on the declared R-653 minimum hardware remains **BLOCKED** here:
this session has no that host.

## Evidence

Captured with `tools/godot_render.sh --script tools/capture_ar03_building_surfaces.gd -- --label <label>`
(Forward+/Metal, 1280 x 720, downscaled to 960 x 540 for storage):

- `images/ar03_material_lineup_{before,after}.png` - every authored family under one light. Before:
  plaster, timber and smoked plaster are the same cream plate, and tile/shingle/thatch are the same brown
  pattern. After: rubble, lime, daub, soot, brick, board, log, clay tile, shingle, reed and straw read
  as different materials.
- `images/ar03_lower_town_slice_{gameplay,wide}_day_{before,after}.png`,
  `images/ar03_lower_town_slice_wide_day_after_no_antitiling.png`,
  `images/ar03_lower_town_slice_gameplay_night_after.png`, and
  `images/ar03_north_quarter_wide_day_{before,after}.png`.

Most `lower_town_slice` frontage is kit GLBs (tiered houses), which AR-03 only re-roughens, so street
plates change most on procedural houses, the city wall and north_quarter.

## Not done (blocks closing R-961)

- Compatibility-renderer plates, overcast and rain plates, and the `minimum` tier set
  (R-996).
- Named human visual review: is stone / lime / tar / clay / reed distinguishable without tint, and does
  any street show a repeating grid?
- R-653 host re-measure of anti-tiling cost with the R-995 minimum-tier off switch.
