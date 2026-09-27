# WB-07e cold building-material textures off the main thread - 2026-09-27

Board row: **R-1027**, follow-up of R-1010 ([WB-07d report](async_assembly_cold_materials_2026-09-27.md)). Status: **in review**.

R-1010 moved terrain, water, apron and boulder painting onto workers, but the first
`hewn_timber()` / `fortification_masonry()` call still painted 256 px door-and-beam
plates on the main thread. A fresh-process `reval_harbor_east` staged build paid
that cost inside `terrain_mesh/pier_cribs` (416 ms in the WB-07d report).

## What changed

| Part | Where | Behaviour |
|------|-------|-----------|
| Door / beam plates | `map_view_material_patterns.gd` | `door_wood_bake_request()` and `beam_wood_bake_request()` name the existing cache keys. `bake_image()` paints, optionally rotates, and optionally bump-maps a job-local `Image`. The synchronous getters run the same two calls. |
| Hewn timber | `map_view_prop_materials.gd` | `hewn_timber_bake_requests()` lists three variant seeds, both grain orientations, albedo plus normal, and the matching door-board plates. `publish_hewn_timber_materials()` builds the cached `StandardMaterial3D`s after the plates land. |
| Masonry plates | `map_view_building_materials.gd` | `fortification_masonry_resource_paths()` lists the AR-03 limestone library albedo/normal/ORM (and the anti-tiling plate). Limestone `Texture2D.get_image()` readback stays on the main thread, as R-1010 required. |
| Units | `map_view_mesh_builder_terrain_staged.gd` | `building_wood_masonry_units()` queues the wood bake, a threaded plate prefetch, and one publish unit. `terrain_start` runs it for the crib rubble colour before `pier_cribs`. |
| Neighbor previews | `map_view_mesh_builder_surroundings.gd` | Each neighbor's `_materials` unit also queues the same wood bake plus masonry colours collected from `kind=wall` buildings. Object chunks then hit a warm cache. |
| Crib publish | `map_view_pier_crib_builder.gd` | After the wood left `pier_cribs`, the remaining ArrayMesh publish was 4.3 ms. Logs and piles are now follow-up units (`pier_cribs_logs`, `pier_cribs_piles`). |

**Thread rule** (unchanged). Workers paint job-local images. Textures, materials and nodes stay on the main thread. Library PNG loads use `ResourceLoader.load_threaded_request()`.

## Verification

| Check | Result |
|-------|--------|
| `--filter=test_async_location_assembly` (18 tests, 1 new) | pass |
| New: crib wood/masonry units prefetch plates and publish byte-identical door/beam textures | pass |
| Existing worker-bake identity test now includes `hewn_timber_bake_requests()` | pass |
| Fresh-process headless `async_assembly_trace.gd --map=reval_harbor_east` | `pier_cribs` 0.004 ms, `pier_cribs_logs` 0.641 ms, `pier_cribs_piles` 0.079 ms, `cribs_building_materials` 0.147 ms |
| GL Compatibility `material_texture_hashes.gd` vs HEAD at `48696ba7` | 2079 / 2079 slots identical |

Reproduce the cold harbor number in a new process (a three-map trace warms the wood cache on the first map):

```bash
godot --headless --path . --script tools/benchmarks/async_assembly_trace.gd \
  -- --output=res://build/benchmarks/async_assembly.json --map=reval_harbor_east
```

Host: Apple M5 Pro, Godot 4.7.1, dummy renderer for the trace, GL Compatibility for the hash pair.
