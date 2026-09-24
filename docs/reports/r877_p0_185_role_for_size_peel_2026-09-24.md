# R-877 / P0-185 role_for_size peel (2026-09-24)

## Decision

Move `MapViewMaterials.role_for_size()` implementation into `map_view_prop_materials.gd` beside `role()`. The facade keeps a one-line delegate so door, landmark, and sign builders keep importing `MapViewMaterials`.

## Rationale

After wind, terrain, water, and building UV table peels, `map_view_materials.gd` still held the only prop-specific sizing logic (pattern pick + `building_uv_scale`). That belongs with prop caches, not the weather-presentation facade.

## Line counts

| File | Before | After |
| --- | ---: | ---: |
| `map_view_materials.gd` | 380 | 370 |
| `map_view_prop_materials.gd` | 282 | 300 |

## Next justified peel (not implemented here)

- **Keep** `apply_weather_presentation()` on the facade: it is the single fan-out adapter for water, mud wetness, and world wind; extracting it would not shrink a cohesive concern until a second owner appears.
- **Optional later:** move `TEXTURE_SIZE` / `COBBLE_TEXTURE_SIZE` / `NATURAL_GROUND_TEXTURE_SIZE` / `MASONRY_TEXTURE_SIZE` into a tiny constants module if tests stop needing them on `MapViewMaterials`.

## Verification

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
godot --headless --path . --script tools/run_godot_tests.gd -- \
  --filter=test_map_view_material_resolution,test_street_and_masonry_realism,test_map_view_3d_fortification,test_direction_sign_3d
```
