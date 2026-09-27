# WB-07d cold material and texture generation off the main thread - 2026-09-27

Board row: **R-1010**, follow-up of R-1005 ([WB-07b report](async_assembly_2026-09-27.md), "Residual gaps"). Status: **in review**.

The first staged build of a map used to stall on main-thread texture painting: `MapViewMaterials.blended_ground(seed)` in `terrain_mesh/ground_publish` (about 3 s cold on `lower_town_slice`), the per-seed terrain materials of every neighbor preview (0.9-1.1 s per neighbor), and water material resources in `surroundings/backdrops`. That work is now split into worker-painted `Image`s plus small main-thread publish units. Every texture keeps its cache key and its bytes.

## Where the time went

Cold costs measured in a fresh headless process (Apple M5 Pro, Godot 4.7.1):

| Item | Cost | Why |
|------|------|-----|
| `cobble_surface_texture(8219)` (512 px RGBA, 5 samples per pixel) | 1688 ms | GDScript per-pixel painting |
| Cobble plate `pattern:cobble:8219:512` | 698 ms | same |
| `terrain(&"cobblestone" / &"castle_paving", seed)` | 700 ms each, per seed | 512 px cobble plate per seed |
| 128 px procedural families (grass, earth, mud, straw, speckle, plaster, plank) | 13-49 ms each | same |
| FFT atlases (`ocean_fft_textures()`) | 97 ms | synchronous `load()` |
| Caustic tile pair (`caustic_tiles_texture()`) | 6-14 ms | per-byte interleave loop plus load |
| Authored plates (`mud_albedo.png`, `limestone_rubble_albedo.png`) | about 5 ms each | synchronous `load()` |

## What changed

| Part | Where | Behaviour |
|------|-------|-----------|
| Bake requests | `map_view_material_patterns.gd` | `pattern_bake_request()`, `pattern_normal_bake_request()` and `cobble_surface_bake_request()` name one cached texture by its existing key. `bake_image()` paints a job-local `Image` (pure, worker-safe). `publish_baked()` creates the `ImageTexture` on the main thread; the first publisher of a key wins. The synchronous getters (`pattern_texture*()`, `pattern_normal_texture()`, `cobble_surface_texture()`) now run the same two calls. `missing_bakes()` filters out cached keys and the two families that stay synchronous: limestone reads an authored plate back with `Texture2D.get_image()` (a renderer call), and the roof-tile painter writes the pattern cache. |
| Terrain materials | `map_view_terrain_materials.gd` | `terrain_bake_requests()` and `blended_ground_bake_requests()` list the textures `terrain()` and `blended_ground()` paint, built from the same helpers the getters use. `terrain_pattern_array()` is split into `terrain_pattern_layer_image()` (one layer) and `publish_terrain_pattern_array()`. The cobble seed `8219` is the named constant `COBBLE_PLATE_SEED`. |
| Prop materials | `map_view_prop_materials.gd` | `backdrop_bake_requests()` for the woodland apron (`surroundings_ground()`) and the tree-band boulders (`natural_rock()`, albedo plus normal). Seeds and the rock normal strength are named constants; values unchanged. |
| Water materials | `map_view_water_materials.gd` | `caustic_tiles_texture()` is split into `caustic_tile_sources()` (main-thread readback), `pack_caustic_tiles()` (pure) and `publish_caustic_tiles()`. `cold_resource_paths()` lists the FFT atlases, foam tile and caustic tiles that are not cached yet. |
| Worker jobs | `map_view_worker_job.gd` | `load_resources(paths)`: a job over `ResourceLoader.load_threaded_request()`. `is_done()` polls the load status; `value()` returns the resources in path order and keeps them cached while a unit holds the job. A job freed without `wait()` now joins its task in `PREDELETE`: neighbor material bakes start one pass before their await units are queued, so a cancel in between must not leave an un-waited pool task. |
| Units | `map_view_mesh_builder_terrain_staged.gd` | `pattern_bake_units()` (one group job, one publish unit per texture), `blended_ground_units()` (bake, plate prefetch, one unit per array layer, array publish, cobble array, material), `terrain_material_units()` and `water_material_units()` (threaded resource prefetch, worker caustic pack, one unit per material). `terrain_start` queues the ground material and water material units beside the existing band and water bakes. |
| Surroundings | `map_view_mesh_builder_surroundings.gd` | Each neighbor gets a `neighbor_<id>_materials` unit right after its data job. It starts that neighbor's terrain and water material bakes, so all neighbors bake at once. The preview units run after every neighbor's data landed, still in transition order; each preview first publishes its materials, then builds the old preview (`neighbor_preview`). The apron and boulder textures start baking with the stage; water backdrop materials get their own units before `backdrops`. |

**Thread rule** (unchanged from R-1005). Workers paint job-local images and read only immutable request dictionaries and source images handed to them. Static caches (pattern, terrain, water, prop), textures and materials are written on the main thread. `Texture2D.get_image()` stays on the main thread because it is a renderer call. Resource loads use Godot's threaded loader.

The synchronous `create()` drains the same units, so it also gets the worker bakes.

Files outside the row's allowed list: `map_view_prop_materials.gd` (the backdrop apron and boulder textures were the rest of the cold `backdrops` / `tree_band_publish` cost) and the new `tools/benchmarks/material_texture_hashes.gd`.

## Verification

| Check | Result |
|-------|--------|
| `--filter=test_async_location_assembly` (16 tests, 4 new) | pass |
| New: a worker job freed without `wait()` joins its task (single and group) | pass |
| New: every worker-painted request (blended ground, all 17 terrain families, apron, boulder albedo and normal, cobble surface) equals the main-thread paint byte for byte, with mipmaps | pass |
| New: cold `blended_ground_units()` bakes on a worker, publishes every texture under its synchronous key with identical bytes, builds one cached array and material, and returns no units when warm | pass |
| New: `load_resources()` resolves in path order and joins twice safely; the worker caustic pack equals the main-thread pack and the published tiles | pass |
| Full `run_godot_tests.gd` | 2244 tests; the failing set equals the baseline worktree's (HEAD plus the same concurrent edits), apart from `test_world_host` additive residency, which also fails in the baseline when that file runs alone (order-dependent), and three `test_act1_*` packaged-build checks that only fail in the worktree because it has no export build |
| `gdlint` on every touched script | clean |

### Texture hash parity

`tools/benchmarks/material_texture_hashes.gd` builds `lower_town_slice` and `reval_harbor_east` through staged assembly and prints the SHA-256 of every texture slot under `Terrain` and `Surroundings` (2079 slots, 64 of them `Texture2DArray` slots hashed per layer). Baseline: a HEAD worktree with the same concurrent working-tree edits to `map_view_3d.gd` and `map_view_materials.gd`. Both runs went through `tools/godot_render.sh` (GL Compatibility), because the headless dummy renderer cannot read `Texture2DArray` layers back.

| Result | Slots |
|--------|-------|
| Identical, including every blended-ground array layer, cobble array, cobble surface, per-seed neighbor terrain texture, apron, boulder albedo and normal, caustic tiles and FFT atlases | 2071 |
| Different: `MerchantStoneLimeRender` albedo on 8 `lower_town_slice` west-neighbor houses | 8 |

The 8 slots are an imported, VRAM-compressed (BC1) JPEG from `merchant_stone_rendered.glb` that this change does not touch. A standalone GL readback of that texture gives `608f89de6e0221fa`, which is the new run's value; the baseline run reads back `e3b4fae799eb3bf7` for it and does so on repeated runs. The difference is in the readback, not in the generated textures.

Headless note: under the dummy renderer, `get_image()` returns the texture's own `Image`, and the existing authored-layer code resizes it in place. With the plate prefetch the `mud_albedo` slot therefore reads back the resized 128 px copy headless. GL is unaffected. Follow-up **R-1025** (landed in 4595db88, merged here) makes those readers copy first.

## Numbers

Host: Apple M5 Pro, Godot 4.7.1, headless dummy renderer, 4 ms budget. Reproduce: `godot --headless --path . --script tools/benchmarks/async_assembly_trace.gd -- --output=res://build/benchmarks/async_assembly.json`. The trace runs the three maps in one process, so `reval_harbor_east` starts with the cobble plates already cached.

Cold material units, main-thread milliseconds (before from the [WB-07b report](async_assembly_2026-09-27.md); after from `cold_staged` of the trace and from a fresh process per map, which is colder than the trace because nothing is shared with an earlier map):

| Unit | Before | After, `lower_town_slice` | After, `reval_harbor_east` |
|------|--------|---------------------------|----------------------------|
| `terrain_mesh/ground_publish` | 2961 (`blended_ground()` inside it) | 3.8 | 1.7 |
| `terrain_mesh/ground_material` (new: array bind and material) | - | 3.0 | 3.0 |
| `terrain_mesh/ground_layer_*` (new, one per array layer) | - | at most 2.2 | at most 1.2 |
| `terrain_mesh/*_pattern_*` publish units (new) | - | at most 0.1 | at most 0.1 |
| `surroundings/neighbor_<id>` preview incl. terrain materials | 900-1100 per neighbor | `neighbor_preview` at most 2.4 | 1.1 |
| `surroundings/neighbor_<id>_materials` (new: starts the bakes) | - | at most 0.5 | 0.2 |
| `surroundings/neighbor_<id>_terrain_<terrain>` (new) | - | at most 0.14 (stone) | at most 0.12 |
| First water material of the process (`*_water_<terrain>`) | 34 in `backdrops` (plus 97 FFT atlas load) | 9.3-11.9 (shader parse, see residuals) | 9.4 |
| `surroundings/backdrops` | 34 | under 1 | 0.06 (81.6-83.9 before R-1024 removed the R-1022 grid rebuild) |

`cold_staged` in the trace (`build/benchmarks/async_assembly.json`): on `lower_town_slice` no `ground_publish`, `neighbor_*` material or `backdrops` unit is over 4 ms except `neighbor_reval_south_water_water` (9.3 ms, the first water shader parse). On `reval_harbor_east` the only such unit over 4 ms was `backdrops` (81.6 ms, all of it the R-1022 grid rebuild; its materials are prebuilt by the `backdrops_water_*` units at under 0.01 ms). R-1024 landed during this task and removed that rebuild: `backdrops` is now 0.06 ms in a fresh process. Every other unit over budget in these stages is a neighbor-preview `build_building()` / `build_prop()` (R-1006).

A fresh process also shows `terrain_mesh/pier_cribs` at 416 ms on `reval_harbor_east`: the crib cladding's first `hewn_timber()` and `fortification_masonry()` materials paint their building textures there. Those are building-material textures outside this row's files; follow-up **R-1027**.

Wall time barely changes: the worker bakes run beside the existing band, water and neighbor bakes. The long pole is the 1.7 s cobble surface on one worker, which only a cold process pays.

## Residual gaps

| Gap | Cost | Owner |
|-----|------|-------|
| `surroundings/backdrops` on `reval_harbor_east`: `water_continuation_rest_y()` (R-1022) ran `MapBuilder.build()` plus `ensure_height_field()` per water side | was about 80 ms warm, up to about 650 ms cold | **R-1024**, landed (0876f4ed); now 0.06 ms |
| First `ShaderMaterial` of the water shader: `water_surface()` costs about 9 ms once even with every resource loaded (the terrain-blend shader about 2.8 ms). This is the shader parse on first use, not texture work, and it is renderer-specific | 9 ms once per process | R-1006 GPU-backed trace decides whether it needs a warm-up |
| Limestone terrain (`terrain(&"stone", seed)`) and the other synchronous families (roof tile, weathered building patterns) still read back or paint on the main thread. With the plate prefetch, the stone material is about 0.1 ms | small | none |
| `tree_band_publish` 14 ms: tree canopy meshes and bark materials | 14 ms cold | R-1006 (scatter and tree batches) |
| Neighbor-preview `build_building()` / `build_prop()` | 4-1030 ms cold | R-1006 |
| `terrain_mesh/pier_cribs` in a fresh process: first `hewn_timber()` / `fortification_masonry()` building textures | 416 ms cold on `reval_harbor_east` | **R-1027** |

## Second review (R-1029)

**ACCEPT**, 2026-09-27. Independent review of `e330642d` on `be1b971e`:
[`r1029_r1010_cold_materials_review.md`](r1029_r1010_cold_materials_review.md).
Focused suite 31/31. Fresh-process `cold_staged` has no `ground_publish` or
`backdrops` unit over 4 ms; the only contract-class overrun is the documented
first water shader parse (~9.3 ms). Close R-1010.
