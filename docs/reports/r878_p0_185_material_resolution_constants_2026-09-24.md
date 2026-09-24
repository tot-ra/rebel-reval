# R-878 / P0-185 material resolution constants peel (2026-09-24)

## Change

- Added `map_view_material_resolution_constants.gd` as the canonical home for
  `TEXTURE_SIZE`, `COBBLE_TEXTURE_SIZE`, `NATURAL_GROUND_TEXTURE_SIZE`, and
  `MASONRY_TEXTURE_SIZE`.
- `map_view_materials.gd` re-exports the four values for contract tests (370 → 366 lines).
- `map_view_terrain_materials.gd` and `map_view_material_patterns.gd` preload the
  constants module directly instead of duplicating literals or routing through the facade.

## Verify

```bash
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
tools/run_godot_checked.sh --require-test-summary material_resolution_peel -- \
  "$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_map_view_material_resolution,test_map_terrain_chunks
```

Result: 2 file(s), 15 test(s), 0 failure(s), 0 error(s).
