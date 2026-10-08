# Village and house windows

Status: implemented (ad-hoc request, no board task). Scope: window relief on seamless-city buildings built by `CityBuildingBuilder`. Out of scope: opening/closing animation, interior-side frames, lit-window glow (see `building_window_lights_3d.gd`), and the older `MapView` house facade windows.

## What the player sees

Log and plank cottages (the country farmsteads) no longer get a flat dark rectangle. Each building picks one **look** from its own id, and about one window in four breaks from it, as hand-built houses do:

| Style | Reference |
|-------|-----------|
| `plain` | Painted frame, sash bars, sill board |
| `platband` | Carved platband (nalichnik): wide side boards, saw-tooth apron, notched lintel, pediment |
| `gable_cap` | Plain frame under a small boarded pediment |
| `shutters_open` | Plank shutters parked flat beside the frame with a darker centre board |
| `shutters_closed` | Shutters closed across the opening with battens |
| `slit` | Low sliding-board smoke-house slit (volokovoe) |
| `surround` | Stone and plaster houses: dressed lintel, jambs and sill |

Trim and shutter colours come from `TRIM_PAINTS` / `SHUTTER_PAINTS` (whitewash, ochre, blue, green, red, bare wood); pane layout is 1 to 3 bar grids. Churches and halls keep their lancets.

## Runtime entry points

- `CityWindows.look` (per-building look, own RNG so roof/chimney draws are unchanged), `add_wall` (placement), `add_window`, `_platband`, `_pediment`, `_shutters`, `_wbox` (relief box), all in `scripts/city/city_windows.gd`; called from `city_building_builder.gd`.
- New material key `paint` (`paint_material`): vertex-coloured painted wood, no texture.
- Determinism: the look RNG is seeded from the building id; no saved state.

## Verify

- `godot --headless --path . --script tools/run_godot_tests.gd` (`tests/godot/test_city_windows.gd`)
- Review plate: `tools/godot_render.sh --script tools/capture_cottage_windows.gd` writes `build/windows/cottage_windows.png`.

## Limits

- Period note: 1343 Baltic peasant houses mostly had small unglazed shuttered openings; glazed platband windows are a deliberate reading of the request and lean on later Russian and Estonian vernacular. Revisit against `docs/CANON.md` if strict 1343 accuracy is required.
- The `MapView` facade windows (`map_view_mesh_builder_building_facade.gd`) and `MapViewRuralDwellingModels` are separate and unchanged.
- Windows add roughly 100 to 300 triangles each; no distance LOD beyond the chunk's `BUILDING_RANGE`.
