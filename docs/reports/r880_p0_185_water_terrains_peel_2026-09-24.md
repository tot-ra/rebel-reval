# R-880 / P0-185 water terrain ID peel (2026-09-24)

## Change

- `map_view_water_materials.gd` now owns `WATER_TERRAINS` as an alias of
  `MapTypes.WATER_TERRAINS` so water rollout inventory and mesh builders share one
  module-level contract beside `WATER_WAVE_BASE`.
- `map_view_materials.gd` re-exports `WATER_TERRAINS` from the water module and
  drops unused ember constants already owned by `map_view_prop_materials.gd`
  (366 → 358 lines).
- `map_view_terrain_materials.gd` aliases `MapTypes.WATER_TERRAINS` directly
  instead of duplicating the four-ID list.

## Verify

```bash
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
tools/run_godot_checked.sh --require-test-summary water_terrains_peel -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_map_view_material_resolution,test_r715_water_material_contract,test_r715_water_rollout_inventory,test_coastal_sea_3d,test_map_terrain_chunks
```
