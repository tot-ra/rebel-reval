# R-529 Monastery east-ditch water

Recorded: 2026-09-27
Parent: R-715 water rollout / R-454 monastery elevation

## Decision

The east outer-wall ditch on `monastery_quarter` is authored still water with a dirt
causeway punch-through. The shared water contour uses a 4-cell Gaussian, which was
filling that short dry gap and the `to_reval_east_outer` travel opening.

Enclosed still water (`TERRAIN_WATER`: ponds, ditches, moats) now keeps the
smoothed contour inside the authored water mask. River and sea keep the broad
field so stair-stepped banks can still round.

## Contract

- Ditch cells along the east wall stay `water`.
- Causeway cells stay `dirt` and walkable.
- `to_reval_north_outer` and `to_reval_east_outer` have no water terrain and sit
  below the water iso-line.
- `MapView3D.create` builds `Terrain/Terrain_water` with the shared enclosed
  material and does not mutate the grid fingerprint or walkability.

## Verify

```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --path . --script tools/run_godot_tests.gd \
  -- --filter=test_r529_monastery_east_ditch,test_monastery_quarter_prototype_map,test_r454_elevation_scope,test_r715_water_exceptions,test_r715_water_map_rollout,test_r715_water_rollout_inventory,test_r715_water_surface_geometry
```

The map stays `active=false`. Visual and performance packets may still omit
monastery plates.
